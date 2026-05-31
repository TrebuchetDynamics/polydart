/// Shared JSON decoding helpers for CLOB wire types.
library;

List<T> clobDecodeObjectList<T>(
  List<dynamic> raw,
  String fieldName,
  T Function(Map<String, dynamic>) decode,
) {
  final out = <T>[];
  for (var index = 0; index < raw.length; index++) {
    out.add(decode(clobObjectCandidateAt(raw, index, fieldName)));
  }
  return List<T>.unmodifiable(out);
}

Map<String, dynamic> clobObjectCandidateAt(
  List<dynamic> candidates,
  int index,
  String fieldName,
) {
  final raw = candidates[index];
  if (raw is! Map<dynamic, dynamic>) {
    throw FormatException('$fieldName[$index] must be a JSON object');
  }
  return raw.cast<String, dynamic>();
}

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
