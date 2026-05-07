import 'package:polydart/src/types/string_or_array.dart';
import 'package:test/test.dart';

void main() {
  test('null and empty produce empty list', () {
    expect(parseStringOrArray(null), isEmpty);
    expect(parseStringOrArray(''), isEmpty);
  });

  test('plain string wraps in single-element list', () {
    expect(parseStringOrArray('Yes'), ['Yes']);
  });

  test('JSON-encoded array string decodes', () {
    expect(parseStringOrArray('["Yes","No"]'), ['Yes', 'No']);
    expect(parseStringOrArray('["0.5","0.5"]'), ['0.5', '0.5']);
  });

  test('list of strings passes through', () {
    expect(parseStringOrArray(<String>['a', 'b']), ['a', 'b']);
  });

  test('list with embedded JSON-array strings flattens', () {
    expect(
      parseStringOrArray(<dynamic>['["Yes","No"]', 'Maybe']),
      ['Yes', 'No', 'Maybe'],
    );
  });

  test('2-D list flattens', () {
    expect(
      parseStringOrArray(<dynamic>[
        <String>['Yes', 'No'],
        <String>['Maybe'],
      ]),
      ['Yes', 'No', 'Maybe'],
    );
  });

  test('malformed JSON-array string falls back to single element', () {
    expect(parseStringOrArray('[oops'), ['[oops']);
  });
}
