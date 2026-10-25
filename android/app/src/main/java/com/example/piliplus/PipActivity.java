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
    private boolean entered;
    private boolean attachedSurface;
    private boolean reportedStarted;
    private boolean enterRequested;
    private boolean stoppedByApp;
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
        // Unlike SurfaceView on older Android versions, TextureView's alpha
        // reliably hides its separate video output during the transparent launch.
        video = new TextureView(this);
        video.setOpaque(false);
        video.setAlpha(0);
        video.setSurfaceTextureListener(this);
        setContentView(video);
        if (isInPictureInPictureMode()) showPipContent();
    }

    @Override
    protected void onPostResume() {
        super.onPostResume();
        // Do not wait for Surface creation + a Dart round trip before asking the
        // OS to shrink the legacy Activity. Those can finish inside PiP.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU &&
                !reportedStarted && !isInPictureInPictureMode()) enterPip();
    }

    void updateParams() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || plugin == null) return;
        Rect rect = new Rect();
        if (video != null) video.getGlobalVisibleRect(rect);
        params = plugin.buildParams(rect);
        setPictureInPictureParams(params);
    }

    void surfaceAttached() {
        attachedSurface = true;
        if (isInPictureInPictureMode()) {
            entered = true;
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
        // Allow TextureView to create/draw its hardware layer as soon as PiP is
        // visible, even if Surface attachment has not completed yet.
        video.setAlpha(1);
        getWindow().getDecorView().setBackgroundColor(Color.BLACK);
    }

    void enterPip() {
        if (entered || enterRequested || isFinishing()) return;
        enterRequested = true;
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
        if (inPip && !entered) {
            entered = true;
            showPipContent();
            reportStarted();
        } else if (!inPip) {
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
    protected void onPause() {
        restoreState.paused();
        super.onPause();
    }

    @Override
    protected void onStop() {
        super.onStop();
        if (restoreState.shouldDismiss()) plugin.dismissed(this);
    }

    @Override
    protected void onDestroy() {
        if (plugin != null && !stoppedByApp) plugin.dismissed(this);
        releaseVideoSurface(null);
        super.onDestroy();
    }

    void finishFromApp() {
        stoppedByApp = true;
        restoreState.close();
        finishAndRemoveTask();
        overridePendingTransition(0, 0);
    }

    @Override
    public void onSurfaceTextureAvailable(@NonNull SurfaceTexture texture, int width, int height) {
        surface = new Surface(texture);
        surfaceReference = SystemPipPlugin.retainSurface(surface);
        onSurfaceTextureSizeChanged(texture, width, height);
    }

    @Override
    public void onSurfaceTextureSizeChanged(@NonNull SurfaceTexture texture, int width, int height) {
        if (!stoppedByApp) plugin.surface(this, surfaceReference, width, height);
    }

    @Override
    public boolean onSurfaceTextureDestroyed(@NonNull SurfaceTexture texture) {
        releaseVideoSurface(texture);
        // Keep the texture alive until mpv has dropped the old Surface.
        return false;
    }

    private void releaseVideoSurface(SurfaceTexture texture) {
        SystemPipPlugin.releaseSurface(surfaceReference, surface, texture);
        surfaceReference = 0;
        surface = null;
    }

    @Override
    public void onSurfaceTextureUpdated(@NonNull SurfaceTexture texture) {}
}
