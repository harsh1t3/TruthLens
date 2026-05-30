import 'dart:typed_data';

/// Lightweight C2PA manifest detector.
///
/// We don't cryptographically verify the manifest — that requires the full
/// C2PA SDK and trust list. We just scan the file for the JUMBF box
/// signature that wraps a C2PA assertion store. Its presence means *something*
/// claimed provenance for this file; absence means no provenance metadata at
/// all (the common case for unsigned content).
///
/// JUMBF boxes follow ISO BMFF box layout. The C2PA manifest sits in a JUMB
/// box whose payload begins with `jumd` (description) containing the UUID
/// for "c2pa". We use a fast byte scan for the marker strings:
///   - `jumbf` / `jumb` / `c2pa` / `c2cl`
/// In JPEG, the manifest is embedded in APP11 markers labeled `JP`.
/// In PNG, in `caBX` chunks.
Map<String, dynamic> runC2PA(Uint8List bytes) {
  final findings = <String>[];

  // JPEG APP11 marker (FF EB) carrying JP-prefixed C2PA payload.
  bool isJpeg = bytes.length > 4 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  bool isPng = bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;

  bool found = false;

  if (isJpeg) {
    // Scan for FF EB ?? ?? "JP" sequence — very fast linear scan.
    for (int i = 2; i < bytes.length - 8; i++) {
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xEB) {
        // Skip marker + 2-byte length, then check next two bytes.
        if (i + 6 < bytes.length && bytes[i + 4] == 0x4A && bytes[i + 5] == 0x50) {
          found = true;
          findings.add('C2PA manifest embedded in JPEG (APP11 / "JP")');
          break;
        }
      }
    }
  }

  if (isPng) {
    // PNG chunks: scan for "caBX" or "iTXt"/"tEXt" with c2pa keyword.
    int i = 8;
    while (i + 8 < bytes.length) {
      final length =
          (bytes[i] << 24) | (bytes[i + 1] << 16) | (bytes[i + 2] << 8) | bytes[i + 3];
      final type = String.fromCharCodes(bytes.sublist(i + 4, i + 8));
      if (type == 'caBX') {
        found = true;
        findings.add('C2PA manifest embedded in PNG (caBX chunk)');
        break;
      }
      if (type == 'IEND') break;
      i = i + 8 + length + 4;
      if (i < 0 || i > bytes.length) break;
    }
  }

  // Generic fallback: search for "c2pa" / "urn:uuid:c2pa" literal substring in
  // first 256KB. Catches edge formats and non-standard embeds.
  if (!found) {
    final scanLen = bytes.length < 262144 ? bytes.length : 262144;
    final view = bytes.sublist(0, scanLen);
    if (_contains(view, _c2paBytes) || _contains(view, _c2pa2Bytes)) {
      found = true;
      findings.add('C2PA identifier present in file metadata');
    }
  }

  return {
    'c2paPresent': found,
    'findings': findings,
  };
}

final _c2paBytes = Uint8List.fromList('c2pa'.codeUnits);
final _c2pa2Bytes = Uint8List.fromList('urn:uuid:c2pa'.codeUnits);

bool _contains(Uint8List haystack, Uint8List needle) {
  if (needle.isEmpty || needle.length > haystack.length) return false;
  outer:
  for (int i = 0; i <= haystack.length - needle.length; i++) {
    for (int j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}
