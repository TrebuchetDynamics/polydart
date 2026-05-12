import 'dart:async';

import 'package:polydart/src/logging/logger.dart';
import 'package:polydart/src/telemetry/telemetry.dart';
import 'package:test/test.dart';

void main() {
  group('TelemetryLogger', () {
    test('defaults to a no-op logger when omitted or null', () {
      final captured = <String>[];
      final spec = ZoneSpecification(
        print: (self, parent, zone, line) => captured.add(line),
      );

      runZoned(() {
        for (final telemetry in [
          const TelemetryLogger(),
          const TelemetryLogger(null),
        ]) {
          telemetry.request(
            method: 'GET',
            path: '/markets',
            status: 200,
            duration: const Duration(milliseconds: 12),
          );
          telemetry.retry(
            method: 'GET',
            path: '/markets',
            attempt: 1,
            error: StateError('retryable'),
          );
          telemetry.rateLimited(
            method: 'GET',
            path: '/markets',
            wait: const Duration(milliseconds: 50),
          );
          telemetry.circuitOpen(method: 'GET', path: '/markets');
        }
      }, zoneSpecification: spec);

      expect(captured, isEmpty);
    });

    test('logs requests with status/error severity and structured fields', () {
      final sink = _RecordingLogger();
      final telemetry = TelemetryLogger(sink);

      telemetry.request(
        method: 'GET',
        path: '/ok',
        status: 200,
        duration: const Duration(milliseconds: 10),
      );
      telemetry.request(
        method: 'GET',
        path: '/missing',
        status: 404,
        duration: const Duration(milliseconds: 20),
      );
      telemetry.request(
        method: 'POST',
        path: '/error',
        status: 500,
        duration: const Duration(milliseconds: 30),
      );
      telemetry.request(
        method: 'DELETE',
        path: '/boom',
        status: 204,
        duration: const Duration(milliseconds: 40),
        error: StateError('network down'),
      );

      expect(
        sink.records.map((record) => (record.level, record.message)).toList(),
        [
          (LogLevel.info, 'request'),
          (LogLevel.warn, 'request'),
          (LogLevel.error, 'request'),
          (LogLevel.error, 'request failed'),
        ],
      );
      expect(sink.records[0].fields, {
        'method': 'GET',
        'path': '/ok',
        'status': 200,
        'dur': const Duration(milliseconds: 10),
      });
      expect(sink.records[3].fields, {
        'method': 'DELETE',
        'path': '/boom',
        'status': 204,
        'dur': const Duration(milliseconds: 40),
        'error': 'Bad state: network down',
      });
    });

    test('logs retry, rate-limit, and circuit-open helper events', () {
      final sink = _RecordingLogger();
      final telemetry = TelemetryLogger(sink);

      telemetry.retry(
        method: 'POST',
        path: '/orders',
        attempt: 3,
        error: StateError('temporary failure'),
      );
      telemetry.rateLimited(
        method: 'GET',
        path: '/markets',
        wait: const Duration(milliseconds: 250),
      );
      telemetry.circuitOpen(method: 'DELETE', path: '/orders/1');

      expect(
        sink.records.map((record) => (record.level, record.message)).toList(),
        [
          (LogLevel.warn, 'retry'),
          (LogLevel.warn, 'rate limited'),
          (LogLevel.error, 'circuit breaker open'),
        ],
      );
      expect(sink.records[0].fields, {
        'method': 'POST',
        'path': '/orders',
        'attempt': 3,
        'error': 'Bad state: temporary failure',
      });
      expect(sink.records[1].fields, {
        'method': 'GET',
        'path': '/markets',
        'wait': const Duration(milliseconds: 250),
      });
      expect(sink.records[2].fields, {'method': 'DELETE', 'path': '/orders/1'});
    });
  });

  group('telemetry redaction', () {
    test('redacts empty and short values completely', () {
      expect(redactTelemetryValue(''), '[REDACTED]');
      expect(redactTelemetryValue('abc'), '[REDACTED]');
      expect(redactTelemetryValue('12345678'), '[REDACTED]');
    });

    test('keeps only the first and last four characters of longer values', () {
      expect(redactTelemetryValue('abcd1234efgh'), 'abcd...efgh');
      expect(redactTelemetryValue('0123456789abcdef'), '0123...cdef');
      expect(
        const RedactableValue('sk_live_0123456789').redacted,
        'sk_l...6789',
      );
    });
  });
}

final class _RecordingLogger implements Logger {
  final records = <_LogRecord>[];

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?>? fields,
    Object? error,
    StackTrace? stackTrace,
  }) {
    records.add(
      _LogRecord(
        level,
        message,
        Map<String, Object?>.unmodifiable(fields ?? const {}),
        error,
        stackTrace,
      ),
    );
  }
}

final class _LogRecord {
  const _LogRecord(
    this.level,
    this.message,
    this.fields,
    this.error,
    this.stackTrace,
  );

  final LogLevel level;
  final String message;
  final Map<String, Object?> fields;
  final Object? error;
  final StackTrace? stackTrace;
}
