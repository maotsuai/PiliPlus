import 'dart:async';

/// Retries a stalled stream, without keeping a suspended OS process alive.
class PlaybackWatchdog {
  PlaybackWatchdog({required this.onStalled, this.onError});

  final Future<void> Function(bool Function() isCurrent) onStalled;
  final void Function(Object error, StackTrace stack)? onError;

  Timer? _timer;
  Duration _position = Duration.zero;
  int _generation = 0;
  int _attempts = 0;
  Duration _progressAfterRetry = Duration.zero;
  bool _active = false;
  bool _recovering = false;

  void start(Duration position) {
    stop();
    _active = true;
    _position = position;
    _attempts = 0;
    _progressAfterRetry = Duration.zero;
    _schedule();
  }

  void stop() {
    _active = false;
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  void onPosition(Duration position) {
    if (!_active) return;
    final previous = _position;
    _position = position;
    // Opening media emits reset/seek positions, which are not playback progress.
    if (_recovering || position == previous) return;
    final delta = position - previous;
    if (delta > Duration.zero && delta < const Duration(seconds: 5)) {
      _progressAfterRetry += delta;
      // A reset or a restored seek position alone must not reset the budget.
      if (_progressAfterRetry >= const Duration(seconds: 5)) _attempts = 0;
    } else {
      _progressAfterRetry = Duration.zero;
    }
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (!_active || _attempts >= 3) return;
    // Give slow networks progressively longer to recover: 8, 16, 32 seconds.
    _timer = Timer(Duration(seconds: 8 << _attempts), _check);
  }

  Future<void> _check() async {
    if (!_active) return;
    // A cancelled generation may still be finishing an asynchronous open.
    if (_recovering) {
      _schedule();
      return;
    }
    final generation = _generation;
    bool isCurrent() => _active && generation == _generation;
    _recovering = true;
    _progressAfterRetry = Duration.zero;
    _attempts++;
    try {
      await onStalled(isCurrent);
    } catch (error, stack) {
      onError?.call(error, stack);
    } finally {
      _recovering = false;
      if (isCurrent()) _schedule();
    }
  }
}
