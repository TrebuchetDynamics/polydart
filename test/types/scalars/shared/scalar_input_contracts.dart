import 'package:test/test.dart';

typedef ScalarParser<T> = T Function(Object? raw);

void expectScalarInputCases<T>({
  required ScalarParser<T> parse,
  required Map<Object?, T> cases,
}) {
  for (final entry in cases.entries) {
    expect(parse(entry.key), entry.value, reason: 'input: ${entry.key}');
  }
}
