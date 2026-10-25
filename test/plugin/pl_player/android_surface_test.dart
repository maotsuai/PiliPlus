import 'package:PiliPlus/plugin/pl_player/utils/android_surface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<(String, String)> writes;
  late AndroidSurfaceCoordinator output;

  setUp(() {
    writes = [];
    output = AndroidSurfaceCoordinator(
      setProperty: (name, value) => writes.add((name, value)),
    );
  });

  test('unknown inline dimensions do not start a one-pixel output', () {
    output.setInlineSurface(11, 0, 0);
    expect(writes, isEmpty);
    output.updateInlineSize(1920, 1080);
    expect(writes, [
      ('vo', 'null'),
      ('android-surface-size', '1920x1080'),
      ('wid', '11'),
      ('vo', 'gpu'),
    ]);
  });

  test('inline parameter updates cannot steal the PiP Surface', () {
    output
      ..setInlineSurface(11, 1920, 1080)
      ..attachExternalSurface(22, 480, 270);
    writes.clear();
    for (var i = 0; i < 100; i++) {
      output.updateInlineSize(i.isEven ? 1920 : 1280, i.isEven ? 1080 : 720);
    }
    expect(writes, isEmpty);
  });

  test('PiP resize changes dimensions without restarting video output', () {
    output
      ..setInlineSurface(11, 1920, 1080)
      ..attachExternalSurface(22, 480, 270);
    writes.clear();
    output.attachExternalSurface(22, 640, 360);
    expect(writes, [('android-surface-size', '640x360')]);
  });

  test('repeated Surface notifications do not recreate the renderer', () {
    output.attachExternalSurface(22, 480, 270);
    writes.clear();
    for (var i = 0; i < 100; i++) {
      output.attachExternalSurface(22, 480, 270);
    }
    expect(writes, isEmpty);
  });

  test(
    'a reconnect keeps PiP selected and restores the latest inline Surface',
    () {
      output
        ..setInlineSurface(11, 1920, 1080)
        ..attachExternalSurface(22, 480, 270)
        ..suspend();
      writes.clear();
      output.setInlineSurface(33, 1280, 720);
      expect(writes.where((entry) => entry.$1 == 'wid'), [('wid', '22')]);
      writes.clear();
      output.detachExternalSurface();
      expect(writes, [
        ('vo', 'null'),
        ('android-surface-size', '1280x720'),
        ('wid', '33'),
        ('vo', 'gpu'),
      ]);
      writes.clear();
      output.detachExternalSurface();
      expect(writes, isEmpty);
    },
  );

  test('closing PiP during reload waits for a valid inline Surface', () {
    output
      ..setInlineSurface(11, 1920, 1080)
      ..attachExternalSurface(22, 480, 270)
      ..suspend();
    writes.clear();
    output.detachExternalSurface();
    expect(writes, isEmpty);
    output.setInlineSurface(33, 1920, 1080);
    expect(writes.where((entry) => entry.$1 == 'wid'), [('wid', '33')]);
  });

  test('invalid native Surface sizes leave the existing output intact', () {
    output.setInlineSurface(11, 1920, 1080);
    writes.clear();
    expect(output.attachExternalSurface(0, 480, 270), isFalse);
    expect(output.attachExternalSurface(22, 0, 270), isFalse);
    expect(writes, isEmpty);
  });
}
