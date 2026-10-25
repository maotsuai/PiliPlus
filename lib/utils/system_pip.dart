import 'dart:async';

import 'package:PiliPlus/plugin/pl_player/utils/android_surface.dart';
import 'package:PiliPlus/plugin/pl_player/utils/pip_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// Native system PiP on iOS and a dedicated video Activity on Android.
abstract final class SystemPipHelper {
  static const _channel = MethodChannel('com.example.piliplus/pip');
  static bool isAvailable = false;
  static bool isActive = false;
  static bool _autoEnter = false;
  static int _sessionId = 0;
  static int? _textureId;
  static PipPlaybackSession? _playback;
  static String Function()? _playbackKey;
  static String? _activeKey;
  static AndroidSurfaceTarget? Function()? _androidSurface;
  static VoidCallback? _play;
  static VoidCallback? _pause;
  static ValueChanged<int>? _skip;
  static VoidCallback? _onRestored;
  static bool get needsUpdate => isActive || _autoEnter;
  static bool get isDetached => _playback?.detached == true;

  static Future<void> init() async {
    _channel.setMethodCallHandler(_onMethodCall);
    try {
      isAvailable = await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('SystemPipHelper init: $e');
    }
  }

  static void bind(
    PipPlaybackSession session, {
    required String Function() playbackKey,
    AndroidSurfaceTarget? Function()? androidSurface,
    required VoidCallback onPlay,
    required VoidCallback onPause,
    required ValueChanged<int> onSkip,
    required VoidCallback onRestored,
  }) {
    _playback = session;
    _playbackKey = playbackKey;
    _androidSurface = androidSurface;
    _play = onPlay;
    _pause = onPause;
    _skip = onSkip;
    _onRestored = onRestored;
  }

  static Future<Object?> _onMethodCall(MethodCall call) async {
    final envelope = call.arguments as Map;
    if (envelope['sessionId'] != _sessionId) return false;
    final value = envelope['value'];
    switch (call.method) {
      case 'surface':
        final args = value as Map;
        return _androidSurface?.call()?.attachExternalSurface(
              args['wid'] as int,
              args['width'] as int,
              args['height'] as int,
            ) ??
            false;
      case 'onStateChanged':
        final args = value as Map;
        isActive = args['active'] as bool;
        if (args['started'] == true) {
          _activeKey = _playbackKey?.call();
          await _playback?.didStart();
          if (envelope['sessionId'] != _sessionId) return false;
        }
        if (args['error'] != null) {
          _restoreAndroidSurface();
          if (WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) {
            SmartDialog.showToast('画中画启动失败');
          }
        }
        if (!isActive &&
            _playback?.detached == true &&
            _playback?.restoring != true) {
          final session = _playback;
          _playback = null;
          dispose();
          session?.close();
        }
        if (!isActive &&
            args['error'] == null &&
            args['closed'] != true &&
            _playback != null) {
          _onRestored?.call();
        }
      case 'restore':
        _restoreAndroidSurface();
        final session = _playback;
        if (session?.detached != true) return false;
        final waitForForeground =
            value is Map && value['waitForForeground'] == true;
        final foreground = waitForForeground ? _PipForegroundWaiter() : null;
        try {
          // Mark restoration immediately, before the native window is stopped.
          // Navigation waits for MainActivity to be visible and ready to draw.
          final restored = await session!.restore(ready: foreground?.ready);
          if (restored && waitForForeground) {
            await WidgetsBinding.instance.endOfFrame;
          }
          return restored;
        } finally {
          foreground?.dispose();
        }
      case 'setPlaying':
        if (value as bool) {
          _play?.call();
        } else {
          _pause?.call();
        }
      case 'skip':
        _skip?.call(value as int);
    }
    return null;
  }

  static void enter(
    int textureId, {
    required int? width,
    required int? height,
    required bool autoEnter,
    required Map<String, Object> state,
  }) {
    if (!isAvailable) return;
    if (_textureId != textureId) {
      _textureId = textureId;
      _sessionId++;
    }
    if (autoEnter) {
      _autoEnter = true;
    } else {
      // Activity transitions must not pause playback before the OS starts PiP.
      isActive = true;
    }
    final sessionId = _sessionId;
    _channel
        .invokeMethod('enter', {
          'sessionId': _sessionId,
          'textureId': textureId,
          'width': ?width,
          'height': ?height,
          'autoEnter': autoEnter,
          ...state,
        })
        .catchError((Object error) {
          if (sessionId != _sessionId) return;
          isActive = false;
          _restoreAndroidSurface();
          if (kDebugMode) debugPrint('SystemPipHelper enter: $error');
          SmartDialog.showToast('画中画启动失败');
        });
  }

  static void update(Map<String, Object> state) {
    _channel.invokeMethod('update', state);
  }

  static void _restoreAndroidSurface() {
    _androidSurface?.call()?.detachExternalSurface();
  }

  static void closeForNewPlayback({String? playbackKey}) {
    if ((isActive || isDetached) &&
        (_playback?.restoring != true ||
            playbackKey == null ||
            playbackKey != _activeKey)) {
      final session = _playback;
      _playback = null;
      dispose();
      session?.close();
    }
  }

  static bool completeRestore() {
    final session = _playback;
    if (session?.restoring != true) return false;
    _playback = null;
    return session!.completeRestore();
  }

  static void disableAutoEnter() {
    if (_autoEnter) {
      _autoEnter = false;
      _channel.invokeMethod('disableAutoEnter');
    }
  }

  static void dispose() {
    _restoreAndroidSurface();
    _sessionId++;
    _textureId = null;
    isActive = _autoEnter = false;
    _playback = null;
    _playbackKey = null;
    _activeKey = null;
    _androidSurface = null;
    _play = _pause = _onRestored = null;
    _skip = null;
    _channel.invokeMethod('dispose');
  }
}

class _PipForegroundWaiter with WidgetsBindingObserver {
  _PipForegroundWaiter() {
    final binding = WidgetsBinding.instance;
    if (binding.lifecycleState == AppLifecycleState.resumed) {
      _ready.complete();
    } else {
      binding.addObserver(this);
    }
  }

  final _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) dispose();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_ready.isCompleted) _ready.complete();
  }
}
