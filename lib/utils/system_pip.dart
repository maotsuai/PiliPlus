import 'dart:io';

import 'package:PiliPlus/plugin/pl_player/utils/pip_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:media_kit/media_kit.dart';

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
  static NativePlayer? Function()? _getPlayer;
  static VoidCallback? _play;
  static VoidCallback? _pause;
  static ValueChanged<int>? _skip;
  static VoidCallback? _onRestored;
  static String? _inlineSurface;
  static String? _inlineSurfaceSize;
  static String? _pipSurface;
  static String? _pipSurfaceSize;
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
    required NativePlayer? Function() player,
    required VoidCallback onPlay,
    required VoidCallback onPause,
    required ValueChanged<int> onSkip,
    required VoidCallback onRestored,
  }) {
    _playback = session;
    _playbackKey = playbackKey;
    _getPlayer = player;
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
        final player = _getPlayer?.call();
        if (player == null) return false;
        _inlineSurface ??= player.getProperty('wid');
        _inlineSurfaceSize ??= player.getProperty('android-surface-size');
        _pipSurfaceSize = '${args['width']}x${args['height']}';
        final surface = args['wid'].toString();
        if (_pipSurface == surface) {
          player.setProperty('android-surface-size', _pipSurfaceSize!);
          return true;
        }
        _pipSurface = surface;
        player
          ..setProperty('vo', 'null')
          ..setProperty('android-surface-size', _pipSurfaceSize!)
          ..setProperty('wid', _pipSurface!)
          ..setProperty('vo', 'gpu');
        return true;
      case 'onStateChanged':
        final args = value as Map;
        isActive = args['active'] as bool;
        if (args['started'] == true) {
          _activeKey = _playbackKey?.call();
          _playback?.didStart();
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
        if (session?.detached != true) return true;
        session!.restore();
        await WidgetsBinding.instance.endOfFrame;
        return !session.detached;
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

  /// media_kit may recreate its inline surface when reconnecting a live stream.
  static void reattachAndroidSurface() {
    if (_pipSurface case final surface? when Platform.isAndroid && isDetached) {
      final player = _getPlayer?.call();
      if (player == null) return;
      final inline = player.getProperty('wid');
      if (inline == surface) return;
      _inlineSurface = inline;
      _inlineSurfaceSize = player.getProperty('android-surface-size');
      player
        ..setProperty('vo', 'null')
        ..setProperty('android-surface-size', _pipSurfaceSize!)
        ..setProperty('wid', surface)
        ..setProperty('vo', 'gpu');
    }
  }

  static void _restoreAndroidSurface() {
    if (Platform.isAndroid && _inlineSurface != null) {
      if (_getPlayer?.call() case final player?) {
        player.setProperty('vo', 'null');
        if (_inlineSurfaceSize case final size?) {
          player.setProperty('android-surface-size', size);
        }
        player
          ..setProperty('wid', _inlineSurface!)
          ..setProperty('vo', 'gpu');
      }
    }
    _inlineSurface = _inlineSurfaceSize = _pipSurface = _pipSurfaceSize = null;
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
    _getPlayer = null;
    _play = _pause = _onRestored = null;
    _skip = null;
    _channel.invokeMethod('dispose');
  }
}
