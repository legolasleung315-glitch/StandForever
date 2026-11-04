import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// 在 isolate 內完成「讀檔 → 解碼 → 處理 → 編碼 → 寫檔」，並回傳各階段耗時。
Future<Map<String, dynamic>> processImageToTempFile(
  Map<String, dynamic> message,
) async {
  final totalWatch = Stopwatch()..start();
  final timings = <String, int>{};
  final inputPath = message['inputPath'] as String;
  final outputPath = message['outputPath'] as String;
  final config = Map<String, dynamic>.from(message['config'] as Map);

  var watch = Stopwatch()..start();
  final inputBytes = await File(inputPath).readAsBytes();
  timings['read'] = watch.elapsedMicroseconds;

  final processed = await _processImageInIsolate(inputBytes, config);
  timings.addAll(processed['timings'] as Map<String, int>);

  watch = Stopwatch()..start();
  // Private intermediate file; SAF performs the durable final write.
  await File(outputPath).writeAsBytes(processed['bytes'] as Uint8List);
  timings['tempWrite'] = watch.elapsedMicroseconds;
  timings['workerTotal'] = totalWatch.elapsedMicroseconds;

  return <String, dynamic>{
    'outputPath': outputPath,
    'timings': timings,
  };
}

Future<Map<String, dynamic>> _processImageInIsolate(
  Uint8List inputBytes,
  Map<String, dynamic> config,
) async {
  final timings = <String, int>{};
  var watch = Stopwatch()..start();
  final decoded = img.decodeImage(inputBytes);
  if (decoded == null) throw Exception('無法解碼圖片');
  timings['decode'] = watch.elapsedMicroseconds;

  img.Image image = decoded;
  image.exif.clear();
  image.textData = null;

  watch = Stopwatch()..start();
  final requestedWidth = config['maxWidth'] as int;
  if (requestedWidth > 0) {
    final maxWidth = requestedWidth.clamp(480, 4000).toInt();
    if (image.width > maxWidth) {
      image = img.copyResize(
        image,
        width: maxWidth,
        interpolation: img.Interpolation.linear,
      );
    }
  }
  timings['resize'] = watch.elapsedMicroseconds;

  watch = Stopwatch()..start();
  final filterMode = config['filterMode'] as int;
  if (filterMode == 1) {
    image = img.adjustColor(
      image,
      contrast: 0.86,
      saturation: 0.4624,
      gamma: 1.03,
    );
    image = img.gaussianBlur(image, radius: 1);
  } else if (filterMode == 2) {
    image = img.adjustColor(
      image,
      contrast: 0.94,
      saturation: 0.6724,
      gamma: 1.01,
    );
    image = img.gaussianBlur(image, radius: 1);
  }
  timings['color'] = watch.elapsedMicroseconds;

  watch = Stopwatch()..start();
  final grainAmount = (config['grainAmount'] as int?) ??
      ((config['addGrain'] as bool) ? 25 : 0);
  final noiseAmount = (config['noiseAmount'] as int?) ?? 0;
  if (grainAmount > 0 || noiseAmount > 0) {
    _applyGrainAndNoise(
      image,
      grainAmount: grainAmount,
      noiseAmount: noiseAmount,
    );
  }
  timings['grainNoise'] = watch.elapsedMicroseconds;

  watch = Stopwatch()..start();
  final watermarkText = config['watermarkText'] as String;
  if ((config['applyWatermark'] as bool) && watermarkText.isNotEmpty) {
    _drawWatermark(
      image,
      text: watermarkText,
      fontSize: (config['fontSize'] as num).toDouble(),
      r: config['colorR'] as int,
      g: config['colorG'] as int,
      b: config['colorB'] as int,
      opacity: (config['opacity'] as num).toDouble(),
      margin: (config['margin'] as num).toDouble(),
      fontFnt: utf8
          .decode(config['fontFntBytes'] as Uint8List)
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('page '))
          .join('\n'),
      fontPngBytes: config['fontPngBytes'] as Uint8List,
    );
  }
  timings['watermark'] = watch.elapsedMicroseconds;

  watch = Stopwatch()..start();
  final quality = (config['jpegQuality'] as int).clamp(60, 98).toInt();
  final encoded = img.encodeJpg(image, quality: quality);
  timings['jpegEncode'] = watch.elapsedMicroseconds;

  return <String, dynamic>{
    'bytes': encoded,
    'timings': timings,
  };
}

void _applyGrainAndNoise(
  img.Image image, {
  required int grainAmount,
  required int noiseAmount,
}) {
  if (grainAmount <= 0 && noiseAmount <= 0) return;

  final grainRandom = math.Random(20260823);
  final noiseRandom = math.Random(20260824);
  final grainEnabled = grainAmount > 0;
  final noiseEnabled = noiseAmount > 0;
  final grainStrength = math.max(1, (grainAmount * 0.18).round());
  final grainCoverage = (0.55 + grainAmount * 0.004).clamp(0.55, 0.95);
  final noiseStrength = math.max(1, (noiseAmount * 0.30).round());

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      var delta = 0;
      if (grainEnabled && grainRandom.nextDouble() <= grainCoverage) {
        delta += grainRandom.nextInt(grainStrength * 2 + 1) - grainStrength;
      }
      if (noiseEnabled) {
        delta += noiseRandom.nextInt(noiseStrength * 2 + 1) - noiseStrength;
      }
      if (delta == 0) continue;
      
      final pixel = image.getPixel(x, y);
      pixel.r = (pixel.r + delta).clamp(0, 255);
      pixel.g = (pixel.g + delta).clamp(0, 255);
      pixel.b = (pixel.b + delta).clamp(0, 255);
    }
  }
}

void _drawWatermark(
  img.Image image, {
  required String text,
  required double fontSize,
  required int r,
  required int g,
  required int b,
  required double opacity,
  required double margin,
  required String fontFnt,
  required Uint8List fontPngBytes,
}) {
  if (text.isEmpty || image.width < 20 || image.height < 20) return;

  final page = img.decodePng(fontPngBytes);
  if (page == null) return;

  final font = img.readFont(fontFnt, page);

  int textWidth = 0;
  int textHeight = font.lineHeight;

  for (final codeUnit in text.codeUnits) {
    final char = font.characters[codeUnit];
    if (char == null) {
      textWidth += font.base ~/ 2;
      continue;
    }
    textWidth += char.xAdvance;
    textHeight = math.max(textHeight, char.height + char.yOffset);
  }

  if (textWidth <= 0 || textHeight <= 0) return;

  final rawWidth = textWidth + 20;
  final rawHeight = textHeight + 20;

  var overlay = img.Image(width: rawWidth, height: rawHeight, numChannels: 4);
  overlay.clear(img.ColorRgba8(0, 0, 0, 0));

  final alpha = (opacity.clamp(0.0, 1.0) * 255).round();
  final color = img.ColorRgba8(
    r.clamp(0, 255).toInt(),
    g.clamp(0, 255).toInt(),
    b.clamp(0, 255).toInt(),
    alpha,
  );

  img.drawString(overlay, text, font: font, x: 8, y: 8, color: color);

  int minX = overlay.width, minY = overlay.height, maxX = -1, maxY = -1;
  for (var yy = 0; yy < overlay.height; yy++) {
    for (var xx = 0; xx < overlay.width; xx++) {
      if (overlay.getPixel(xx, yy).a > 8) {
        if (xx < minX) minX = xx;
        if (yy < minY) minY = yy;
        if (xx > maxX) maxX = xx;
        if (yy > maxY) maxY = yy;
      }
    }
  }
  if (maxX < minX || maxY < minY) return;

  const cropPad = 1;
  final cropX = math.max(0, minX - cropPad);
  final cropY = math.max(0, minY - cropPad);
  final cropRight = math.min(overlay.width - 1, maxX + cropPad);
  final cropBottom = math.min(overlay.height - 1, maxY + cropPad);

  overlay = img.copyCrop(
    overlay,
    x: cropX,
    y: cropY,
    width: cropRight - cropX + 1,
    height: cropBottom - cropY + 1,
  );

  final scale = image.width / 2000.0;
  final targetHeight = (fontSize * scale).round().clamp(7, 160).toInt();
  final targetWidth = math.max(1, (overlay.width * targetHeight / overlay.height).round());

  final bool small = targetHeight <= 40;
  final int supersample = small ? 8 : 4;
  final workWidth = math.max(1, targetWidth * supersample);
  final workHeight = math.max(1, targetHeight * supersample);

  final dense = img.copyResize(
    overlay,
    width: workWidth,
    height: workHeight,
    interpolation: img.Interpolation.cubic,
  );

  final scaled = img.Image(width: targetWidth, height: targetHeight, numChannels: 4);
  scaled.clear(img.ColorRgba8(0, 0, 0, 0));

  final sr = r.clamp(0, 255).toInt();
  final sg = g.clamp(0, 255).toInt();
  final sb = b.clamp(0, 255).toInt();

  for (var yy = 0; yy < targetHeight; yy++) {
    final sy0 = (yy * workHeight / targetHeight).floor();
    final sy1 = math.min(workHeight, math.max(sy0 + 1, ((yy + 1) * workHeight / targetHeight).ceil()));

    for (var xx = 0; xx < targetWidth; xx++) {
      final sx0 = (xx * workWidth / targetWidth).floor();
      final sx1 = math.min(workWidth, math.max(sx0 + 1, ((xx + 1) * workWidth / targetWidth).ceil()));

      var alphaSum = 0, count = 0;
      for (var sy = sy0; sy < sy1; sy++) {
        for (var sx = sx0; sx < sx1; sx++) {
          alphaSum += dense.getPixel(sx, sy).a.toInt();
          count++;
        }
      }
      if (count == 0) continue;
      final aa = (alphaSum / count).round().clamp(0, 255).toInt();
      if (aa == 0) continue;
      scaled.setPixelRgba(xx, yy, sr, sg, sb, aa);
    }
  }

  final x = math.max(0, image.width - scaled.width - margin.round());
  final y = math.max(0, image.height - scaled.height - margin.round());

  img.compositeImage(image, scaled, dstX: x, dstY: y, blend: img.BlendMode.alpha);
}
