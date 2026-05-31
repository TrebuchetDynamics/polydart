/// Shared JSON array frame splitting for market stream batches.
///
/// Keeps the "this frame was an array" fact separate from the resulting child
/// count so callers can distinguish an empty batch (`[]`) from a non-array
/// frame that should still be decoded as a single JSON object.
library;

import 'dart:convert';

/// Result of attempting to split a WebSocket payload as a JSON array.
final class JsonArrayFrameSplit {
  const JsonArrayFrameSplit._({required this.isArray, required this.frames});

  /// The payload syntactically began with `[` and decoded to a JSON array.
  final bool isArray;

  /// JSON-encoded child payloads when [isArray] is true.
  final List<List<int>> frames;

  static const notArray = JsonArrayFrameSplit._(
    isArray: false,
    frames: <List<int>>[],
  );
}

/// Splits a JSON array frame into individually encoded child frames.
///
/// Returns [JsonArrayFrameSplit.notArray] when [data] is empty, does not start
/// with `[`, fails to parse, or decodes to a non-array JSON value.
JsonArrayFrameSplit splitJsonArrayFrame(List<int> data) {
  if (!_startsWithJsonArray(data)) return JsonArrayFrameSplit.notArray;
  Object? decoded;
  try {
    decoded = json.decode(utf8.decode(data));
  } on FormatException {
    return JsonArrayFrameSplit.notArray;
  }
  if (decoded is! List) return JsonArrayFrameSplit.notArray;
  return JsonArrayFrameSplit._(
    isArray: true,
    frames: decoded
        .map((m) => utf8.encode(json.encode(m)))
        .toList(growable: false),
  );
}

bool _startsWithJsonArray(List<int> data) {
  for (final byte in data) {
    switch (byte) {
      case 0x20: // space
      case 0x09: // tab
      case 0x0A: // line feed
      case 0x0D: // carriage return
        continue;
      case 0x5B: // '['
        return true;
      default:
        return false;
    }
  }
  return false;
}
