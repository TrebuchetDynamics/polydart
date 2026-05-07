/// Tolerant decoder for CLOB fields that arrive as a JSON string OR number.
///
/// Mirrors `polytypes.NumericString.UnmarshalJSON`. Returns the canonical
/// string form so downstream order math stays string-based and exact.
library;

String parseNumericString(Object? raw) {
  if (raw == null) return '';
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed == 'null') return '';
    return trimmed;
  }
  if (raw is num) return raw.toString();
  return raw.toString();
}
