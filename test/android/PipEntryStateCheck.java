package com.example.piliplus;

/** Runs with plain javac/java; checks both Surface/PiP callback orderings. */
public final class PipEntryStateCheck {
    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }

    public static void main(String[] args) {
        PipEntryState fallback = new PipEntryState();
        fallback.surfaceChanged(42, 1080, 1920);
        check(fallback.takeOutput() == null, "an unpinned launch cannot steal inline playback");
        check(fallback.requestEntry(), "a normal Activity launch must request PiP explicitly");
        check(!fallback.requestEntry(), "do not issue duplicate explicit requests");
        check(fallback.takeOutput() == null, "request acceptance alone is not PiP confirmation");
        fallback.modeChanged(true);
        PipEntryState.Output output = fallback.takeOutput();
        check(output != null && output.reference == 42, "confirmed PiP takes the video output");
        check(fallback.takeOutput() == null, "do not rebind an unchanged output");
        check(fallback.confirmOutput(42, 1080, 1920), "the attached output confirms startup");

        PipEntryState direct = new PipEntryState();
        check(direct.requestEntry(), "entry can start before TextureView supplies a Surface");
        direct.modeChanged(true);
        check(!direct.requestEntry(), "a pinned window needs no further entry request");
        check(direct.takeOutput() == null, "wait for the video Surface to exist");
        direct.surfaceChanged(8, 480, 270);
        check(direct.takeOutput() != null, "a late Surface can finish explicit entry");
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
