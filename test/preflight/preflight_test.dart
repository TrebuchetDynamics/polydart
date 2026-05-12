import 'dart:async';

import 'package:polydart/src/preflight/preflight.dart';
import 'package:test/test.dart';

void main() {
  test('runPreflight reports probe failures', () async {
    final result = await runPreflight([
      PreflightCheck(name: 'gamma', probe: () {}),
      PreflightCheck(name: 'clob', probe: () => throw StateError('503')),
    ]);

    expect(result.ok, isFalse);
    expect(result.checks[0].status, 'pass');
    expect(result.checks[0].message, isNull);
    expect(result.checks[1].name, 'clob');
    expect(result.checks[1].status, 'fail');
    expect(result.checks[1].message, contains('503'));
  });

  test('runPreflight awaits probes sequentially', () async {
    final events = <String>[];

    final result = await runPreflight([
      PreflightCheck(
        name: 'first',
        probe: () async {
          events.add('first:start');
          await Future<void>.delayed(Duration.zero);
          events.add('first:end');
        },
      ),
      PreflightCheck(
        name: 'second',
        probe: () {
          events.add('second');
        },
      ),
    ]);

    expect(result.ok, isTrue);
    expect(events, ['first:start', 'first:end', 'second']);
    expect(result.checks.map((check) => check.status), ['pass', 'pass']);
  });

  test('result snapshots serialize with Polygolem field names', () async {
    final result = await runPreflight([
      const PreflightCheck(name: 'gamma', probe: Future<void>.value),
    ]);

    expect(result.toJson(), {
      'ok': true,
      'checks': [
        {'name': 'gamma', 'status': 'pass'},
      ],
    });
  });
}
