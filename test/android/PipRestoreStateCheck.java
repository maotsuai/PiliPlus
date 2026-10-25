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
        System.out.println("PiP restore lifecycle checks passed");
    }
}
