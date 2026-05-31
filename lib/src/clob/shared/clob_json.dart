/// Shared JSON decoding helpers for CLOB wire types.
library;

Object? clobFirstOf(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key)) return json[key];
  }
  return null;
}

String clobStringOf(Map<String, dynamic> json, List<String> keys) {
  return clobFirstOf(json, keys)?.toString() ?? '';
}

bool clobBool(Object? raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  if (raw is String) {
    final normalized = raw.toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
  return false;
}

double clobDouble(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw) ?? 0;
  return 0;
}

int clobInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? 0;
  return 0;
}
