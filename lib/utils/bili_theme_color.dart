import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_color_utilities/quantize/quantizer_celebi.dart';
import 'package:material_color_utilities/score/score.dart';

/// Extracts a Material-compatible seed color from [file].
///
/// The image is decoded at a small width so applying a theme does not retain a
/// full-size theme image in memory. Transparent pixels are ignored.
Future<int?> extractSeedColorFromImage(
  File file, {
  int resizeWidth = 128,
}) async {
  if (!file.existsSync()) return null;

  final codec = await ui.instantiateImageCodec(
    await file.readAsBytes(),
    targetWidth: resizeWidth,
  );
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return null;
      final rgba = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      final pixels = <int>[];
      for (var i = 0; i + 3 < rgba.length; i += 4) {
        final alpha = rgba[i + 3];
        if (alpha < 16) continue;
        pixels.add(
          0xFF000000 |
              (rgba[i] << 16) |
              (rgba[i + 1] << 8) |
              rgba[i + 2],
        );
      }
      if (pixels.isEmpty) return null;

      final quantized = await QuantizerCelebi().quantize(pixels, 16);
      final ranked = Score.score(quantized.colorToCount, desired: 1);
      return ranked.isEmpty ? null : 0xFF000000 | ranked.first;
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
