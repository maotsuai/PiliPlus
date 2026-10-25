package com.example.piliplus;

/** Expansion owns playback even if Android stops/destroys the PiP Activity first. */
final class PipRestoreState {
    private boolean started;
    private boolean restoring;
    private boolean closed;
    private boolean foregroundReady;
    private boolean hostLaunchRequested;
    private boolean hostLaunched;
    private boolean hostFocused;
    private boolean pageRestored;

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

    void foregroundReady(boolean ready) { foregroundReady = ready; }

    void requestHostLaunch() {
        if (isRestoring()) hostLaunchRequested = true;
    }

    boolean takeHostLaunch(boolean inPip) {
        if (!isRestoring() || !foregroundReady || inPip ||
                !hostLaunchRequested || hostLaunched) return false;
        hostLaunched = true;
        return true;
    }

    void pageRestored() { pageRestored = true; }

    void hostFocused() {
        if (isRestoring() && hostLaunched) hostFocused = true;
    }

    boolean readyToFinish() {
        return isRestoring() && hostLaunched && pageRestored && hostFocused;
    }

    boolean shouldDismiss(boolean finishing) {
        return finishing && started && !restoring && !closed;
    }

    void close() { closed = true; }
}
