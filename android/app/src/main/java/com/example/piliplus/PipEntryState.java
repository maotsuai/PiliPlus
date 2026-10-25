package com.example.piliplus;

/** A launch request is not confirmation that Android has pinned the window. */
final class PipEntryState {
    static final class Output {
        final long reference;
        final int width;
        final int height;

        Output(long reference, int width, int height) {
            this.reference = reference;
            this.width = width;
            this.height = height;
        }

        boolean matches(Output other) {
            return other != null && reference == other.reference &&
                    width == other.width && height == other.height;
        }
    }

    private boolean inPip;
    private boolean requested;
    private boolean closed;
    private Output available;
    private Output submitted;

    void modeChanged(boolean inPip) { this.inPip = inPip; }

    boolean requestEntry() {
        if (closed || inPip || requested) return false;
        requested = true;
        return true;
    }

    void surfaceChanged(long reference, int width, int height) {
        available = reference != 0 && width > 0 && height > 0
                ? new Output(reference, width, height) : null;
        if (available == null) submitted = null;
    }

    Output takeOutput() {
        if (closed || !inPip || available == null || available.matches(submitted)) return null;
        submitted = available;
        return submitted;
    }

    boolean confirmOutput(long reference, int width, int height) {
        return !closed && inPip && new Output(reference, width, height).matches(available);
    }

    void close() { closed = true; }
}
