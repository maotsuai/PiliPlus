package com.example.piliplus;

import android.app.Activity;
import android.app.PictureInPictureParams;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.Rect;
import android.graphics.SurfaceTexture;
import android.os.Build;
import android.os.Bundle;
import android.view.Surface;
import android.view.TextureView;
import android.view.WindowManager;

import androidx.annotation.NonNull;

/** A system PiP window with one video Surface and no Flutter engine or decoder. */
public final class PipActivity extends Activity implements TextureView.SurfaceTextureListener {
    long sessionId;
    private SystemPipPlugin plugin;
    private TextureView video;
    private Surface surface;
    private long surfaceReference;
    private PictureInPictureParams params;
    private boolean attachedSurface;
    private boolean reportedStarted;
    private boolean stoppedByApp;
    private final PipEntryState entryState = new PipEntryState();
    private final PipRestoreState restoreState = new PipRestoreState();

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        plugin = SystemPipPlugin.instance;
        sessionId = getIntent().getLongExtra("sessionId", -1);
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || plugin == null || !plugin.attach(this, sessionId)) {
            finish();
            return;
        }
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        // Prepare a transparent output without covering the inline video with a
        // separate SurfaceView window. mpv attaches only after PiP is confirmed.
        video = new TextureView(this);
        video.setOpaque(false);
        video.setSurfaceTextureListener(this);
        setContentView(video);
        if (isInPictureInPictureMode()) confirmPipMode();
    }

    @Override
    protected void onPostResume() {
        super.onPostResume();
        // makeLaunchIntoPip is an optimization, not an acknowledgment. Some
        // systems still resume this Activity normally; explicitly enter there.
        // Give direct entry its first frame before applying this fallback.
        video.postDelayed(() -> {
            if (stoppedByApp || reportedStarted || isFinishing()) return;
            if (isInPictureInPictureMode()) confirmPipMode();
            else enterPip();
        }, Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU ? 100 : 0);
    }

    void updateParams() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || plugin == null) return;
        Rect rect = new Rect();
        if (video != null) video.getGlobalVisibleRect(rect);
        params = plugin.buildParams(rect);
        setPictureInPictureParams(params);
    }

    void surfaceAttached(long reference, int width, int height) {
        if (!entryState.confirmOutput(reference, width, height)) return;
        attachedSurface = true;
        if (isInPictureInPictureMode()) {
            reportStarted();
        }
    }

    private void reportStarted() {
        if (!attachedSurface || reportedStarted || stoppedByApp) return;
        reportedStarted = true;
        restoreState.started();
        showPipContent();
        plugin.started(this);
    }

    private void showPipContent() {
        getWindow().getDecorView().setBackgroundColor(Color.BLACK);
    }

    private void confirmPipMode() {
        entryState.modeChanged(true);
        showPipContent();
        attachPipOutput();
    }

    private void attachPipOutput() {
        PipEntryState.Output output = entryState.takeOutput();
        if (output != null) plugin.surface(this, output.reference, output.width, output.height);
    }

    void enterPip() {
        if (isFinishing() || stoppedByApp) return;
        if (isInPictureInPictureMode()) {
            confirmPipMode();
            return;
        }
        if (!entryState.requestEntry()) return;
        try {
            updateParams();
            if (!enterPictureInPictureMode(params)) plugin.fail("System rejected PiP");
        } catch (RuntimeException error) {
            plugin.fail(error.toString());
        }
    }

    @Override
    public void onPictureInPictureModeChanged(boolean inPip, Configuration configuration) {
        super.onPictureInPictureModeChanged(inPip, configuration);
        entryState.modeChanged(inPip);
        if (inPip) {
            confirmPipMode();
        } else {
            if (!isFinishing() && restoreState.modeChanged(false)) plugin.restore(this);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (!isFinishing() && restoreState.resumed(isInPictureInPictureMode())) {
            plugin.restore(this);
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
        if (restoreState.stopped(isInPictureInPictureMode(), isFinishing())) {
            plugin.restore(this);
        } else if (restoreState.shouldDismiss(isFinishing())) {
            plugin.dismissed(this);
        }
    }

    @Override
    protected void onDestroy() {
        if (plugin != null && !stoppedByApp) plugin.dismissed(this);
        releaseVideoSurface(null);
        super.onDestroy();
    }

    void finishFromApp() {
        stoppedByApp = true;
        entryState.close();
        restoreState.close();
        // Direct-launch PiP may be reparented into the host's task on expansion.
        // Finish only this window; the host owns its task and navigation stack.
        finish();
        overridePendingTransition(0, 0);
    }

    boolean isRestoring() { return restoreState.isRestoring(); }

    String startupState() {
        return "mode=" + isInPictureInPictureMode() + ", surface=" +
                (surfaceReference != 0) + ", attached=" + attachedSurface;
    }

    @Override
    public void onSurfaceTextureAvailable(@NonNull SurfaceTexture texture, int width, int height) {
        surface = new Surface(texture);
        surfaceReference = SystemPipPlugin.retainSurface(surface);
        onSurfaceTextureSizeChanged(texture, width, height);
    }

    @Override
    public void onSurfaceTextureSizeChanged(@NonNull SurfaceTexture texture, int width, int height) {
        if (stoppedByApp) return;
        entryState.surfaceChanged(surfaceReference, width, height);
        // Keep mpv on its inline output until Android confirms the window is PiP.
        // A failed launch must never steal and then reset the inline Surface.
        attachPipOutput();
    }

    @Override
    public boolean onSurfaceTextureDestroyed(@NonNull SurfaceTexture texture) {
        releaseVideoSurface(texture);
        // Keep the texture alive until mpv has dropped the old Surface.
        return false;
    }

    private void releaseVideoSurface(SurfaceTexture texture) {
        entryState.surfaceChanged(0, 0, 0);
        SystemPipPlugin.releaseSurface(surfaceReference, surface, texture);
        surfaceReference = 0;
        surface = null;
    }

    @Override
    public void onSurfaceTextureUpdated(@NonNull SurfaceTexture texture) {}
}
