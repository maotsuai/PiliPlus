package com.example.piliplus;

/** Runs with plain javac/java, without Android runtime stubs. */
public final class PipRestoreStateCheck {
    private static void check(boolean value, String description) {
        if (!value) throw new AssertionError(description);
    }

    public static void main(String[] args) {
        PipRestoreState beforeResume = new PipRestoreState();
        check(!beforeResume.resumed(false), "initial launch must not restore");
        beforeResume.started();
        check(beforeResume.modeChanged(false), "expansion starts restoration before onResume");
        check(!beforeResume.resumed(false), "onResume does not duplicate the queued restoration");
        check(!beforeResume.modeChanged(false), "restore exactly once");
        check(beforeResume.isRestoring(), "host reordering may destroy the native Activity during restoration");
        check(!beforeResume.shouldDismiss(true), "moving behind the host during restore is not closing");

        PipRestoreState stoppedFirst = new PipRestoreState();
        stoppedFirst.started();
        check(stoppedFirst.stopped(false, false), "onStop outside PiP must preserve expansion before other callbacks");
        check(!stoppedFirst.shouldDismiss(false), "expansion onStop must not close retained playback");
        check(stoppedFirst.isRestoring(), "onDestroy must still be treated as restoration");
        check(!stoppedFirst.modeChanged(false), "a late mode callback cannot restore twice");

        PipRestoreState staleMode = new PipRestoreState();
        staleMode.started();
        check(!staleMode.stopped(true, false), "onStop may arrive before the new mode is visible");
        check(!staleMode.shouldDismiss(false), "a non-finishing onStop cannot discard playback");
        check(staleMode.modeChanged(false), "a subsequent mode callback still restores playback");
        check(staleMode.isRestoring(), "restoration survives the stale onStop mode query");

        PipRestoreState afterResume = new PipRestoreState();
        afterResume.started();
        check(!afterResume.resumed(true), "onResume can still report PiP");
        check(afterResume.modeChanged(false), "mode callback after onResume also restores");
        check(!afterResume.resumed(false), "repeated onResume must not duplicate navigation");

        PipRestoreState dismissed = new PipRestoreState();
        dismissed.started();
        check(!dismissed.stopped(true, true), "closing a PiP window does not restore the page");
        check(dismissed.shouldDismiss(true), "closing the PiP window releases playback");
        dismissed.close();
        check(!dismissed.resumed(false), "a closed window cannot restore later");
        check(!dismissed.shouldDismiss(true), "app-driven close must not report a user dismissal");
        check(!dismissed.isRestoring(), "app-driven close cancels restoration ownership");

        PipRestoreState background = new PipRestoreState();
        background.started();
        background.modeChanged(false);
        background.requestHostLaunch();
        check(!background.takeHostLaunch(false), "do not launch from a paused PiP Activity");
        background.pageRestored();
        check(!background.readyToFinish(), "background audio/page recovery is not foreground UI recovery");
        background.foregroundReady(true);
        check(background.takeHostLaunch(false), "launch the host from the resumed expanded Activity");
        check(!background.readyToFinish(), "keep restoration until the host window has focus");
        background.hostFocused();
        check(background.readyToFinish(), "page acknowledgment plus a focused host completes restoration");
        check(!background.takeHostLaunch(false), "focus/lifecycle callbacks cannot relaunch the host twice");

        PipRestoreState focusedFirst = new PipRestoreState();
        focusedFirst.started();
        focusedFirst.foregroundReady(true);
        focusedFirst.modeChanged(false);
        focusedFirst.requestHostLaunch();
        check(focusedFirst.takeHostLaunch(false), "in-app expansion can raise the host immediately");
        focusedFirst.hostFocused();
        check(!focusedFirst.readyToFinish(), "host focus alone does not discard an unrestored page");
        focusedFirst.pageRestored();
        check(focusedFirst.readyToFinish(), "either acknowledgment order completes restoration");

        PipRestoreState pendingClose = new PipRestoreState();
        pendingClose.started();
        pendingClose.modeChanged(false);
        pendingClose.requestHostLaunch();
        pendingClose.close();
        pendingClose.foregroundReady(true);
        pendingClose.pageRestored();
        pendingClose.hostFocused();
        check(!pendingClose.takeHostLaunch(false), "closing while pending cannot bring the app forward later");
        check(!pendingClose.readyToFinish(), "a canceled restoration cannot be completed by stale callbacks");

        PipRestoreState stillPip = new PipRestoreState();
        stillPip.started();
        stillPip.foregroundReady(true);
        stillPip.requestHostLaunch();
        check(!stillPip.takeHostLaunch(true), "ordinary PiP playback must never pull the app forward");
        System.out.println("PiP restore lifecycle checks passed");
    }
}
