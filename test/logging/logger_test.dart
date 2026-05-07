import 'dart:async';

import 'package:polydart/src/logging/logger.dart';
import 'package:test/test.dart';

void main() {
  group('Logger.silent', () {
    test('drops every record without throwing', () {
      const log = Logger.silent;
      log.debug('x');
      log.info('y');
      log.warn('z');
      log.err('w');
    });
  });

  group('Logger.console', () {
    late List<String> captured;

    setUp(() => captured = <String>[]);

    R capture<R>(R Function() body) {
      final spec = ZoneSpecification(
        print: (self, parent, zone, line) => captured.add(line),
      );
      return runZoned(body, zoneSpecification: spec);
    }

    test('skips records below threshold', () {
      capture(() {
        final log = Logger.console(level: LogLevel.warn);
        log.debug('skipped-debug');
        log.info('skipped-info');
        log.warn('kept-warn', fields: {'k': 1});
        log.err('kept-error');
      });
      expect(captured.any((l) => l.contains('skipped-debug')), isFalse);
      expect(captured.any((l) => l.contains('skipped-info')), isFalse);
      expect(
        captured.any((l) => l.contains('kept-warn') && l.contains('k=1')),
        isTrue,
      );
      expect(captured.any((l) => l.contains('kept-error')), isTrue);
    });

    test('records error and stack trace separately', () {
      capture(() {
        final log = Logger.console(level: LogLevel.debug);
        log.err(
          'boom',
          error: StateError('oops'),
          stackTrace: StackTrace.current,
        );
      });
      expect(captured.any((l) => l.contains('boom')), isTrue);
      expect(captured.any((l) => l.contains('err=')), isTrue);
    });
  });
}
