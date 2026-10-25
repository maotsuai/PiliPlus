package com.example.piliplus;

import android.app.Activity;
import android.app.PictureInPictureParams;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.Rect;
import android.os.Build;
import android.os.Bundle;
import android.util.Rational;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.WindowManager;

import androidx.annotation.NonNull;

/** A system PiP window with one video Surface and no Flutter engine or decoder. */
public final class PipActivity extends Activity implements SurfaceHolder.Callback {
    long sessionId;
    private SystemPipPlugin plugin;
    private SurfaceView video;
    private long surfaceReference;
    private PictureInPictureParams params;
    private boolean entered;
    private boolean enterRequested;
    private boolean stoppedByApp;
    private boolean restoring;

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
        getWindow().getDecorView().setBackgroundColor(Color.BLACK);
        video = new SurfaceView(this);
        video.getHolder().addCallback(this);
        setContentView(video);
    }

    void updateParams() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || plugin == null) return;
        int width = plugin.dimension("width", 16);
        int height = plugin.dimension("height", 9);
        double ratio = (double) width / height;
        if (ratio < 1 / 2.39 || ratio > 2.39) {
            width = width > height ? 16 : 9;
            height = width == 16 ? 9 : 16;
        }
        PictureInPictureParams.Builder builder = new PictureInPictureParams.Builder()
                .setAspectRatio(new Rational(width, height));
        Rect rect = new Rect();
        if (video != null && video.getGlobalVisibleRect(rect)) builder.setSourceRectHint(rect);
        AndroidHelper.setPipActions(this, builder, plugin.state("isLive"), plugin.state("isPlaying"));
        params = builder.build();
        setPictureInPictureParams(params);
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
            plugin.started(this);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (entered && !isInPictureInPictureMode() && !stoppedByApp && !restoring) {
            restoring = true;
            plugin.restore(this);
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
        if (entered && !stoppedByApp && !restoring) plugin.dismissed(this);
    }

    @Override
    protected void onDestroy() {
        if (plugin != null && !stoppedByApp) plugin.dismissed(this);
        if (surfaceReference != 0) SystemPipPlugin.releaseSurface(surfaceReference);
        super.onDestroy();
    }

    void finishFromApp() {
        stoppedByApp = true;
        finishAndRemoveTask();
    }

    @Override
    public void surfaceCreated(@NonNull SurfaceHolder holder) {
        surfaceReference = SystemPipPlugin.retainSurface(holder.getSurface());
    }

    @Override
    public void surfaceChanged(@NonNull SurfaceHolder holder, int format, int width, int height) {
        if (!stoppedByApp) plugin.surface(this, surfaceReference, width, height);
    }

    @Override
    public void surfaceDestroyed(@NonNull SurfaceHolder holder) {
        if (surfaceReference != 0) {
            SystemPipPlugin.releaseSurface(surfaceReference);
            surfaceReference = 0;
        }
    }
}
