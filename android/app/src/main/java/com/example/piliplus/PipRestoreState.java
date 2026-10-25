package com.example.piliplus;

/** PiP expansion must work with either Android lifecycle callback order. */
final class PipRestoreState {
    private boolean started;
    private boolean resumed;
    private boolean restoring;
    private boolean closed;

    void started() { started = true; }

    boolean resumed(boolean inPip) {
        resumed = true;
        return modeChanged(inPip);
    }

    void paused() { resumed = false; }

    boolean modeChanged(boolean inPip) {
        if (!resumed || !started || inPip || restoring || closed) return false;
        restoring = true;
        return true;
    }

    boolean shouldDismiss() { return started && !restoring && !closed; }

    void close() { closed = true; }
}
