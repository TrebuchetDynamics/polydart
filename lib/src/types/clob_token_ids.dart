/// Shared parsing for Gamma's token-id fields.
///
/// Gamma often exposes CLOB token ids as `clobTokenIds`, a JSON-encoded array
/// stored inside a string. Keep the parser tolerant so read-side flows can
/// replay partially populated Gamma payloads without dropping candidates.
library;

import 'dart:convert';

/// Parses Gamma's `clobTokenIds` field — a JSON-encoded array of strings
/// stored as a string. Tolerant of empty / `[]` / malformed input.
List<String> parseClobTokenIds(String raw) {
  final s = raw.trim();
  if (s.isEmpty || s == '[]' || s == 'null') return const <String>[];

  try {
    final decoded = jsonDecode(s);
    if (decoded is List) {
      return decoded
          .map(_trimmedTokenId)
          .where((tokenId) => tokenId.isNotEmpty)
          .toList(growable: false);
    }
  } on FormatException {
    // fall through to manual parse for legacy payloads
  }

  final out = <String>[];
  final buffer = StringBuffer();
  var inQuote = false;
  for (final code in s.runes) {
    final c = String.fromCharCode(code);
    if (c == '"') {
      inQuote = !inQuote;
      if (!inQuote) {
        final tokenId = _trimmedTokenId(buffer.toString());
        if (tokenId.isNotEmpty) out.add(tokenId);
        buffer.clear();
      }
    } else if (inQuote) {
      buffer.write(c);
    }
  }
  return out;
}

String _trimmedTokenId(Object? value) => value?.toString().trim() ?? '';
