import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Reports actual playback to the native, finite mobile recovery protection.
abstract final class PlaybackBackground {
  static const _channel = MethodChannel(
    'com.example.piliplus/playback_background',
  );
  static (bool, bool, bool)? _state;
  static final _clock = Stopwatch()..start();
  static int _lastReport = -1000;
  static Duration? _lastPosition;

  static Future<void> update({
    required bool playing,
    required bool allowed,
    required bool buffering,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    final state = (playing, allowed, buffering);
    if (_state == state) return;
    _state = state;
    _lastPosition = null;
    final delivered = await _invoke('update', {
      'playing': playing,
      'allowed': allowed,
      'buffering': buffering,
    });
    // Do not permanently suppress a state that failed to reach the native side.
    if (!delivered && _state == state) _state = null;
  }

  static void onPosition(Duration position) {
    if ((!Platform.isIOS && !Platform.isAndroid) ||
        _state != (true, true, false)) {
      return;
    }
    if (Platform.isIOS &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    final previous = _lastPosition;
    _lastPosition = position;
    if (previous == null || position <= previous) return;
    // A seek/reset is not proof that audio playback recovered.
    if (position - previous >= const Duration(seconds: 5)) return;
    final now = _clock.elapsedMilliseconds;
    if (now - _lastReport < 1000) return;
    _lastReport = now;
    _invoke('progress');
  }

  static Future<bool> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
      return true;
    } on PlatformException catch (error) {
      if (kDebugMode) debugPrint('Background playback: $error');
    } on MissingPluginException catch (error) {
      if (kDebugMode) debugPrint('Background playback: $error');
    }
    return false;
  }
}
