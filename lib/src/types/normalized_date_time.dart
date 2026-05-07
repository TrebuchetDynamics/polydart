/// Tolerant datetime parser for Gamma fields.
///
/// Gamma emits multiple datetime formats: RFC3339, RFC3339Nano, "YYYY-MM-DD
/// HH:MM:SS+TZ", "YYYY-MM-DD", and the human "January 2, 2006" form. This
/// helper accepts all of them and returns null for null / empty inputs.
///
/// Mirrors `polytypes.NormalizedTime.UnmarshalJSON`.
library;

DateTime? parseNormalizedDateTime(Object? raw) {
  if (raw == null) return null;
  var s = raw.toString().trim();
  if (s.isEmpty || s == 'null') return null;
  if (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
    s = s.substring(1, s.length - 1);
  }
  if (s.isEmpty || s == 'null') return null;

  // Pad short timezone suffixes: "+07" → "+07:00".
  if (s.length >= 3 && (s.contains(' ') || s.contains('T'))) {
    final last3 = s.substring(s.length - 3);
    if ((last3.codeUnitAt(0) == 0x2B || last3.codeUnitAt(0) == 0x2D) &&
        _isDigit(last3.codeUnitAt(1)) &&
        _isDigit(last3.codeUnitAt(2))) {
      final tail = s.length >= 6 ? s.substring(s.length - 6) : '';
      if (tail != '$last3:00') {
        s = '${s.substring(0, s.length - 3)}$last3:00';
      }
    }
  }

  // DateTime.parse accepts RFC3339 / RFC3339Nano / "YYYY-MM-DD" / ISO with
  // space separator after Dart 2.9.
  final direct = DateTime.tryParse(s);
  if (direct != null) return direct;

  final spaceToT = DateTime.tryParse(s.replaceFirst(' ', 'T'));
  if (spaceToT != null) return spaceToT;

  final m = _longDateRegex.firstMatch(s);
  if (m != null) {
    final monthName = m.group(1)!.toLowerCase();
    final day = int.parse(m.group(2)!);
    final year = int.parse(m.group(3)!);
    final month = _monthNameToInt[monthName];
    if (month != null) return DateTime.utc(year, month, day);
  }

  return null;
}

/// Encodes a [DateTime] back to a Gamma-style RFC3339 string, or null.
String? encodeNormalizedDateTime(DateTime? dt) {
  if (dt == null) return null;
  return dt.toUtc().toIso8601String();
}

bool _isDigit(int code) => code >= 0x30 && code <= 0x39;

final RegExp _longDateRegex = RegExp(r'^([A-Za-z]+)\s+(\d{1,2}),\s+(\d{4})$');

const Map<String, int> _monthNameToInt = {
  'january': 1,
  'february': 2,
  'march': 3,
  'april': 4,
  'may': 5,
  'june': 6,
  'july': 7,
  'august': 8,
  'september': 9,
  'october': 10,
  'november': 11,
  'december': 12,
};
