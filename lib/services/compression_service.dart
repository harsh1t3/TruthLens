import 'package:image/image.dart' as img;

/// 8-pixel block-boundary discontinuity score.
///
/// JPEG compresses in 8x8 DCT blocks. A heavily-compressed or re-saved image
/// shows stronger luminance gradients across block boundaries (x % 8 == 0)
/// than within blocks (x % 8 == 4). The ratio of edge-gradient to
/// interior-gradient is a proxy for compression aggressiveness.
///
/// We don't claim true double-compression detection (which requires DCT
/// coefficient analysis — the `image` package doesn't expose them). This is
/// an honest, implementable heuristic.
///
/// Returns: { compressionScore }
Map<String, dynamic> runCompression(img.Image decoded) {
  final width = decoded.width;
  final height = decoded.height;
  if (width < 16 || height < 16) {
    return {'compressionScore': 0.0};
  }

  double edgeGradSum = 0;
  int edgeGradCount = 0;
  double interiorGradSum = 0;
  int interiorGradCount = 0;

  double luminance(img.Pixel p) => 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;

  // Horizontal gradients.
  for (int y = 0; y < height; y += 2) {
    for (int x = 1; x < width; x += 2) {
      final l1 = luminance(decoded.getPixel(x - 1, y));
      final l2 = luminance(decoded.getPixel(x, y));
      final grad = (l1 - l2).abs();
      if (x % 8 == 0) {
        edgeGradSum += grad;
        edgeGradCount++;
      } else if (x % 8 == 4) {
        interiorGradSum += grad;
        interiorGradCount++;
      }
    }
  }

  // Vertical gradients.
  for (int y = 1; y < height; y += 2) {
    for (int x = 0; x < width; x += 2) {
      final l1 = luminance(decoded.getPixel(x, y - 1));
      final l2 = luminance(decoded.getPixel(x, y));
      final grad = (l1 - l2).abs();
      if (y % 8 == 0) {
        edgeGradSum += grad;
        edgeGradCount++;
      } else if (y % 8 == 4) {
        interiorGradSum += grad;
        interiorGradCount++;
      }
    }
  }

  if (edgeGradCount == 0 || interiorGradCount == 0) {
    return {'compressionScore': 0.0};
  }

  final edgeMean = edgeGradSum / edgeGradCount;
  final interiorMean = interiorGradSum / interiorGradCount;
  if (interiorMean < 0.5) {
    return {'compressionScore': 0.0};
  }
  final ratio = edgeMean / interiorMean;
  // ratio of 1.0 means no block artifact; 1.5+ means strong artifact.
  // Map [1.0 .. 2.0] linearly to [0.0 .. 1.0].
  final score = ((ratio - 1.0)).clamp(0.0, 1.0);

  return {'compressionScore': score};
}
