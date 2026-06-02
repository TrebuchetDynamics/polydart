/// Shared JSON object frame decoder for stream internals.
///
/// Keeps parse and shape errors explicit so callers such as the stream
/// deduplicator can decide whether malformed payloads should be forwarded.
library;

import 'dart:convert';

/// Result status for decoding one JSON object frame.
enum JsonObjectFrameDecodeStatus { ok, invalidJson, nonObjectJson }

/// Decoded JSON object frame with parse/shape status.
final class JsonObjectFrameDecodeResult {
  const JsonObjectFrameDecodeResult._(this.status, this.value);

  const JsonObjectFrameDecodeResult.ok(Map<String, dynamic> value)
    : this._(JsonObjectFrameDecodeStatus.ok, value);

  const JsonObjectFrameDecodeResult.invalidJson()
    : this._(JsonObjectFrameDecodeStatus.invalidJson, null);

  const JsonObjectFrameDecodeResult.nonObjectJson()
    : this._(JsonObjectFrameDecodeStatus.nonObjectJson, null);

  final JsonObjectFrameDecodeStatus status;
  final Map<String, dynamic>? value;
}

/// Decodes [bytes] as a JSON object and reports invalid/shape failures without
/// throwing.
JsonObjectFrameDecodeResult decodeJsonObjectFrame(List<int> bytes) {
  Object? decoded;
  try {
    decoded = json.decode(utf8.decode(bytes));
  } on FormatException {
    return const JsonObjectFrameDecodeResult.invalidJson();
  }
  if (decoded is! Map) {
    return const JsonObjectFrameDecodeResult.nonObjectJson();
  }
  return JsonObjectFrameDecodeResult.ok(
    decoded.map<String, dynamic>((key, value) => MapEntry(key.toString(), value)),
  );
}
