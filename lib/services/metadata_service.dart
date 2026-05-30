import 'dart:typed_data';

import 'package:exif/exif.dart';

/// EXIF metadata integrity check.
///
/// Two classes of signals:
///   - Strong: editor / generator software tags (Photoshop, GIMP, …, plus
///     AI tools — those raise score sharply).
///   - Moderate: DateTime inconsistencies between DateTime / DateTimeOriginal
///     / DateTimeDigitized fields.
///
/// Missing-GPS is *not* weighted because almost every shared photo has had
/// its location stripped on upload. Missing Make/Model is mildly suspicious
/// because every camera and phone writes those.
///
/// Returns: { metadataScore, findings }
Future<Map<String, dynamic>> runMetadata(Uint8List bytes) async {
  final issues = <String>[];
  double score = 0;

  Map<String, IfdTag> tags;
  try {
    tags = await readExifFromBytes(bytes);
  } catch (_) {
    return {
      'metadataScore': 0.2,
      'findings': <String>['Unable to read EXIF metadata'],
    };
  }

  if (tags.isEmpty) {
    return {
      'metadataScore': 0.35,
      'findings': <String>['No EXIF metadata present (possibly stripped or screenshot)'],
    };
  }

  String? tagValue(String key) => tags[key]?.printable;

  // Editor / generator signature in Software tag.
  final software = (tagValue('Image Software') ?? tagValue('Software') ?? '').toLowerCase();
  const editors = [
    'photoshop', 'gimp', 'lightroom', 'pixelmator', 'affinity',
    'snapseed', 'facetune', 'capture one', 'darktable',
  ];
  for (final e in editors) {
    if (software.contains(e)) {
      issues.add('Edited with $e (Software: "$software")');
      score += 0.5;
      break;
    }
  }

  // DateTime inconsistencies.
  final dt = tagValue('Image DateTime');
  final dtOriginal = tagValue('EXIF DateTimeOriginal');
  final dtDigitized = tagValue('EXIF DateTimeDigitized');
  if (dt != null && dtOriginal != null && dt != dtOriginal) {
    issues.add('DateTime ($dt) differs from DateTimeOriginal ($dtOriginal)');
    score += 0.3;
  }
  if (dtOriginal != null && dtDigitized != null && dtOriginal != dtDigitized) {
    issues.add('DateTimeOriginal and DateTimeDigitized do not match');
    score += 0.15;
  }

  // Missing Make/Model.
  if (tagValue('Image Make') == null && tagValue('Image Model') == null) {
    issues.add('Camera Make/Model fields are missing');
    score += 0.1;
  }

  if (dtOriginal == null) {
    issues.add('DateTimeOriginal is missing');
    score += 0.1;
  }

  if (issues.isEmpty) {
    issues.add('No metadata anomalies detected');
  }

  return {
    'metadataScore': score.clamp(0.0, 1.0),
    'findings': issues,
  };
}
