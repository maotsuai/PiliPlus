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
  final Future<void> Function(bool Function() isCurrent)? onReady;

  bool detached = false;
  bool restoring = false;
  int _generation = 0;
  Future<void>? _minimizing;
  Completer<bool>? _restoreResult;

  Future<void> didStart() async {
    if (detached) return;
    final generation = ++_generation;
    detached = true;
    onRetain();
    await (_minimizing = Future<void>.sync(onMinimize));
    if (generation == _generation && detached && !restoring) {
      await onReady?.call(
        () => generation == _generation && detached && !restoring,
      );
    }
  }

  Future<bool> restore({Future<void>? ready}) {
    if (!detached) return Future.value(false);
    if (restoring) return _restoreResult!.future;
    restoring = true;
    final generation = ++_generation;
    final result = _restoreResult = Completer<bool>();
    _restoreWhenReady(generation, result, ready);
    return result.future;
  }

  Future<void> _restoreWhenReady(
    int generation,
    Completer<bool> result,
    Future<void>? ready,
  ) async {
    try {
      // Expansion may precede the host's resume or the outgoing route's disposal.
      await _minimizing;
      if (ready != null) await ready;
      if (generation == _generation && detached && restoring) onRestore();
    } catch (error, stack) {
      if (!result.isCompleted) result.completeError(error, stack);
      if (identical(_restoreResult, result)) {
        _restoreResult = null;
        restoring = false;
      }
    }
  }

  bool completeRestore() {
    if (!restoring) return false;
    detached = restoring = false;
    onRelease(false);
    _finishRestore(true);
    return true;
  }

  void close() {
    _generation++;
    final release = detached;
    detached = restoring = false;
    if (release) onRelease(true);
    _finishRestore(false);
  }

  void _finishRestore(bool restored) {
    final result = _restoreResult;
    _restoreResult = null;
    if (result != null && !result.isCompleted) result.complete(restored);
  }
}
