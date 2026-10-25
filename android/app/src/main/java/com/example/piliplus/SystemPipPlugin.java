package com.example.piliplus;

import android.app.Activity;
import android.app.ActivityOptions;
import android.app.PictureInPictureParams;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.graphics.Rect;
import android.graphics.SurfaceTexture;
import android.util.Rational;
import android.util.Log;
import android.view.Surface;

import androidx.annotation.NonNull;

import com.alexmercerind.mediakitandroidhelper.MediaKitAndroidHelper;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Keeps the existing mpv player in Dart; only its Surface moves to another Activity. */
public final class SystemPipPlugin implements FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    static SystemPipPlugin instance;
    private MethodChannel channel;
    private Context applicationContext;
    private Activity host;
    private Map<String, Object> configuration;
    private boolean autoEnter;
    private boolean launching;
    private PipActivity playbackActivity;
    private final Handler handler = new Handler(Looper.getMainLooper());

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        instance = this;
        applicationContext = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "com.example.piliplus/pip");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        close();
        channel.setMethodCallHandler(null);
        if (instance == this) instance = null;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) { host = binding.getActivity(); }
    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) { onAttachedToActivity(binding); }
    @Override
    public void onDetachedFromActivityForConfigChanges() { host = null; }
    @Override
    public void onDetachedFromActivity() { host = null; }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "isAvailable":
                result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && host != null &&
                        host.getPackageManager().hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE));
                break;
            case "enter":
                configuration = new HashMap<>(call.<Map<String, Object>>arguments());
                if (Boolean.TRUE.equals(configuration.get("autoEnter"))) {
                    autoEnter = true;
                } else {
                    launch(false);
                }
                result.success(null);
                break;
            case "update":
                if (configuration != null) configuration.putAll(call.<Map<String, Object>>arguments());
                if (playbackActivity != null) playbackActivity.updateParams();
                result.success(null);
                break;
            case "disableAutoEnter":
                autoEnter = false;
                result.success(null);
                break;
            case "dispose":
                close();
                result.success(null);
                break;
            default:
                result.notImplemented();
        }
    }

    public boolean onUserLeaveHint() {
        if (launching || playbackActivity != null) return true;
        if (!autoEnter || configuration == null || !Boolean.TRUE.equals(configuration.get("isPlaying"))) return false;
        launch(true);
        return true;
    }

    private void launch(boolean leavingApp) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || host == null || configuration == null || launching || playbackActivity != null) return;
        launching = true;
        final long id = sessionId();
        emit("onStateChanged", map("active", true));
        try {
            Intent intent = new Intent(host, PipActivity.class)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_NO_ANIMATION)
                    .putExtra("sessionId", id)
                    .putExtra("leavingApp", leavingApp);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                host.startActivity(intent, ActivityOptions.makeLaunchIntoPip(buildParams(null)).toBundle());
            } else {
                host.startActivity(intent, ActivityOptions.makeCustomAnimation(host, 0, 0).toBundle());
            }
            handler.postDelayed(() -> {
                if (launching && sessionId() == id) fail("PiP startup timed out: " +
                        (playbackActivity == null ? "Activity missing" : playbackActivity.startupState()));
            }, 3000);
        } catch (RuntimeException error) {
            fail(error.toString());
        }
    }

    long sessionId() {
        return configuration == null ? -1 : ((Number) configuration.get("sessionId")).longValue();
    }

    int dimension(String name, int fallback) {
        Object value = configuration == null ? null : configuration.get(name);
        return value instanceof Number && ((Number) value).intValue() > 0 ? ((Number) value).intValue() : fallback;
    }

    boolean state(String name) { return configuration != null && Boolean.TRUE.equals(configuration.get(name)); }

    boolean attach(PipActivity activity, long id) {
        if (!launching || id != sessionId()) return false;
        playbackActivity = activity;
        return true;
    }

    void surface(PipActivity activity, long wid, int width, int height) {
        if (activity != playbackActivity || activity.isRestoring()) return;
        channel.invokeMethod("surface", envelope(map("wid", wid, "width", width, "height", height)),
                new MethodChannel.Result() {
                    @Override public void success(Object value) {
                        if (activity != playbackActivity || activity.isRestoring()) return;
                        if (Boolean.TRUE.equals(value)) activity.surfaceAttached(wid, width, height);
                        else fail("Could not attach the playback surface");
                    }
                    @Override public void error(String code, String message, Object details) {
                        if (activity == playbackActivity && !activity.isRestoring()) fail(message);
                    }
                    @Override public void notImplemented() {
                        if (activity == playbackActivity && !activity.isRestoring()) fail("Surface handoff unavailable");
                    }
                });
    }

    void started(PipActivity activity) {
        if (activity != playbackActivity) return;
        launching = false;
        AndroidHelper.isPipMode = true;
        emit("onStateChanged", map("active", true, "started", true));
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU &&
                !activity.getIntent().getBooleanExtra("leavingApp", false)) bringHostToFront();
    }

    PictureInPictureParams buildParams(Rect source) {
        int width = dimension("width", 16);
        int height = dimension("height", 9);
        double ratio = (double) width / height;
        if (ratio < 1 / 2.39 || ratio > 2.39) {
            width = width > height ? 16 : 9;
            height = width == 16 ? 9 : 16;
        }
        PictureInPictureParams.Builder builder = new PictureInPictureParams.Builder()
                .setAspectRatio(new Rational(width, height));
        if (source != null && !source.isEmpty()) builder.setSourceRectHint(source);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) builder.setSeamlessResizeEnabled(true);
        Context context = host != null ? host : applicationContext;
        AndroidHelper.setPipActions(context, builder, state("isLive"), state("isPlaying"));
        return builder.build();
    }

    void restore(PipActivity activity) {
        if (activity != playbackActivity) return;
        AndroidHelper.isPipMode = false;
        // Queue restoration before raising the singleTask host: Android can
        // destroy/reparent this Activity while bringing MainActivity forward.
        // Dart marks the session restoring now and waits for its foreground frame.
        channel.invokeMethod("restore", envelope(map("waitForForeground", true)), new MethodChannel.Result() {
            @Override public void success(Object value) {
                if (activity != playbackActivity) return;
                if (Boolean.TRUE.equals(value)) {
                    close();
                    emitStopped(activity.sessionId, false);
                }
            }
            @Override public void error(String code, String message, Object details) {
                if (activity == playbackActivity) fail(message);
            }
            @Override public void notImplemented() {
                if (activity == playbackActivity) fail("Restore unavailable");
            }
        });
        bringHostToFront();
    }

    void dismissed(PipActivity activity) {
        if (activity != playbackActivity || activity.isRestoring()) return;
        long id = sessionId();
        close();
        emitStopped(id, true);
    }

    void fail(String message) {
        Log.w("PiliPlus/PiP", "session=" + sessionId() + " sdk=" + Build.VERSION.SDK_INT +
                " device=" + Build.MANUFACTURER + "/" + Build.MODEL + ": " + message);
        long id = sessionId();
        close();
        channel.invokeMethod("onStateChanged", map("sessionId", id,
                "value", map("active", false, "error", message == null ? "PiP failed" : message)));
    }

    private void bringHostToFront() {
        Context context = host != null ? host : applicationContext;
        if (context != null) context.startActivity(new Intent(context, MainActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT |
                        Intent.FLAG_ACTIVITY_NO_ANIMATION),
                ActivityOptions.makeCustomAnimation(context, 0, 0).toBundle());
    }

    private static Map<String, Object> map(Object... entries) {
        Map<String, Object> result = new HashMap<>();
        for (int i = 0; i < entries.length; i += 2) result.put((String) entries[i], entries[i + 1]);
        return result;
    }

    private Map<String, Object> envelope(Object value) {
        Map<String, Object> result = new HashMap<>();
        result.put("sessionId", sessionId());
        result.put("value", value);
        return result;
    }

    private void emit(String method, Object value) { channel.invokeMethod(method, envelope(value)); }

    private void emitStopped(long id, boolean closed) {
        channel.invokeMethod("onStateChanged", map("sessionId", id,
                "value", map("active", false, "closed", closed)));
    }

    private void close() {
        launching = autoEnter = false;
        AndroidHelper.isPipMode = false;
        configuration = null;
        PipActivity activity = playbackActivity;
        playbackActivity = null;
        if (activity != null) activity.finishFromApp();
    }

    static Activity pipActivity() { return instance == null ? null : instance.playbackActivity; }

    static long retainSurface(Surface surface) { return MediaKitAndroidHelper.newGlobalObjectRef(surface); }
    static void releaseSurface(long reference, Surface surface, SurfaceTexture texture) {
        // mpv drops the old output asynchronously, just as media_kit does.
        new Handler(Looper.getMainLooper()).postDelayed(
                () -> {
                    if (reference != 0) MediaKitAndroidHelper.deleteGlobalObjectRef(reference);
                    if (surface != null) surface.release();
                    if (texture != null) texture.release();
                }, 5000);
    }
}
