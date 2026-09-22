package com.example.piliplus;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.os.PowerManager;
import android.os.SystemClock;
import android.util.Log;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Supplementary CPU lock for recovery; normal playback belongs to audio_service. */
public final class PlaybackRecoveryPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private final PlaybackRecoveryPolicy policy = new PlaybackRecoveryPolicy();
    private final Handler handler = new Handler(Looper.getMainLooper());
    private PowerManager.WakeLock wakeLock;
    private MethodChannel channel;
    private final Runnable timeout = () -> {
        policy.expire();
        releaseLock();
    };

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        PowerManager manager = (PowerManager) binding.getApplicationContext()
                .getSystemService(Context.POWER_SERVICE);
        wakeLock = manager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,
                "PiliPlus:PlaybackRecovery");
        wakeLock.setReferenceCounted(false);
        channel = new MethodChannel(binding.getBinaryMessenger(),
                "com.example.piliplus/playback_background");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        long now = SystemClock.elapsedRealtime();
        switch (call.method) {
            case "update":
                Object playing = call.argument("playing");
                Object allowed = call.argument("allowed");
                Object buffering = call.argument("buffering");
                if (!(playing instanceof Boolean) || !(allowed instanceof Boolean)
                        || !(buffering instanceof Boolean)) {
                    result.error("invalid_state", "Missing playback state", null);
                    return;
                }
                policy.update((Boolean) playing, (Boolean) allowed, (Boolean) buffering, now);
                break;
            case "progress":
                policy.progress(now);
                break;
            default:
                result.notImplemented();
                return;
        }
        syncLock(now);
        result.success(null);
    }

    private void syncLock(long now) {
        long remaining = policy.remainingMillis(now);
        if (remaining == 0) {
            releaseLock();
        } else if (wakeLock != null && !wakeLock.isHeld()) {
            try {
                // Android's timeout and our cleanup callback share one fixed deadline.
                // Repeated buffering/retry notifications never call acquire again.
                wakeLock.acquire(remaining);
                handler.removeCallbacks(timeout);
                handler.postDelayed(timeout, remaining);
            } catch (RuntimeException error) {
                policy.expire();
                releaseLock();
                Log.w("PlaybackRecovery", "Unable to acquire recovery wake lock", error);
            }
        }
    }

    private void releaseLock() {
        handler.removeCallbacks(timeout);
        if (wakeLock != null && wakeLock.isHeld()) wakeLock.release();
    }

    public void stop() {
        policy.reset();
        releaseLock();
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        if (channel != null) channel.setMethodCallHandler(null);
        channel = null;
        stop();
        wakeLock = null;
    }
}
