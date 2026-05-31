/// Redaction helpers for safe logging.
///
/// Mirrors `transport.RedactSecret` and `transport.RedactMap`. Secret-bearing
/// values are clipped or replaced before they reach a logger.
library;

const Set<String> _sensitiveHeaderNames = {
  'POLY_PRIVATE_KEY',
  'POLY_API_KEY',
  'POLY_SECRET',
  'POLY_PASSPHRASE',
  'POLY_SIGNATURE',
  'POLY_BUILDER_API_KEY',
  'POLY_BUILDER_SECRET',
  'POLY_BUILDER_PASSPHRASE',
  'POLY_BUILDER_SIGNATURE',
  'RELAYER_API_KEY',
};

bool _isSensitiveHeaderName(String name) =>
    _sensitiveHeaderNames.contains(name.toUpperCase());

/// Redacts a single secret-bearing string.
///
/// Empty input returns empty. Strings of 8 chars or fewer become
/// `[REDACTED]`. Longer strings keep the first and last 4 chars with
/// an ellipsis.
String redactSecret(String value) {
  if (value.isEmpty) return '';
  if (value.length <= 8) return '[REDACTED]';
  return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
}

/// Returns a copy of [headers] with sensitive values redacted.
Map<String, String> redactMap(Map<String, String> headers) {
  final out = <String, String>{};
  for (final entry in headers.entries) {
    if (_isSensitiveHeaderName(entry.key)) {
      out[entry.key] = redactSecret(entry.value);
    } else {
      out[entry.key] = entry.value;
    }
  }
  return out;
}
