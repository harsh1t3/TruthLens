import 'package:flutter/material.dart';

/// v2 verdict taxonomy:
///   - "ai_generated"  — generator signature found OR strong spectral match
///   - "edited"        — editor signature OR strong compression/edit signals
///   - "authentic"     — clean across all detectors
///   - "unknown"       — middle ground (some signals but not conclusive)
String verdictFromScores({
  required double trustScore,
  required double aiSignalScore,
  required double spectralScore,
  required double metadataScore,
  required bool hasEditorTag,
  required String? aiGenerator,
}) {
  if (aiGenerator != null || aiSignalScore >= 0.6 || spectralScore >= 0.55) {
    return 'ai_generated';
  }
  if (hasEditorTag || metadataScore >= 0.5) {
    return 'edited';
  }
  if (trustScore >= 75) return 'authentic';
  if (trustScore >= 50) return 'unknown';
  return 'edited';
}

String verdictLabel(String verdict) {
  switch (verdict) {
    case 'authentic':
      return 'Likely Authentic';
    case 'ai_generated':
      return 'Likely AI-Generated';
    case 'edited':
      return 'Likely Edited';
    default:
      return 'Inconclusive';
  }
}

Color colorForScore(double score) {
  if (score >= 75) return const Color(0xFF22A557);
  if (score >= 50) return const Color(0xFFCC8410);
  return const Color(0xFFD33F2F);
}

Color colorForVerdict(String verdict) {
  switch (verdict) {
    case 'authentic':
      return const Color(0xFF22A557);
    case 'ai_generated':
      return const Color(0xFF6D5BFF);
    case 'edited':
      return const Color(0xFFCC8410);
    default:
      return const Color(0xFF6B6B73);
  }
}
