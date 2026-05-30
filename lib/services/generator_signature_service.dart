import 'dart:convert';
import 'dart:typed_data';

import 'package:exif/exif.dart';

/// Known generator name substrings — case-insensitive. Map to the canonical
/// display name shown in the UI.
const _generators = <String, String>{
  'midjourney': 'Midjourney',
  'dall-e': 'DALL-E',
  'dalle': 'DALL-E',
  'stable diffusion': 'Stable Diffusion',
  'stablediffusion': 'Stable Diffusion',
  'sdxl': 'Stable Diffusion (SDXL)',
  'flux': 'Flux',
  'firefly': 'Adobe Firefly',
  'imagen': 'Google Imagen',
  'gemini': 'Gemini Image',
  'sora': 'OpenAI Sora',
  'leonardo': 'Leonardo.AI',
  'ideogram': 'Ideogram',
  'recraft': 'Recraft',
  'comfyui': 'ComfyUI',
  'automatic1111': 'Automatic1111',
  'invokeai': 'InvokeAI',
  'krea': 'Krea',
  'runway': 'Runway',
  'gen-3': 'Runway Gen-3',
};

/// Cross-format AI generator name scanner.
///
/// Looks at EXIF Software fields and at PNG `tEXt` / `iTXt` chunks (where
/// Automatic1111, ComfyUI, etc. embed prompt + generator info verbatim).
///
/// Returns: `{aiGenerator: String?, evidence: List<String>, score: 0..1}`.
Future<Map<String, dynamic>> runGeneratorSignature(Uint8List bytes) async {
  final evidence = <String>[];
  String? generator;

  // ---- EXIF Software / Processing Software / ImageDescription ----
  try {
    final tags = await readExifFromBytes(bytes);
    final searchTags = [
      'Image Software',
      'Software',
      'Image ProcessingSoftware',
      'Image ImageDescription',
      'EXIF UserComment',
    ];
    for (final t in searchTags) {
      final v = tags[t]?.printable;
      if (v == null || v.isEmpty) continue;
      final lower = v.toLowerCase();
      for (final entry in _generators.entries) {
        if (lower.contains(entry.key)) {
          generator ??= entry.value;
          evidence.add('$t contains "${entry.value}"');
        }
      }
    }
  } catch (_) {}

  // ---- PNG tEXt / iTXt / zTXt chunks ----
  // PNG signature: 89 50 4E 47 0D 0A 1A 0A
  bool isPng = bytes.length > 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
  if (isPng) {
    final textChunks = _readPngTextChunks(bytes);
    for (final kv in textChunks.entries) {
      final key = kv.key.toLowerCase();
      final val = kv.value.toLowerCase();
      // Automatic1111 stores everything in `parameters`; ComfyUI in `prompt`/`workflow`.
      if (key == 'parameters' || key == 'prompt' || key == 'workflow') {
        evidence.add('PNG chunk "${kv.key}" present (typical of AI image tools)');
        generator ??= 'Stable Diffusion';
      }
      for (final entry in _generators.entries) {
        if (key.contains(entry.key) || val.contains(entry.key)) {
          generator ??= entry.value;
          evidence.add('PNG metadata mentions "${entry.value}"');
        }
      }
    }
  }

  // Score = strong signal if any generator name detected.
  final score = generator != null ? 1.0 : 0.0;
  return {
    'aiGenerator': generator,
    'evidence': evidence,
    'score': score,
  };
}

/// Parse PNG tEXt / iTXt / zTXt chunks → { keyword: value }.
/// We only decode the keyword + the textual part (no zlib for zTXt — skipped).
Map<String, String> _readPngTextChunks(Uint8List bytes) {
  final out = <String, String>{};
  int i = 8; // skip PNG signature
  while (i + 8 < bytes.length) {
    final length = (bytes[i] << 24) | (bytes[i + 1] << 16) | (bytes[i + 2] << 8) | bytes[i + 3];
    final type = String.fromCharCodes(bytes.sublist(i + 4, i + 8));
    final dataStart = i + 8;
    final dataEnd = dataStart + length;
    if (dataEnd > bytes.length) break;
    if (type == 'tEXt' || type == 'iTXt') {
      try {
        final raw = bytes.sublist(dataStart, dataEnd);
        final nul = raw.indexOf(0);
        if (nul > 0) {
          final keyword = ascii.decode(raw.sublist(0, nul), allowInvalid: true);
          // For iTXt there are extra fields (compression flag, language, translated keyword)
          // before the actual text; we approximate by finding the last null and taking the tail.
          int textStart = nul + 1;
          if (type == 'iTXt') {
            // skip compression flag + method (2 bytes) + null-terminated lang + null-terminated translated keyword
            int p = textStart + 2;
            int firstNul = raw.indexOf(0, p);
            if (firstNul > 0) {
              int secondNul = raw.indexOf(0, firstNul + 1);
              if (secondNul > 0) textStart = secondNul + 1;
            }
          }
          final text = utf8.decode(raw.sublist(textStart), allowMalformed: true);
          out[keyword] = text;
        }
      } catch (_) {}
    }
    if (type == 'IEND') break;
    i = dataEnd + 4; // skip CRC
  }
  return out;
}
