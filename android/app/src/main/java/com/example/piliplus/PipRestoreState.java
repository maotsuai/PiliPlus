package com.example.piliplus;

/** Expansion owns playback even if Android stops/destroys the PiP Activity first. */
final class PipRestoreState {
    private boolean started;
    private boolean restoring;
    private boolean closed;

    void started() { started = true; }

    boolean resumed(boolean inPip) {
        return modeChanged(inPip);
    }

    boolean modeChanged(boolean inPip) {
        if (!started || inPip || restoring || closed) return false;
        restoring = true;
        return true;
    }

    boolean stopped(boolean inPip, boolean finishing) {
        return !finishing && modeChanged(inPip);
    }

    boolean isRestoring() { return restoring && !closed; }

    boolean shouldDismiss(boolean finishing) {
        return finishing && started && !restoring && !closed;
    }

    void close() { closed = true; }
}
