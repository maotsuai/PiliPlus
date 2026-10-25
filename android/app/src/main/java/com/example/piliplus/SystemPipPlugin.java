package com.example.piliplus;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
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
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    .putExtra("sessionId", id)
                    .putExtra("leavingApp", leavingApp);
            host.startActivity(intent);
            handler.postDelayed(() -> {
                if (launching && sessionId() == id) fail("PiP activity did not start");
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
        if (activity != playbackActivity) return;
        channel.invokeMethod("surface", envelope(map("wid", wid, "width", width, "height", height)),
                new MethodChannel.Result() {
                    @Override public void success(Object value) {
                        if (activity != playbackActivity) return;
                        if (Boolean.TRUE.equals(value)) activity.enterPip();
                        else fail("Could not attach the playback surface");
                    }
                    @Override public void error(String code, String message, Object details) {
                        if (activity == playbackActivity) fail(message);
                    }
                    @Override public void notImplemented() {
                        if (activity == playbackActivity) fail("Surface handoff unavailable");
                    }
                });
    }

    void started(PipActivity activity) {
        if (activity != playbackActivity) return;
        launching = false;
        AndroidHelper.isPipMode = true;
        emit("onStateChanged", map("active", true, "started", true));
        if (!activity.getIntent().getBooleanExtra("leavingApp", false)) bringHostToFront();
    }

    void restore(PipActivity activity) {
        if (activity != playbackActivity) return;
        AndroidHelper.isPipMode = false;
        // Resume the Flutter engine before Dart waits for the restored page's frame.
        bringHostToFront();
        channel.invokeMethod("restore", envelope(null), new MethodChannel.Result() {
            @Override public void success(Object value) {
                if (activity != playbackActivity) return;
                close();
                emitStopped(activity.sessionId, false);
            }
            @Override public void error(String code, String message, Object details) {
                if (activity == playbackActivity) fail(message);
            }
            @Override public void notImplemented() {
                if (activity == playbackActivity) fail("Restore unavailable");
            }
        });
    }

    void dismissed(PipActivity activity) {
        if (activity != playbackActivity) return;
        long id = sessionId();
        close();
        emitStopped(id, true);
    }

    void fail(String message) {
        long id = sessionId();
        close();
        channel.invokeMethod("onStateChanged", map("sessionId", id,
                "value", map("active", false, "error", message == null ? "PiP failed" : message)));
    }

    private void bringHostToFront() {
        Context context = host != null ? host : applicationContext;
        if (context != null) context.startActivity(new Intent(context, MainActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT));
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
    static void releaseSurface(long reference) {
        // mpv drops the old output asynchronously, just as media_kit does.
        new Handler(Looper.getMainLooper()).postDelayed(
                () -> MediaKitAndroidHelper.deleteGlobalObjectRef(reference), 5000);
    }
}
