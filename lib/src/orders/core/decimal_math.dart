/// Internal decimal arithmetic helpers for order amount math.
///
/// These helpers keep replayable order calculations in integer/rational space
/// so decimal tick boundaries are not affected by binary floating point drift.
library;

import '../../errors/errors.dart';

/// Exact rational representation of a base-10 decimal literal.
typedef DecimalRatio = ({BigInt numerator, BigInt denominator});

/// Number of significant decimal places in [s], ignoring trailing zeroes.
int decimalsOf(String s) {
  final dot = s.indexOf('.');
  if (dot < 0) return 0;
  return s.substring(dot + 1).replaceFirst(RegExp(r'0+$'), '').length;
}

/// Parses a simple base-10 decimal string into an exact ratio.
DecimalRatio decimalRatio(String raw) {
  final value = raw.trim();
  final negative = value.startsWith('-');
  final body = negative ? value.substring(1) : value;
  final dot = body.indexOf('.');
  final whole = dot < 0 ? body : body.substring(0, dot);
  final fractional = dot < 0 ? '' : body.substring(dot + 1);
  final digits = whole + fractional;
  final numerator = BigInt.parse(digits.isEmpty ? '0' : digits);
  final signedNumerator = negative ? -numerator : numerator;
  return (numerator: signedNumerator, denominator: pow10(fractional.length));
}

/// Returns [raw] truncated to [scale] decimal places as integer units.
BigInt decimalUnitsAtScale(String raw, int scale) {
  final ratio = decimalRatio(raw);
  if (ratio.numerator < BigInt.zero) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'amount must be non-negative',
      field: 'amount',
    );
  }
  return (ratio.numerator * pow10(scale)) ~/ ratio.denominator;
}

/// Rounds [value] down to the nearest [tickSize] multiple using exact decimal
/// arithmetic. [tickSize] must be non-zero.
String roundDecimalDownToTick(String value, String tickSize) {
  final v = decimalRatio(value);
  final t = decimalRatio(tickSize);
  if (t.numerator == BigInt.zero) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'tickSize must be non-zero',
    );
  }

  final quotient =
      (v.numerator * t.denominator) ~/ (v.denominator * t.numerator);
  final outputDecimals = decimalsOf(tickSize);
  final outputScale = pow10(outputDecimals);
  final outputUnits = (quotient * t.numerator * outputScale) ~/ t.denominator;
  return formatFixedDecimal(outputUnits, outputDecimals);
}

/// Formats integer [units] scaled by 10^[scale] with exactly [scale] decimals.
String formatFixedDecimal(BigInt units, int scale) {
  if (scale == 0) return units.toString();
  final negative = units < BigInt.zero;
  final absUnits = negative ? -units : units;
  final scaleFactor = pow10(scale);
  final whole = absUnits ~/ scaleFactor;
  final fractional = (absUnits % scaleFactor).toString().padLeft(scale, '0');
  return '${negative ? '-' : ''}$whole.$fractional';
}

BigInt pow10(int exponent) {
  var out = BigInt.one;
  for (var i = 0; i < exponent; i++) {
    out *= BigInt.from(10);
  }
  return out;
}

int minInt(int a, int b) => a < b ? a : b;
