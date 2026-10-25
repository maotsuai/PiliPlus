import 'dart:async';

import 'package:PiliPlus/plugin/pl_player/video_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

class _VideoStream extends Fake implements PlayerStream {
  final params = StreamController<VideoParams>.broadcast();

  @override
  Stream<VideoParams> get videoParams => params.stream;
}

class _Player extends Fake implements Player {
  _Player(this.handle);

  @override
  final int handle;
  @override
  final _VideoStream stream = _VideoStream();
  @override
  final List<Future<void> Function()> release = [];
  @override
  final List<FutureOr<void> Function()> onLoadHooks = [];
  @override
  final List<FutureOr<void> Function()> onUnloadHooks = [];
  final writes = <(String, String)>[];

  @override
  void setProperty(String name, String value) => writes.add((name, value));

  Future<void> sendSize(VideoParams value) async {
    stream.params.add(value);
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<void> dispose() async {
    for (final callback in release) {
      await callback();
    }
    await stream.params.close();
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.alexmercerind/media_kit_video');
  var nextHandle = 0;
  late List<_Player> players;
  late List<MethodCall> calls;

  setUp(() {
    players = [];
    calls = [];
    var surface = 10;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return switch (call.method) {
        'VideoOutputManager.Create' => {'id': ++surface},
        'VideoOutputManager.CreateSurface' => {'wid': ++surface},
        _ => null,
      };
    });
  });

  tearDown(() async {
    for (final player in players) {
      await player.dispose();
    }
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  Future<(_Player, PiliAndroidVideoController)> create() async {
    final player = _Player(++nextHandle);
    players.add(player);
    final controller = await PiliAndroidVideoController.create(player);
    await player.onLoadHooks.single();
    await player.sendSize(const VideoParams(dw: 1920, dh: 1080));
    player.writes.clear();
    return (player, controller);
  }

  test(
    'codec parameter updates cannot replace the selected PiP output',
    () async {
      final (player, controller) = await create();
      controller.attachExternalSurface(50, 480, 270);
      player.writes.clear();
      for (var i = 0; i < 20; i++) {
        await player.sendSize(
          VideoParams(dw: 1920, dh: 1080, gamma: 'gamma$i'),
        );
      }
      await player.sendSize(const VideoParams(dw: 1280, dh: 720));
      expect(player.writes, isEmpty);
      expect(controller.rect.value!.size.width, 1280);
      controller.detachExternalSurface();
      expect(
        player.writes.where((entry) => entry.$1 == 'android-surface-size'),
        [('android-surface-size', '1280x720')],
      );
    },
  );

  test(
    'live reconnection selects PiP again without exposing the inline output',
    () async {
      final (player, controller) = await create();
      controller.attachExternalSurface(50, 480, 270);
      await player.onUnloadHooks.single();
      player.writes.clear();
      await player.onLoadHooks.single();
      expect(player.writes.where((entry) => entry.$1 == 'wid'), [
        ('wid', '50'),
      ]);
      controller.detachExternalSurface();
      expect(player.writes.last, ('vo', 'gpu'));
      final inline = player.writes.lastWhere((entry) => entry.$1 == 'wid').$2;
      expect(inline, isNot('50'));
    },
  );

  test(
    'first-frame events are routed to the correct shared-channel controller',
    () async {
      final (firstPlayer, first) = await create();
      final (secondPlayer, second) = await create();
      var firstReady = false;
      var secondReady = false;
      first.waitUntilFirstFrameRendered.then((_) => firstReady = true);
      second.waitUntilFirstFrameRendered.then((_) => secondReady = true);
      const codec = StandardMethodCodec();
      Future<void> firstFrame(int handle) =>
          binding.defaultBinaryMessenger.handlePlatformMessage(
            channel.name,
            codec.encodeMethodCall(
              MethodCall('VideoOutput.WaitUntilFirstFrameRenderedNotify', {
                'handle': handle,
              }),
            ),
            (_) {},
          );
      await firstFrame(secondPlayer.handle);
      expect(secondReady, isTrue);
      expect(firstReady, isFalse);
      await firstFrame(firstPlayer.handle);
      expect(firstReady, isTrue);
    },
  );

  test(
    'a disposed output no longer accepts native Surface notifications',
    () async {
      final (player, controller) = await create();
      await player.dispose();
      players.remove(player);
      expect(controller.attachExternalSurface(50, 480, 270), isFalse);
      expect(calls.last.method, 'VideoOutputManager.Dispose');
    },
  );
}
