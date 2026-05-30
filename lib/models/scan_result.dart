import 'package:hive/hive.dart';

part 'scan_result.g.dart';

/// Persisted record of a single image analysis run.
///
/// v2 pivot: detector set is AI-focused.
///   - [aiSignalScore]  combined generator-signature + C2PA evidence (0..1)
///   - [spectralScore]  FFT-domain high-frequency anomaly (0..1)
///   - [metadataScore]  EXIF integrity + editor/generator software tag
///   - [compressionScore] JPEG 8-pixel block boundary consistency
///
/// [trustScore] is 0–100 where 100 means "looks like a human-photographed
/// authentic image." [aiGenerator] is the name of the AI tool when we can
/// extract it directly from metadata (DALL-E, Stable Diffusion, …).
@HiveType(typeId: 0)
class ScanResult extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String imagePath;

  @HiveField(2)
  final double trustScore;

  @HiveField(3)
  final double spectralScore;

  @HiveField(4)
  final double metadataScore;

  @HiveField(5)
  final double compressionScore;

  @HiveField(6)
  final double aiSignalScore;

  @HiveField(7)
  final List<String> findings;

  @HiveField(8)
  final DateTime scannedAt;

  @HiveField(9)
  final String verdict;

  @HiveField(10)
  final String? heatmapPath;

  @HiveField(11)
  final String? aiGenerator;

  @HiveField(12)
  final bool c2paPresent;

  ScanResult({
    required this.id,
    required this.imagePath,
    required this.trustScore,
    required this.spectralScore,
    required this.metadataScore,
    required this.compressionScore,
    required this.aiSignalScore,
    required this.findings,
    required this.scannedAt,
    required this.verdict,
    this.heatmapPath,
    this.aiGenerator,
    this.c2paPresent = false,
  });
}
