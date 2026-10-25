import 'package:PiliPlus/plugin/pl_player/utils/pip_session.dart';
import 'package:PiliPlus/utils/system_pip.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.example.piliplus/pip');
  const codec = StandardMethodCodec();
  late List<MethodCall> calls;
  late List<String> events;

  Future<Object?> native(String method, int id, [Object? value]) async {
    Object? result;
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(
        MethodCall(method, {'sessionId': id, 'value': value}),
      ),
      (data) => result = codec.decodeEnvelope(data!),
    );
    return result;
  }

  PipPlaybackSession bind({bool completeOnRestore = true}) {
    final session = PipPlaybackSession(
      onRetain: () => events.add('retain'),
      onRelease: (stop) => events.add(stop ? 'stop' : 'handoff'),
      onMinimize: () => events.add('pop'),
      onRestore: () {
        events.add('push');
        if (completeOnRestore) {
          expectSync(SystemPipHelper.completeRestore(), isTrue);
        }
      },
    );
    SystemPipHelper.bind(
      session,
      playbackKey: () => 'video/42',
      onPlay: () => events.add('play'),
      onPause: () => events.add('pause'),
      onSkip: (value) => events.add('skip $value'),
      onRestored: () => events.add('rearm'),
    );
    return session;
  }

  Future<int> enter({bool autoEnter = false}) async {
    SystemPipHelper.enter(
      42,
      width: 1920,
      height: 1080,
      autoEnter: autoEnter,
      state: const {'isPlaying': true, 'isLive': false},
    );
    await Future<void>.value();
    return (calls.lastWhere((call) => call.method == 'enter').arguments
            as Map)['sessionId']
        as int;
  }

  setUp(() async {
    calls = [];
    events = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return call.method == 'isAvailable' ? true : null;
    });
    await SystemPipHelper.init();
  });

  tearDown(() async {
    SystemPipHelper.dispose();
    await Future<void>.value();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('only confirmed startup exits the playback page', () async {
    bind();
    final id = await enter();
    await native('onStateChanged', id, {'active': true});
    expect(events, isEmpty);
    await native('onStateChanged', id, {'active': true, 'started': true});
    expect(events, ['retain', 'pop']);
  });

  test(
    'new playback stops the previous PiP and ignores its delayed events',
    () async {
      bind();
      final id = await enter();
      await native('onStateChanged', id, {'active': true, 'started': true});
      SystemPipHelper.closeForNewPlayback();
      expect(events, ['retain', 'pop', 'stop']);
      bind();
      final nextId = await enter();
      expect(nextId, isNot(id));
      await native('onStateChanged', id, {'active': false, 'closed': true});
      await native('setPlaying', id, false);
      expect(SystemPipHelper.isActive, isTrue);
      expect(events, ['retain', 'pop', 'stop']);
    },
  );

  test(
    'closing the system window stops detached playback in foreground',
    () async {
      bind();
      final id = await enter();
      await native('onStateChanged', id, {'active': true, 'started': true});
      await native('onStateChanged', id, {'active': false, 'closed': true});
      expect(events, ['retain', 'pop', 'stop']);
      expect(SystemPipHelper.isDetached, isFalse);
    },
  );

  testWidgets(
    'expanding hands playback to the restored page without stopping',
    (tester) async {
      await tester.pumpWidget(const SizedBox());
      bind();
      final idFuture = enter();
      await tester.pump();
      final id = await idFuture;
      await native('onStateChanged', id, {'active': true, 'started': true});
      final restored = native('restore', id);
      await tester.pump();
      expect(await restored, isTrue);
      expect(events, ['retain', 'pop', 'push', 'handoff']);
      expect(SystemPipHelper.isDetached, isFalse);
    },
  );

  test(
    'system playback actions remain connected after the page closes',
    () async {
      bind();
      final id = await enter(autoEnter: true);
      await native('onStateChanged', id, {'active': true, 'started': true});
      await native('setPlaying', id, false);
      await native('setPlaying', id, true);
      await native('skip', id, 10000);
      expect(events, ['retain', 'pop', 'pause', 'play', 'skip 10000']);
    },
  );

  testWidgets('restore acknowledgment waits beyond the first frame', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    bind(completeOnRestore: false);
    final id = await enter();
    await native('onStateChanged', id, {'active': true, 'started': true});
    var acknowledged = false;
    final restored = native('restore', id).then((value) {
      acknowledged = true;
      return value;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(events, ['retain', 'pop', 'push']);
    expect(acknowledged, isFalse);
    expect(SystemPipHelper.completeRestore(), isTrue);
    expect(await restored, isTrue);
  });
  test('the requested playback page can claim a pending restore', () async {
    final session = bind(completeOnRestore: false);
    final id = await enter();
    await native('onStateChanged', id, {'active': true, 'started': true});
    session.restore();
    SystemPipHelper.closeForNewPlayback(playbackKey: 'video/42');
    expect(session.detached, isTrue);
    expect(SystemPipHelper.completeRestore(), isTrue);
    expect(events.last, 'handoff');
  });

  test(
    'different content cancels a pending restore instead of adopting it',
    () async {
      final session = bind(completeOnRestore: false);
      final id = await enter();
      await native('onStateChanged', id, {'active': true, 'started': true});
      session.restore();
      SystemPipHelper.closeForNewPlayback(playbackKey: 'live/99');
      expect(SystemPipHelper.completeRestore(), isFalse);
      expect(events.last, 'stop');
      expect(session.detached, isFalse);
    },
  );
}
