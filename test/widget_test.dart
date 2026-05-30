import 'package:flutter_test/flutter_test.dart';
import 'package:truthlens/utils/color_utils.dart';

void main() {
  group('verdictFromScores', () {
    test('flags ai_generated when a generator name is detected', () {
      final v = verdictFromScores(
        trustScore: 35,
        aiSignalScore: 1.0,
        spectralScore: 0.2,
        metadataScore: 0.1,
        hasEditorTag: false,
        aiGenerator: 'Midjourney',
      );
      expect(v, 'ai_generated');
    });

    test('flags ai_generated on strong spectral score alone', () {
      final v = verdictFromScores(
        trustScore: 40,
        aiSignalScore: 0.0,
        spectralScore: 0.7,
        metadataScore: 0.0,
        hasEditorTag: false,
        aiGenerator: null,
      );
      expect(v, 'ai_generated');
    });

    test('flags edited when an editor tag is found', () {
      final v = verdictFromScores(
        trustScore: 55,
        aiSignalScore: 0.0,
        spectralScore: 0.1,
        metadataScore: 0.5,
        hasEditorTag: true,
        aiGenerator: null,
      );
      expect(v, 'edited');
    });

    test('returns authentic for clean signals + high trust', () {
      final v = verdictFromScores(
        trustScore: 92,
        aiSignalScore: 0.0,
        spectralScore: 0.05,
        metadataScore: 0.05,
        hasEditorTag: false,
        aiGenerator: null,
      );
      expect(v, 'authentic');
    });
  });

  group('verdictLabel', () {
    test('maps verdicts to display strings', () {
      expect(verdictLabel('authentic'), 'Likely Authentic');
      expect(verdictLabel('ai_generated'), 'Likely AI-Generated');
      expect(verdictLabel('edited'), 'Likely Edited');
      expect(verdictLabel('unknown'), 'Inconclusive');
    });
  });
}
