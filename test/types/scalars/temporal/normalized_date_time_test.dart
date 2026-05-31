import 'package:polydart/src/types/normalized_date_time.dart';
import 'package:test/test.dart';

import '../shared/scalar_input_contracts.dart';

void main() {
  test('null / empty / "null" return null', () {
    expectScalarInputCases(
      parse: parseNormalizedDateTime,
      cases: const <Object?, DateTime?>{
        null: null,
        '': null,
        'null': null,
        '"null"': null,
      },
    );
  });

  test('quoted ISO-8601 unwraps', () {
    final dt = parseNormalizedDateTime('"2026-05-07T12:34:56Z"');
    expect(dt, isNotNull);
    expect(dt!.toUtc().year, 2026);
    expect(dt.toUtc().month, 5);
    expect(dt.toUtc().hour, 12);
  });

  test('RFC3339 with fractional seconds', () {
    final dt = parseNormalizedDateTime('2026-05-07T12:34:56.789Z');
    expect(dt!.toUtc().millisecond, 789);
  });

  test('space-separated form gets converted', () {
    final dt = parseNormalizedDateTime('2026-05-07 12:34:56+00:00');
    expect(dt, isNotNull);
    expect(dt!.toUtc().day, 7);
  });

  test('short timezone padded', () {
    final dt = parseNormalizedDateTime('2026-05-07T12:34:56+07');
    expect(dt, isNotNull);
    expect(dt!.toUtc().hour, 5);
  });

  test('date-only form', () {
    final dt = parseNormalizedDateTime('2026-05-07');
    expect(dt, DateTime.utc(2026, 5, 7));
  });

  test('invalid date-only form is rejected instead of normalized', () {
    expect(parseNormalizedDateTime('2026-02-30'), isNull);
    expect(parseNormalizedDateTime('2026-13-01'), isNull);
  });

  test('long human form', () {
    final dt = parseNormalizedDateTime('May 7, 2026');
    expect(dt, isNotNull);
    expect(dt!.year, 2026);
    expect(dt.month, 5);
    expect(dt.day, 7);
  });

  test('invalid long human form is rejected instead of normalized', () {
    expect(parseNormalizedDateTime('February 30, 2026'), isNull);
  });

  test('encode round-trips a UTC moment', () {
    final dt = DateTime.utc(2026, 5, 7, 12, 34, 56);
    final encoded = encodeNormalizedDateTime(dt);
    expect(encoded, '2026-05-07T12:34:56.000Z');
  });

  test('encode null returns null', () {
    expect(encodeNormalizedDateTime(null), isNull);
  });

  test('garbage returns null', () {
    expect(parseNormalizedDateTime('not a date'), isNull);
  });
}
