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

  test('expanding restores the page before releasing without stopping', () {
    session
      ..didStart()
      ..restore()
      ..restore();
    expect(session.detached, isTrue);
    expect(session.restoring, isTrue);
    expect(events, ['retain', 'pop page', 'push page']);
    expect(session.completeRestore(), isTrue);
    expect(session.completeRestore(), isFalse);
    session.close();
    expect(events, ['retain', 'pop page', 'push page', 'handoff']);
  });

  test('closing during restoration cancels the handoff', () {
    session
      ..didStart()
      ..restore()
      ..close();
    expect(session.completeRestore(), isFalse);
    expect(events.last, 'stop');
    expect(session.detached, isFalse);
  });
}
