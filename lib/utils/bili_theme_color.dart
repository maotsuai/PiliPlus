import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_color_utilities/quantize/quantizer_celebi.dart';
import 'package:material_color_utilities/score/score.dart';

/// 从图片提取主色作为 Monet 种子色（返回 ARGB int，失败返回 null）
Future<int?> extractSeedColorFromImage(
  File file, {
  int resizeWidth = 128,
  int maxColors = 16,
}) async {
  final bytes = await file.readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: resizeWidth);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  codec.dispose();
  if (byteData == null) return null;

  final rgba = byteData.buffer.asUint8List();
  final length = rgba.length ~/ 4;
  if (length == 0) return null;
  final pixels = List<int>.generate(length, (i) {
    final offset = i * 4;
    return (rgba[offset + 3] << 24) |
        (rgba[offset] << 16) |
        (rgba[offset + 1] << 8) |
        rgba[offset + 2];
  });

  final quantized = QuantizerCelebi().quantize(pixels, maxColors);
  final ranked = Score.score(quantized, desired: 1);
  if (ranked.isEmpty) return null;
  return 0xFF000000 | ranked.first;
}
