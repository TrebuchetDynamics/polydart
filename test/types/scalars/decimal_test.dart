import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/types/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('Decimal.parse', () {
    test('accepts integers, decimals, negatives', () {
      expect(Decimal.parse('0').raw, '0');
      expect(Decimal.parse('1.5').raw, '1.5');
      expect(Decimal.parse('-12.34').raw, '-12.34');
      expect(Decimal.parse('  3.14  ').raw, '3.14');
    });

    test('throws on empty / garbage', () {
      expect(() => Decimal.parse(''), throwsA(isA<ValidationException>()));
      expect(() => Decimal.parse('abc'), throwsA(isA<ValidationException>()));
      expect(() => Decimal.parse('1.2.3'), throwsA(isA<ValidationException>()));
      expect(() => Decimal.parse('0x10'), throwsA(isA<ValidationException>()));
    });
  });

  test('tryParse returns null on garbage', () {
    expect(Decimal.tryParse('foo'), isNull);
    expect(Decimal.tryParse('1.5'), isNotNull);
  });

  test('zero / one constants', () {
    expect(Decimal.zero.isZero, isTrue);
    expect(Decimal.one.isZero, isFalse);
    expect(Decimal.one.toDouble(), 1.0);
  });

  test('equality compares numeric value', () {
    expect(Decimal.parse('1.50'), Decimal.parse('1.5'));
    expect(Decimal.parse('0'), Decimal.parse('0.0'));
    expect(Decimal.parse('1') == Decimal.parse('2'), isFalse);
  });

  test('fromInt round-trips', () {
    expect(Decimal.fromInt(42).raw, '42');
    expect(Decimal.fromInt(-7).toDouble(), -7.0);
  });
}
