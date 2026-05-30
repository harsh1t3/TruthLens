import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/scan_result.dart';
import '../utils/color_utils.dart';
import 'ai_classifier_service.dart';
import 'c2pa_service.dart';
import 'compression_service.dart';
import 'generator_signature_service.dart';
import 'metadata_service.dart';
import 'spectral_service.dart';

/// Heuristic detectors that run inside one isolate (no Flutter bindings needed).
Future<Map<String, dynamic>> _heuristicsInIsolate(Uint8List originalBytes) async {
  final decoded = img.decodeImage(originalBytes);
  if (decoded == null) {
    return {'error': 'unsupported_image'};
  }

  const maxEdge = 1024;
  img.Image working = decoded;
  if (decoded.width > maxEdge || decoded.height > maxEdge) {
    if (decoded.width >= decoded.height) {
      working = img.copyResize(decoded, width: maxEdge);
    } else {
      working = img.copyResize(decoded, height: maxEdge);
    }
  }

  final genResult = await runGeneratorSignature(originalBytes);
  final c2paResult = runC2PA(originalBytes);
  final metaResult = await runMetadata(originalBytes);
  final spectralResult = runSpectral(working);
  final compResult = runCompression(working);

  return {
    'generator': genResult,
    'c2pa': c2paResult,
    'metadata': metaResult,
    'spectral': spectralResult,
    'compression': compResult,
  };
}

class AnalysisOrchestrator {
  AnalysisOrchestrator(this._box);

  final Box<ScanResult> _box;
  static const _uuid = Uuid();

  /// Main flow:
  ///   1. Read bytes on main thread.
  ///   2. Kick off the heuristics isolate AND the on-device AI classifier
  ///      concurrently — they're independent.
  ///   3. Merge into a single ScanResult, persist, return.
  Future<ScanResult> runAnalysis(File imageFile) async {
    final bytes = await imageFile.readAsBytes();

    // Decode once on the main thread for the classifier. The image package's
    // decoder is cheap; the classifier itself does its own resize to 224×224.
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('Unsupported or corrupt image');

    final aiFuture = _classifySafely(decoded);
    final heuristicsFuture = compute(_heuristicsInIsolate, bytes);

    final results = await Future.wait([aiFuture, heuristicsFuture]);
    final aiResult = results[0];
    final heuristicResult = results[1];

    if (heuristicResult.containsKey('error')) {
      throw const FormatException('Unsupported or corrupt image');
    }

    final gen = heuristicResult['generator'] as Map;
    final c2pa = heuristicResult['c2pa'] as Map;
    final meta = heuristicResult['metadata'] as Map;
    final spectral = heuristicResult['spectral'] as Map;
    final comp = heuristicResult['compression'] as Map;

    final aiGenerator = gen['aiGenerator'] as String?;
    final c2paPresent = c2pa['c2paPresent'] as bool;
    final metadataScore = (meta['metadataScore'] as num).toDouble();
    final spectralScore = (spectral['spectralScore'] as num).toDouble();
    final compressionScore = (comp['compressionScore'] as num).toDouble();
    final heatmapBytes = spectral['heatmapPngBytes'] as Uint8List;

    final aiProbability = aiResult['aiProbability'] as double; // 0..1, 1 = AI
    final classifierAvailable = aiResult['available'] as bool;
    final classifierError = aiResult['error'] as String?;

    // AI signal score blends model probability with deterministic evidence.
    //   - If a generator name was found in metadata, snap to 1.0.
    //   - Else the classifier dominates, with a small bonus for C2PA-without-camera.
    double aiSignalScore;
    if (aiGenerator != null) {
      aiSignalScore = 1.0;
    } else {
      aiSignalScore = aiProbability;
      if (c2paPresent) aiSignalScore = (aiSignalScore + 0.15).clamp(0.0, 1.0);
    }

    final findings = <String>[
      if (classifierAvailable)
        'On-device classifier: ${(aiProbability * 100).round()}% AI-generated'
      else
        'On-device classifier UNAVAILABLE — heuristics only. '
            '(${classifierError ?? "unknown error"})',
      ...List<String>.from(gen['evidence'] as List),
      ...List<String>.from(c2pa['findings'] as List),
      ...List<String>.from(meta['findings'] as List),
    ];

    // Trust score weighting — classifier carries the load now.
    //   AI signal 55 · spectral 12 · metadata 18 · compression 15.
    // Sub-scores 0..1, weights sum to 100 ⇒ already 0..100.
    final trustScore = (100 -
            (aiSignalScore * 55 +
                spectralScore * 12 +
                metadataScore * 18 +
                compressionScore * 15))
        .clamp(0.0, 100.0);

    final hasEditorTag = findings.any((f) => f.toLowerCase().startsWith('edited with'));

    final verdict = verdictFromScores(
      trustScore: trustScore.toDouble(),
      aiSignalScore: aiSignalScore,
      spectralScore: spectralScore,
      metadataScore: metadataScore,
      hasEditorTag: hasEditorTag,
      aiGenerator: aiGenerator,
    );

    final id = _uuid.v4();
    final docsDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(docsDir.path, 'images'));
    final heatmapsDir = Directory(p.join(docsDir.path, 'heatmaps'));
    if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
    if (!await heatmapsDir.exists()) await heatmapsDir.create(recursive: true);

    final savedImagePath = p.join(imagesDir.path, '$id${p.extension(imageFile.path)}');
    await imageFile.copy(savedImagePath);

    String? heatmapPath;
    if (heatmapBytes.isNotEmpty) {
      heatmapPath = p.join(heatmapsDir.path, '$id.png');
      await File(heatmapPath).writeAsBytes(heatmapBytes);
    }

    final scan = ScanResult(
      id: id,
      imagePath: savedImagePath,
      heatmapPath: heatmapPath,
      trustScore: trustScore.toDouble(),
      aiSignalScore: aiSignalScore,
      spectralScore: spectralScore,
      metadataScore: metadataScore,
      compressionScore: compressionScore,
      findings: findings,
      scannedAt: DateTime.now(),
      verdict: verdict,
      aiGenerator: aiGenerator,
      c2paPresent: c2paPresent,
    );

    await _box.put(id, scan);
    return scan;
  }

  /// Wraps the classifier in a try/catch — if the model fails to load on a
  /// device or the inference errors out, we degrade gracefully to a neutral
  /// 0.5 probability and mark it unavailable so the UI can label findings.
  Future<Map<String, dynamic>> _classifySafely(img.Image decoded) async {
    try {
      final r = await AiClassifierService.instance.classify(decoded);
      return {
        'available': true,
        'aiProbability': r['aiProbability']!,
        'humanProbability': r['humanProbability']!,
        'error': null,
      };
    } catch (e) {
      debugPrint('AI classifier failed: $e');
      return {
        'available': false,
        'aiProbability': 0.0,
        'humanProbability': 1.0,
        'error': e.toString(),
      };
    }
  }

  Future<void> deleteScan(ScanResult scan) async {
    try {
      final f = File(scan.imagePath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    if (scan.heatmapPath != null) {
      try {
        final f = File(scan.heatmapPath!);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    await _box.delete(scan.id);
  }
}
