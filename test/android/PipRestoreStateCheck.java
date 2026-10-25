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
        beforeResume.paused();
        check(!beforeResume.modeChanged(false), "wait for the expanded Activity to resume");
        check(beforeResume.resumed(false), "mode callback before onResume restores");
        check(!beforeResume.modeChanged(false), "restore exactly once");
        check(!beforeResume.shouldDismiss(), "moving behind the host during restore is not closing");

        PipRestoreState afterResume = new PipRestoreState();
        afterResume.started();
        check(!afterResume.resumed(true), "onResume can still report PiP");
        check(afterResume.modeChanged(false), "mode callback after onResume also restores");
        check(!afterResume.resumed(false), "repeated onResume must not duplicate navigation");

        PipRestoreState dismissed = new PipRestoreState();
        dismissed.started();
        dismissed.paused();
        check(dismissed.shouldDismiss(), "closing the PiP window releases playback");
        dismissed.close();
        check(!dismissed.resumed(false), "a closed window cannot restore later");
        check(!dismissed.shouldDismiss(), "app-driven close must not report a user dismissal");
        System.out.println("PiP restore lifecycle checks passed");
    }
}
