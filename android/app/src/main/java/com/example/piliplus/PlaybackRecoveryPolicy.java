package com.example.piliplus;

/** One bounded wake-lock window per stall, independent of Android APIs. */
public final class PlaybackRecoveryPolicy {
    public static final long TIMEOUT_MS = 60_000;
    private boolean playing;
    private boolean allowed;
    private boolean buffering;
    private boolean requested;
    private boolean expired;
    private long deadline;
    private long progressStarted = -1;
    private long lastProgress = -1;

    public void update(boolean playing, boolean allowed, boolean buffering, long now) {
        this.playing = playing;
        this.allowed = allowed;
        this.buffering = buffering;
        expireIfDue(now);
        if (!playing || !allowed) {
            reset();
        } else if (buffering) {
            resetProgress();
            if (!requested && !expired) {
                requested = true;
                deadline = now + TIMEOUT_MS;
            }
        }
    }

    public void progress(long now) {
        expireIfDue(now);
        if (!playing || !allowed || buffering) return;
        if (lastProgress < 0 || now < lastProgress || now - lastProgress > 2500) {
            progressStarted = now;
        }
        lastProgress = now;
        if (now - progressStarted >= 2000) {
            requested = false;
            expired = false;
            deadline = 0;
        }
    }

    public long remainingMillis(long now) {
        expireIfDue(now);
        return requested ? Math.max(0, deadline - now) : 0;
    }

    public void expire() {
        requested = false;
        expired = true;
        deadline = 0;
        resetProgress();
    }

    public void reset() {
        playing = false;
        allowed = false;
        buffering = false;
        requested = false;
        expired = false;
        deadline = 0;
        resetProgress();
    }

    private void expireIfDue(long now) {
        if (requested && now >= deadline) expire();
    }

    private void resetProgress() {
        progressStarted = -1;
        lastProgress = -1;
    }
}
