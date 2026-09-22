import 'dart:async';

import 'package:PiliPlus/plugin/pl_player/utils/playback_watchdog.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retries a silent stall after playback has already progressed', () {
    fakeAsync((clock) {
      var retries = 0;
      final watchdog = PlaybackWatchdog(onStalled: (_) async => retries++);
      watchdog.start(const Duration(minutes: 3));
      clock.elapse(const Duration(seconds: 7));
      expect(retries, 0);
      clock.elapse(const Duration(seconds: 1));
      expect(retries, 1);
      watchdog.stop();
    });
  });

  test('continued playback postpones recovery', () {
    fakeAsync((clock) {
      var retries = 0;
      final watchdog = PlaybackWatchdog(onStalled: (_) async => retries++);
      watchdog.start(Duration.zero);
      for (var second = 1; second <= 60; second++) {
        clock.elapse(const Duration(seconds: 1));
        watchdog.onPosition(Duration(seconds: second));
      }
      expect(retries, 0);
      watchdog.stop();
    });
  });

  test('backs off and stops after three unsuccessful attempts', () {
    fakeAsync((clock) {
      final attempts = <Duration>[];
      final watchdog = PlaybackWatchdog(
        onStalled: (_) async => attempts.add(clock.elapsed),
      );
      watchdog.start(Duration.zero);
      clock.elapse(const Duration(minutes: 10));
      expect(attempts, const [
        Duration(seconds: 8),
        Duration(seconds: 24),
        Duration(seconds: 56),
      ]);
      expect(clock.nonPeriodicTimerCount, 0);
      watchdog.stop();
    });
  });

  test('pause or disposal invalidates an in-flight recovery', () {
    fakeAsync((clock) {
      final opened = Completer<void>();
      var resumed = false;
      final watchdog = PlaybackWatchdog(
        onStalled: (isCurrent) async {
          await opened.future;
          if (isCurrent()) resumed = true;
        },
      );
      watchdog.start(Duration.zero);
      clock.elapse(const Duration(seconds: 8));
      watchdog.stop();
      opened.complete();
      clock.flushMicrotasks();
      clock.elapse(const Duration(minutes: 1));
      expect(resumed, isFalse);
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });

  test('pausing during buffering cancels scheduled recovery', () {
    fakeAsync((clock) {
      var retries = 0;
      final watchdog = PlaybackWatchdog(onStalled: (_) async => retries++);
      watchdog.start(Duration.zero);
      clock.elapse(const Duration(seconds: 7));
      watchdog.stop();
      watchdog.onPosition(const Duration(seconds: 1));
      clock.elapse(const Duration(minutes: 5));
      expect(retries, 0);
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });

  test('source changes cannot overlap a pending recovery or resume it', () {
    fakeAsync((clock) {
      final opened = Completer<void>();
      var calls = 0;
      var staleResume = false;
      final watchdog = PlaybackWatchdog(
        onStalled: (isCurrent) async {
          calls++;
          if (calls == 1) {
            await opened.future;
            staleResume = isCurrent();
          }
        },
      );
      watchdog.start(Duration.zero);
      clock.elapse(const Duration(seconds: 8));
      watchdog.start(const Duration(minutes: 1));
      clock.elapse(const Duration(seconds: 24));
      expect(calls, 1);
      opened.complete();
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 8));
      expect(staleResume, isFalse);
      expect(calls, 2);
      watchdog.stop();
    });
  });

  test('open and seek positions do not create an unlimited retry loop', () {
    fakeAsync((clock) {
      var retries = 0;
      late PlaybackWatchdog watchdog;
      watchdog = PlaybackWatchdog(
        onStalled: (_) async {
          retries++;
          watchdog.onPosition(Duration.zero);
          watchdog.onPosition(const Duration(minutes: 3));
        },
      );
      watchdog.start(const Duration(minutes: 3));
      clock.elapse(const Duration(minutes: 5));
      expect(retries, 3);
      watchdog.stop();
    });
  });

  test('sustained progress replenishes the retry budget', () {
    fakeAsync((clock) {
      var retries = 0;
      final watchdog = PlaybackWatchdog(onStalled: (_) async => retries++);
      watchdog.start(Duration.zero);
      clock.elapse(const Duration(seconds: 8));
      for (var second = 1; second <= 5; second++) {
        clock.elapse(const Duration(seconds: 1));
        watchdog.onPosition(Duration(seconds: second));
      }
      clock.elapse(const Duration(seconds: 8));
      expect(retries, 2);
      watchdog.stop();
    });
  });

  test('failed open is bounded and reported without an unhandled error', () {
    fakeAsync((clock) {
      var errors = 0;
      final watchdog = PlaybackWatchdog(
        onStalled: (_) async => throw StateError('offline'),
        onError: (_, _) => errors++,
      );
      watchdog.start(Duration.zero);
      clock.elapse(const Duration(minutes: 5));
      expect(errors, 3);
      expect(clock.nonPeriodicTimerCount, 0);
      watchdog.stop();
    });
  });
}
