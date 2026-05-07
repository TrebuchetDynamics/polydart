import 'package:polydart/src/types/numeric_string.dart';
import 'package:test/test.dart';

void main() {
  test('null and "null" collapse to empty', () {
    expect(parseNumericString(null), '');
    expect(parseNumericString('null'), '');
  });

  test('strings are trimmed', () {
    expect(parseNumericString('  0.5  '), '0.5');
    expect(parseNumericString('0.5'), '0.5');
  });

  test('numbers stringify', () {
    expect(parseNumericString(0.5), '0.5');
    expect(parseNumericString(1), '1');
    expect(parseNumericString(0), '0');
  });

  test('arbitrary objects fall back to toString', () {
    expect(parseNumericString(true), 'true');
  });
}
