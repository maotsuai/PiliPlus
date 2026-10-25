import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_color_utilities/quantize/quantizer_celebi.dart';
import 'package:material_color_utilities/score/score.dart';

/// Average the bottom edge, not the foreground/text color in theme metadata.
/// Used for the system gesture area so the navigation artwork is not stretched.
Future<int?> extractBottomEdgeColorFromImage(File file) async {
  final codec = await ui.instantiateImageCodec(
    await file.readAsBytes(),
    targetWidth: 64,
  );
  try {
    final image = (await codec.getNextFrame()).image;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      final rgba = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      var red = 0, green = 0, blue = 0, weight = 0;
      final startRow = (image.height - 3).clamp(0, image.height);
      for (var i = startRow * image.width * 4; i < rgba.length; i += 4) {
        final alpha = rgba[i + 3];
        red += rgba[i] * alpha;
        green += rgba[i + 1] * alpha;
        blue += rgba[i + 2] * alpha;
        weight += alpha;
      }
      if (weight == 0) return null;
      return 0xFF000000 |
          ((red / weight).round() << 16) |
          ((green / weight).round() << 8) |
          (blue / weight).round();
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

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
