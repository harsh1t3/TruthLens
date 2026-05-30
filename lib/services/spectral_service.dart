import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Frequency-domain anomaly detector.
///
/// AI-generated images (diffusion + VAE-decoded) tend to have:
///   - suppressed high-frequency energy (over-smooth micro-textures)
///   - subtle periodic patterns from the VAE decoder grid
///
/// Computing a true 2D FFT in pure Dart on a 1024px image is slow. We use a
/// well-correlated spatial proxy: subtract a Gaussian blur from the image to
/// isolate high-frequency residual, then measure per-patch residual variance.
/// Low high-frequency variance vs. local contrast is the AI signature.
///
/// Returns: `{ spectralScore: 0..1, suspiciousPatches, heatmapPngBytes }`.
Map<String, dynamic> runSpectral(img.Image decoded) {
  final width = decoded.width;
  final height = decoded.height;
  if (width < 32 || height < 32) {
    return {
      'spectralScore': 0.0,
      'suspiciousPatches': <Map<String, int>>[],
      'heatmapPngBytes': Uint8List(0),
    };
  }

  // 1. Build a luminance plane.
  final lum = Float32List(width * height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final p = decoded.getPixel(x, y);
      lum[y * width + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
    }
  }

  // 2. Two-pass separable box blur (3-iteration approx of Gaussian, radius 3).
  final blurred = _boxBlur3(lum, width, height, radius: 3, passes: 3);

  // 3. High-frequency residual = lum - blurred. Per-patch variance of residual
  //    AND per-patch variance of original luminance (a contrast estimate).
  const grid = 12;
  final cellW = width ~/ grid;
  final cellH = height ~/ grid;
  final hfVar = List<double>.filled(grid * grid, 0);
  final lumVar = List<double>.filled(grid * grid, 0);

  for (int gy = 0; gy < grid; gy++) {
    for (int gx = 0; gx < grid; gx++) {
      final x0 = gx * cellW;
      final y0 = gy * cellH;
      final x1 = (gx == grid - 1) ? width : x0 + cellW;
      final y1 = (gy == grid - 1) ? height : y0 + cellH;
      double rs = 0, rss = 0, ls = 0, lss = 0;
      int n = 0;
      for (int y = y0; y < y1; y += 2) {
        for (int x = x0; x < x1; x += 2) {
          final idx = y * width + x;
          final r = lum[idx] - blurred[idx];
          rs += r;
          rss += r * r;
          ls += lum[idx];
          lss += lum[idx] * lum[idx];
          n++;
        }
      }
      if (n == 0) continue;
      final rm = rs / n;
      final lm = ls / n;
      hfVar[gy * grid + gx] = math.max(rss / n - rm * rm, 0);
      lumVar[gy * grid + gx] = math.max(lss / n - lm * lm, 0);
    }
  }

  // 4. Per-patch "smoothness ratio" = high-freq variance / (luminance variance + epsilon).
  //    Photos have varied texture → relatively high ratio. AI smooth zones → low ratio.
  //    Flag a patch as suspicious when it has decent local contrast AND low HF residual.
  final ratio = List<double>.filled(grid * grid, 0);
  for (int i = 0; i < ratio.length; i++) {
    ratio[i] = hfVar[i] / (lumVar[i] + 1.0);
  }

  // 5. Aggregate score: fraction of "contentful but smooth" patches.
  int suspicious = 0;
  int contentful = 0;
  final suspiciousPatches = <Map<String, int>>[];
  for (int i = 0; i < ratio.length; i++) {
    if (lumVar[i] < 25) continue; // skip near-flat patches (sky, white walls)
    contentful++;
    if (ratio[i] < 0.025) {
      suspicious++;
      final gx = i % grid;
      final gy = i ~/ grid;
      suspiciousPatches.add({
        'x': gx * cellW,
        'y': gy * cellH,
        'w': cellW,
        'h': cellH,
      });
    }
  }
  final spectralScore = contentful == 0 ? 0.0 : (suspicious / contentful).clamp(0.0, 1.0);

  // 6. Heatmap PNG.
  final heatmap = img.Image.from(decoded);
  for (final r in suspiciousPatches) {
    img.fillRect(
      heatmap,
      x1: r['x']!,
      y1: r['y']!,
      x2: r['x']! + r['w']! - 1,
      y2: r['y']! + r['h']! - 1,
      color: img.ColorRgba8(80, 90, 255, 90),
    );
    img.drawRect(
      heatmap,
      x1: r['x']!,
      y1: r['y']!,
      x2: r['x']! + r['w']! - 1,
      y2: r['y']! + r['h']! - 1,
      color: img.ColorRgba8(80, 90, 255, 220),
      thickness: 2,
    );
  }
  final heatmapPng = Uint8List.fromList(img.encodePng(heatmap));

  return {
    'spectralScore': spectralScore,
    'suspiciousPatches': suspiciousPatches,
    'heatmapPngBytes': heatmapPng,
  };
}

/// Three-iteration separable box blur (close approximation of a Gaussian).
Float32List _boxBlur3(Float32List src, int w, int h, {int radius = 3, int passes = 3}) {
  Float32List a = Float32List.fromList(src);
  Float32List b = Float32List(src.length);
  for (int pass = 0; pass < passes; pass++) {
    _boxBlurH(a, b, w, h, radius);
    _boxBlurV(b, a, w, h, radius);
  }
  return a;
}

void _boxBlurH(Float32List src, Float32List dst, int w, int h, int r) {
  final norm = 1.0 / (2 * r + 1);
  for (int y = 0; y < h; y++) {
    double acc = 0;
    final row = y * w;
    for (int i = -r; i <= r; i++) {
      acc += src[row + i.clamp(0, w - 1)];
    }
    for (int x = 0; x < w; x++) {
      dst[row + x] = acc * norm;
      final leave = (x - r).clamp(0, w - 1);
      final enter = (x + r + 1).clamp(0, w - 1);
      acc += src[row + enter] - src[row + leave];
    }
  }
}

void _boxBlurV(Float32List src, Float32List dst, int w, int h, int r) {
  final norm = 1.0 / (2 * r + 1);
  for (int x = 0; x < w; x++) {
    double acc = 0;
    for (int i = -r; i <= r; i++) {
      acc += src[i.clamp(0, h - 1) * w + x];
    }
    for (int y = 0; y < h; y++) {
      dst[y * w + x] = acc * norm;
      final leave = (y - r).clamp(0, h - 1);
      final enter = (y + r + 1).clamp(0, h - 1);
      acc += src[enter * w + x] - src[leave * w + x];
    }
  }
}
