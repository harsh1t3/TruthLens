import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/scan_result.dart';
import '../utils/color_utils.dart';
import 'c2pa_service.dart';
import 'compression_service.dart';
import 'generator_signature_service.dart';
import 'metadata_service.dart';
import 'spectral_service.dart';

/// Top-level entry point invoked via `compute()`.
///
/// Decodes once (downscaled to a 1024px long edge), then runs all detectors
/// sequentially inside one isolate. Compressed bytes in, primitives + one
/// heatmap PNG out — never raw RGBA buffers across the boundary.
Future<Map<String, dynamic>> _analyzeInIsolate(Uint8List originalBytes) async {
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

  Future<ScanResult> runAnalysis(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final result = await compute(_analyzeInIsolate, bytes);

    if (result.containsKey('error')) {
      throw const FormatException('Unsupported or corrupt image');
    }

    final gen = result['generator'] as Map;
    final c2pa = result['c2pa'] as Map;
    final meta = result['metadata'] as Map;
    final spectral = result['spectral'] as Map;
    final comp = result['compression'] as Map;

    final aiGenerator = gen['aiGenerator'] as String?;
    final genScore = (gen['score'] as num).toDouble();
    final c2paPresent = c2pa['c2paPresent'] as bool;
    final metadataScore = (meta['metadataScore'] as num).toDouble();
    final spectralScore = (spectral['spectralScore'] as num).toDouble();
    final compressionScore = (comp['compressionScore'] as num).toDouble();
    final heatmapBytes = spectral['heatmapPngBytes'] as Uint8List;

    // Combine direct-signal AI evidence into a single "AI signal score" in 0..1.
    //   - explicit generator name → 1.0
    //   - C2PA manifest present but no editor/camera tag → adds 0.3 (informational lean)
    //   - else → 0
    double aiSignalScore = genScore;
    if (c2paPresent && aiGenerator == null) {
      aiSignalScore = (aiSignalScore + 0.3).clamp(0.0, 1.0);
    }

    // Aggregate findings (deduped, ordered: AI evidence → C2PA → metadata).
    final findings = <String>[
      ...List<String>.from(gen['evidence'] as List),
      ...List<String>.from(c2pa['findings'] as List),
      ...List<String>.from(meta['findings'] as List),
    ];

    // Trust score (0..100, 100 = clean human-photographed authentic).
    // Weights: AI signal 40 · spectral 25 · metadata 20 · compression 15.
    final trustScore = (100 -
            (aiSignalScore * 40 +
                spectralScore * 25 +
                metadataScore * 20 +
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
