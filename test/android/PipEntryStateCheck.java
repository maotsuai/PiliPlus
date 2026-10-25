package com.example.piliplus;

/** Runs with plain javac/java; checks both direct-entry and explicit-entry paths. */
public final class PipEntryStateCheck {
    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }

    public static void main(String[] args) {
        PipEntryState fallback = new PipEntryState();
        fallback.surfaceChanged(42, 1080, 1920);
        check(fallback.takeOutput() == null, "an unpinned launch cannot steal inline playback");
        check(fallback.requestEntry(), "direct launch not taking effect must allow explicit entry");
        check(!fallback.requestEntry(), "do not issue duplicate explicit requests");
        check(fallback.takeOutput() == null, "request acceptance alone is not PiP confirmation");
        fallback.modeChanged(true);
        PipEntryState.Output output = fallback.takeOutput();
        check(output != null && output.reference == 42, "confirmed PiP takes the video output");
        check(fallback.takeOutput() == null, "do not rebind an unchanged output");
        check(fallback.confirmOutput(42, 1080, 1920), "the attached output confirms startup");

        PipEntryState direct = new PipEntryState();
        direct.modeChanged(true);
        check(!direct.requestEntry(), "successful direct launch needs no explicit request");
        check(direct.takeOutput() == null, "wait for the video Surface to exist");
        direct.surfaceChanged(8, 480, 270);
        check(direct.takeOutput() != null, "a late Surface can finish direct launch");
        direct.surfaceChanged(9, 480, 270);
        check(!direct.confirmOutput(8, 480, 270), "ignore an old Surface acknowledgment");
        check(direct.takeOutput().reference == 9, "attach the replacement Surface");
        direct.modeChanged(false);
        check(!direct.confirmOutput(9, 480, 270), "late acknowledgment after expansion is not startup");

        PipEntryState failed = new PipEntryState();
        failed.surfaceChanged(1, 1, 1);
        failed.requestEntry();
        failed.close();
        failed.modeChanged(true);
        check(failed.takeOutput() == null, "timeout closes pending output handoffs");
        check(!failed.confirmOutput(1, 1, 1), "a failed window cannot confirm startup later");
        System.out.println("PiP entry checks passed");
    }
}
