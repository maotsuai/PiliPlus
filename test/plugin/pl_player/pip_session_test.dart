import 'dart:async';

import 'package:PiliPlus/plugin/pl_player/utils/pip_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> events;
  late PipPlaybackSession session;

  setUp(() {
    events = [];
    session = PipPlaybackSession(
      onRetain: () => events.add('retain'),
      onRelease: (stop) => events.add(stop ? 'stop' : 'handoff'),
      onMinimize: () => events.add('pop page'),
      onRestore: () => events.add('push page'),
    );
  });

  test('failed or pending PiP does not pop or retain playback', () {
    session.close();
    expect(events, isEmpty);
    expect(session.detached, isFalse);
  });

  test('confirmed PiP retains playback before exiting the page, once', () {
    session
      ..didStart()
      ..didStart();
    expect(events, ['retain', 'pop page']);
    expect(session.detached, isTrue);
  });

  test('closing PiP releases playback exactly once', () {
    session
      ..didStart()
      ..close()
      ..close();
    expect(events, ['retain', 'pop page', 'stop']);
  });

  test(
    'expanding restores the page before releasing without stopping',
    () async {
      await session.didStart();
      final restored = session.restore();
      final duplicate = session.restore();
      await Future<void>.value();
      expect(session.detached, isTrue);
      expect(session.restoring, isTrue);
      expect(events, ['retain', 'pop page', 'push page']);
      expect(session.completeRestore(), isTrue);
      expect(session.completeRestore(), isFalse);
      expect(await restored, isTrue);
      expect(await duplicate, isTrue);
      session.close();
      expect(events, ['retain', 'pop page', 'push page', 'handoff']);
    },
  );

  test('closing during restoration cancels the handoff', () async {
    await session.didStart();
    final restored = session.restore();
    session.close();
    expect(await restored, isFalse);
    expect(session.completeRestore(), isFalse);
    expect(events.last, 'stop');
    expect(session.detached, isFalse);
  });

  test(
    'playback handoff finishes after the outgoing route is disposed',
    () async {
      final pageGone = Completer<void>();
      session = PipPlaybackSession(
        onRetain: () => events.add('retain'),
        onRelease: (_) => events.add('release'),
        onMinimize: () => pageGone.future,
        onRestore: () {},
        onReady: (_) async => events.add('ready'),
      );
      final starting = session.didStart();
      expect(events, ['retain']);
      pageGone.complete();
      await starting;
      expect(events, ['retain', 'ready']);
    },
  );

  test(
    'closing during route removal cannot resume detached playback later',
    () async {
      final pageGone = Completer<void>();
      session = PipPlaybackSession(
        onRetain: () => events.add('retain'),
        onRelease: (_) => events.add('stop'),
        onMinimize: () => pageGone.future,
        onRestore: () {},
        onReady: (_) async => events.add('unexpected resume'),
      );
      final starting = session.didStart();
      session.close();
      pageGone.complete();
      await starting;
      expect(events, ['retain', 'stop']);
    },
  );

  test(
    'expanding during route removal cancels the late playback handoff',
    () async {
      final pageGone = Completer<void>();
      session = PipPlaybackSession(
        onRetain: () {},
        onRelease: (_) {},
        onMinimize: () => pageGone.future,
        onRestore: () {
          events.add('restore');
          session.completeRestore();
        },
        onReady: (_) async => events.add('unexpected resume'),
      );
      final starting = session.didStart();
      final restored = session.restore();
      expect(events, isEmpty);
      pageGone.complete();
      await starting;
      expect(await restored, isTrue);
      expect(events, ['restore']);
    },
  );

  test('restore waits for the destination page to acquire playback', () async {
    await session.didStart();
    var finished = false;
    final restored = session.restore().then((value) {
      finished = true;
      return value;
    });
    await Future<void>.value();
    expect(events.last, 'push page');
    expect(finished, isFalse);
    session.completeRestore();
    expect(await restored, isTrue);
  });

  test(
    'close before route removal cancels pending restore navigation',
    () async {
      final pageGone = Completer<void>();
      session = PipPlaybackSession(
        onRetain: () {},
        onRelease: (_) => events.add('stop'),
        onMinimize: () => pageGone.future,
        onRestore: () => events.add('unexpected push'),
      );
      final starting = session.didStart();
      final restored = session.restore();
      session.close();
      pageGone.complete();
      await starting;
      expect(await restored, isFalse);
      expect(events, ['stop']);
    },
  );

  test('an async handoff observes cancellation after it starts', () async {
    final paused = Completer<void>();
    session = PipPlaybackSession(
      onRetain: () {},
      onRelease: (_) => events.add('stop'),
      onMinimize: () {},
      onRestore: () {},
      onReady: (isCurrent) async {
        expect(isCurrent(), isTrue);
        await paused.future;
        if (isCurrent()) events.add('unexpected play');
      },
    );
    final starting = session.didStart();
    await Future<void>.value();
    session.close();
    paused.complete();
    await starting;
    expect(events, ['stop']);
  });

  test('restore marks ownership immediately but waits for the host', () async {
    await session.didStart();
    final ready = Completer<void>();
    final restored = session.restore(ready: ready.future);
    await Future<void>.value();
    expect(session.restoring, isTrue);
    expect(events, ['retain', 'pop page']);
    ready.complete();
    await Future<void>.value();
    expect(events.last, 'push page');
    session.completeRestore();
    expect(await restored, isTrue);
  });

  test(
    'closing while the host is paused cancels restoration promptly',
    () async {
      await session.didStart();
      final ready = Completer<void>();
      final restored = session.restore(ready: ready.future);
      session.close();
      expect(await restored, isFalse);
      ready.complete();
      await Future<void>.value();
      expect(events, ['retain', 'pop page', 'stop']);
    },
  );
}
