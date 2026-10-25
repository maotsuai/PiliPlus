// Android integration adapted from media_kit_video's AndroidVideoController.
//
// MIT License
// Copyright (c) 2021 & onwards Hitesh Kumar Saini <saini123hitesh@gmail.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/plugin/pl_player/utils/android_surface.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:synchronized/synchronized.dart';

Future<VideoController> createVideoController(
  Player player, {
  VideoControllerConfiguration configuration =
      const VideoControllerConfiguration(),
}) => Platform.isAndroid
    ? PiliAndroidVideoController.create(player, configuration: configuration)
    : VideoController.create(player, configuration: configuration);

/// Selects inline or system PiP output without competing with another owner.
class PiliAndroidVideoController extends PlatformVideoController
    implements AndroidSurfaceTarget {
  PiliAndroidVideoController._(super.player, super.configuration) {
    _surface = AndroidSurfaceCoordinator(setProperty: player.setProperty);
  }

  static const _channel = MethodChannel('com.alexmercerind/media_kit_video');
  static final _controllers = <int, PiliAndroidVideoController>{};
  static bool _listening = false;

  final _lock = Lock();
  late final AndroidSurfaceCoordinator _surface;
  StreamSubscription<VideoParams>? _sizeSubscription;
  int _width = 0;
  int _height = 0;
  bool _disposed = false;

  static Future<PiliAndroidVideoController> create(
    Player player, {
    VideoControllerConfiguration configuration =
        const VideoControllerConfiguration(),
  }) async {
    final existing = _controllers[player.handle];
    if (existing != null) return existing;
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'VideoOutput.WaitUntilFirstFrameRenderedNotify') {
          final handle = (call.arguments as Map)['handle'] as int;
          final controller = _controllers[handle];
          if (controller != null &&
              !controller.waitUntilFirstFrameRenderedCompleter.isCompleted) {
            controller.waitUntilFirstFrameRenderedCompleter.complete();
          }
        }
      });
    }

    final controller = PiliAndroidVideoController._(player, configuration);
    _controllers[player.handle] = controller;
    player.release.add(controller._dispose);

    final data = await _channel.invokeMapMethod<String, dynamic>(
      'VideoOutputManager.Create',
      {'handle': player.handle.toString()},
    );
    controller.id.value = data!['id'] as int;
    for (final entry in {
      'vo': 'null',
      'hwdec':
          configuration.hwdec ??
          (configuration.enableHardwareAcceleration ? 'auto-safe' : 'no'),
      'vid': 'auto',
      'opengl-es': 'yes',
      'force-window': 'no',
      'gpu-context': 'android',
      'sub-use-margins': 'no',
      'sub-font-provider': 'none',
      'sub-scale-with-window': 'yes',
      'hwdec-codecs': 'h264,hevc,mpeg4,mpeg2video,vp8,vp9,av1',
    }.entries) {
      player.setProperty(entry.key, entry.value);
    }
    player.onLoadHooks.add(controller._onLoad);
    player.onUnloadHooks.add(controller._onUnload);
    controller._sizeSubscription = player.stream.videoParams.listen(
      controller._updateVideoSize,
    );
    return controller;
  }

  Future<void> _onLoad() => _lock.synchronized(() async {
    if (_disposed) return;
    final data = await _channel.invokeMapMethod<String, dynamic>(
      'VideoOutputManager.CreateSurface',
      {'handle': player.handle.toString()},
    );
    if (_disposed) return;
    _surface.setInlineSurface(data!['wid'] as int, _width, _height);
  });

  Future<void> _onUnload() => _lock.synchronized(() {
    if (!_disposed) _surface.suspend();
  });

  Future<void> _updateVideoSize(VideoParams params) => _lock.synchronized(
    () async {
      if (_disposed) return;
      final rotated = params.rotate == 90 || params.rotate == 270;
      final width = (rotated ? params.dh : params.dw) ?? 0;
      final height = (rotated ? params.dw : params.dh) ?? 0;
      if (width <= 0 || height <= 0 || (width == _width && height == _height)) {
        return;
      }
      _width = width;
      _height = height;
      await _channel.invokeMethod<void>(
        'VideoOutputManager.SetSurfaceTextureSize',
        {
          'handle': player.handle.toString(),
          'width': width.toString(),
          'height': height.toString(),
        },
      );
      if (_disposed) return;
      _surface.updateInlineSize(width, height);
      rect.value = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    },
  );

  @override
  bool attachExternalSurface(int surface, int width, int height) =>
      !_disposed && _surface.attachExternalSurface(surface, width, height);

  @override
  void detachExternalSurface() {
    if (!_disposed) _surface.detachExternalSurface();
  }

  @override
  Future<void>? setSize({int? width, int? height}) =>
      throw UnsupportedError('Fixed output size is unavailable on Android');

  Future<void> _dispose() async {
    _disposed = true;
    _controllers.remove(player.handle);
    await _sizeSubscription?.cancel();
    await _channel.invokeMethod<void>('VideoOutputManager.Dispose', {
      'handle': player.handle.toString(),
    });
  }
}
