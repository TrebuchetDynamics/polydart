/// Shared JSON WebSocket frame decoding helpers for stream clients.
///
/// Keeps transport-frame normalization and JSON object validation consistent
/// across market and authenticated user streams without broadening the public
/// SDK API.
library;

import 'dart:convert';

/// Normalizes a WebSocket text/binary frame into UTF-8 bytes.
///
/// Unsupported frame shapes return `null` and should be ignored by callers.
List<int>? streamFrameBytes(dynamic frame) {
  if (frame is String) return utf8.encode(frame);
  if (frame is List<int>) return frame;
  return null;
}

/// Decodes [bytes] as a JSON object, reporting parse/shape failures through
/// [emitError].
Map<String, dynamic>? decodeStreamJsonObject(
  List<int> bytes, {
  required String expectedObjectMessage,
  required void Function(Object error) emitError,
}) {
  Object? decoded;
  try {
    decoded = json.decode(utf8.decode(bytes));
  } on FormatException catch (e) {
    emitError(e);
    return null;
  }
  if (decoded is! Map) {
    emitError(FormatException(expectedObjectMessage, decoded));
    return null;
  }
  return decoded.map<String, dynamic>((k, v) => MapEntry(k.toString(), v));
}
