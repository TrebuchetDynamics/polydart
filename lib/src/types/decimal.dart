/// String-backed decimal for Polymarket prices and amounts.
///
/// Mirrors `polytypes.Decimal`. Phase 1 uses string storage with float-based
/// equality and ordering. Real big-decimal arithmetic lands in Phase 2 when
/// order math requires it.
library;

import 'package:meta/meta.dart';

import '../errors/errors.dart';

@immutable
final class Decimal {
  const Decimal._(this._value);

  /// Parses a decimal literal. Throws [ValidationException] on garbage input.
  factory Decimal.parse(String input) {
    final s = input.trim();
    if (s.isEmpty) {
      throw const ValidationException(
        code: ErrorCode.invalidValue,
        message: 'invalid decimal: empty',
      );
    }
    if (!_decimalRegex.hasMatch(s)) {
      throw ValidationException(
        code: ErrorCode.invalidValue,
        message: 'invalid decimal: $s',
      );
    }
    return Decimal._(s);
  }

  /// Returns null instead of throwing.
  static Decimal? tryParse(String input) {
    try {
      return Decimal.parse(input);
    } on ValidationException {
      return null;
    }
  }

  factory Decimal.fromInt(int n) => Decimal._(n.toString());

  static const Decimal zero = Decimal._('0');
  static const Decimal one = Decimal._('1');

  final String _value;

  String get raw => _value;

  bool get isZero => toDouble() == 0;

  double toDouble() => double.parse(_value);

  @override
  String toString() => _value;

  /// Equality compares numeric value, so `0` and `0.0` collide.
  @override
  bool operator ==(Object other) =>
      other is Decimal && other.toDouble() == toDouble();

  @override
  int get hashCode => toDouble().hashCode;
}

final RegExp _decimalRegex = RegExp(r'^-?\d+(\.\d+)?$');
