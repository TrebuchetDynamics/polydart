/// Tolerant decoder for Gamma fields that arrive as a string, an array,
/// a 2-D array, or a string containing a JSON-encoded array.
///
/// Mirrors `polytypes.StringOrArray.UnmarshalJSON`. Always returns a flat
/// `List<String>`. Empty / null sources collapse to an empty list.
library;

import 'dart:convert';

List<String> parseStringOrArray(Object? raw) {
  if (raw == null) return const <String>[];

  if (raw is List) {
    final out = <String>[];
    for (final item in raw) {
      if (item is String &&
          item.length >= 2 &&
          item.startsWith('[') &&
          item.endsWith(']')) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is List) {
            out.addAll(decoded.map((e) => e.toString()));
            continue;
          }
        } on FormatException {
          // Fall through to plain-string handling.
        }
      }
      if (item is List) {
        out.addAll(item.map((e) => e.toString()));
        continue;
      }
      if (item is String) {
        out.add(item);
      } else if (item != null) {
        out.add(item.toString());
      }
    }
    return out;
  }

  if (raw is String) {
    if (raw.isEmpty) return const <String>[];
    if (raw.length >= 2 && raw.startsWith('[') && raw.endsWith(']')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList(growable: false);
        }
      } on FormatException {
        // Fall through.
      }
    }
    return <String>[raw];
  }

  return const <String>[];
}
