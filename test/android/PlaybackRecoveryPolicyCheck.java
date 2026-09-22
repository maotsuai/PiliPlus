package com.example.piliplus;

/** Standalone JVM checks; compile with PlaybackRecoveryPolicy.java. */
public final class PlaybackRecoveryPolicyCheck {
    public static void main(String[] args) {
        check("normal playback does not request an extra lock", () -> {
            PlaybackRecoveryPolicy p = new PlaybackRecoveryPolicy();
            p.update(true, true, false, 0);
            require(p.remainingMillis(0) == 0);
        });
        check("background playback must be enabled", () -> {
            PlaybackRecoveryPolicy p = new PlaybackRecoveryPolicy();
            p.update(true, false, true, 0);
            require(p.remainingMillis(0) == 0);
        });
        check("buffering gets one 60-second window", () -> {
            PlaybackRecoveryPolicy p = bufferingPolicy();
            require(p.remainingMillis(0) == 60_000);
            require(p.remainingMillis(15_000) == 45_000);
        });
        check("repeated buffering cannot extend the deadline", () -> {
            PlaybackRecoveryPolicy p = bufferingPolicy();
            p.update(true, true, true, 25_000);
            p.update(true, true, false, 30_000);
            p.update(true, true, true, 40_000);
            require(p.remainingMillis(40_000) == 20_000);
        });
        check("expiry prevents automatic reacquisition", () -> {
            PlaybackRecoveryPolicy p = bufferingPolicy();
            require(p.remainingMillis(60_000) == 0);
            p.update(true, true, true, 61_000);
            p.update(true, true, false, 62_000);
            p.update(true, true, true, 63_000);
            require(p.remainingMillis(63_000) == 0);
        });
        check("two seconds of real progress releases early", () -> {
            PlaybackRecoveryPolicy p = bufferingPolicy();
            p.update(true, true, false, 1000);
            p.progress(1000);
            p.progress(2000);
            require(p.remainingMillis(2000) > 0);
            p.progress(3000);
            require(p.remainingMillis(3000) == 0);
        });
        check("a progress gap does not count as recovered playback", () -> {
            PlaybackRecoveryPolicy p = bufferingPolicy();
            p.update(true, true, false, 1000);
            p.progress(1000);
            p.progress(10_000);
            require(p.remainingMillis(10_000) > 0);
            p.progress(11_000);
            p.progress(12_000);
            require(p.remainingMillis(12_000) == 0);
        });
        check("pause and interruption release immediately", () -> {
            PlaybackRecoveryPolicy p = bufferingPolicy();
            p.update(false, true, true, 1000);
            require(p.remainingMillis(1000) == 0);
            p.progress(2000);
            require(p.remainingMillis(2000) == 0);
        });
        check("disabling background playback releases immediately", () -> {
            PlaybackRecoveryPolicy p = bufferingPolicy();
            p.update(true, false, true, 1000);
            require(p.remainingMillis(1000) == 0);
        });
        check("destroying the activity or engine clears the lease", () -> {
            PlaybackRecoveryPolicy p = bufferingPolicy();
            p.reset();
            p.progress(1000);
            require(p.remainingMillis(1000) == 0);
        });
        check("failed acquisition cannot spin on retries", () -> {
            PlaybackRecoveryPolicy p = bufferingPolicy();
            p.expire();
            p.update(true, true, true, 1000);
            require(p.remainingMillis(1000) == 0);
        });
        check("recovered playback permits a new window for a later stall", () -> {
            PlaybackRecoveryPolicy p = bufferingPolicy();
            p.expire();
            p.update(true, true, false, 1000);
            p.progress(1000);
            p.progress(2000);
            p.progress(3000);
            p.update(true, true, true, 4000);
            require(p.remainingMillis(4000) == 60_000);
        });
        System.out.println("All 12 Android recovery policy checks passed.");
    }

    private static PlaybackRecoveryPolicy bufferingPolicy() {
        PlaybackRecoveryPolicy p = new PlaybackRecoveryPolicy();
        p.update(true, true, true, 0);
        return p;
    }

    private static void check(String name, Runnable body) {
        body.run();
        System.out.println("PASS: " + name);
    }

    private static void require(boolean condition) {
        if (!condition) throw new AssertionError("Recovery policy violated");
    }
}
