/// Owns one playback reference while its page is absent. The OS owns the UI.
class PipPlaybackSession {
  PipPlaybackSession({
    required this.onRetain,
    required this.onRelease,
    required this.onMinimize,
    required this.onRestore,
  });

  final void Function() onRetain;
  final void Function(bool stop) onRelease;
  final void Function() onMinimize;
  final void Function() onRestore;

  bool detached = false;
  bool restoring = false;

  void didStart() {
    if (detached) return;
    detached = true;
    onRetain();
    onMinimize();
  }

  void restore() {
    if (!detached || restoring) return;
    restoring = true;
    onRestore();
  }

  bool completeRestore() {
    if (!restoring) return false;
    detached = restoring = false;
    onRelease(false);
    return true;
  }

  void close() {
    final release = detached;
    detached = restoring = false;
    if (release) onRelease(true);
  }
}
