import 'dart:async';

/// Owns one playback reference while its page is absent. The OS owns the UI.
class PipPlaybackSession {
  PipPlaybackSession({
    required this.onRetain,
    required this.onRelease,
    required this.onMinimize,
    required this.onRestore,
    this.onReady,
  });

  final void Function() onRetain;
  final void Function(bool stop) onRelease;
  final FutureOr<void> Function() onMinimize;
  final void Function() onRestore;
  final Future<void> Function()? onReady;

  bool detached = false;
  bool restoring = false;
  int _generation = 0;

  Future<void> didStart() async {
    if (detached) return;
    final generation = ++_generation;
    detached = true;
    onRetain();
    await onMinimize();
    if (generation == _generation && detached && !restoring) {
      await onReady?.call();
    }
  }

  void restore() {
    if (!detached || restoring) return;
    restoring = true;
    _generation++;
    onRestore();
  }

  bool completeRestore() {
    if (!restoring) return false;
    detached = restoring = false;
    onRelease(false);
    return true;
  }

  void close() {
    _generation++;
    final release = detached;
    detached = restoring = false;
    if (release) onRelease(true);
  }
}
