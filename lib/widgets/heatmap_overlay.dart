import 'dart:io';

import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// Stacks a translucent heatmap PNG (rendered by [runEla]) over the original
/// image, with a fade-in. Falls back gracefully when no heatmap exists.
class HeatmapOverlay extends StatelessWidget {
  const HeatmapOverlay({
    super.key,
    required this.imagePath,
    required this.heatmapPath,
  });

  final String imagePath;
  final String? heatmapPath;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Image.file(File(imagePath), fit: BoxFit.cover),
          if (heatmapPath != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.85,
                child: Image.file(File(heatmapPath!), fit: BoxFit.cover),
              ),
            ),
        ],
      ),
    );
  }
}
