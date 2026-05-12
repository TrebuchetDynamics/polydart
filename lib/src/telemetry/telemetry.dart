/// Structured telemetry helpers for SDK protocol clients.
library;

import '../logging/logger.dart';

/// Redacts a telemetry value before it reaches log output.
String redactTelemetryValue(String value) {
  if (value.length <= 8) return '[REDACTED]';
  return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
}

/// Wrapper for values that should be redacted when formatted by a logger.
final class RedactableValue {
  const RedactableValue(this.value);

  final String value;

  /// Redacted representation of [value].
  String get redacted => redactTelemetryValue(value);

  @override
  String toString() => redacted;
}

/// Thin telemetry wrapper with a quiet default.
final class TelemetryLogger {
  /// Creates a telemetry logger. Without a sink, records are dropped.
  const TelemetryLogger([Logger? logger]) : _logger = logger ?? Logger.silent;

  final Logger _logger;

  /// Records a completed HTTP request.
  void request({
    required String method,
    required String path,
    required int status,
    required Duration duration,
    Object? error,
  }) {
    final fields = <String, Object?>{
      'method': method,
      'path': path,
      'status': status,
      'dur': duration,
    };
    if (error != null) {
      fields['error'] = error.toString();
      _logger.log(LogLevel.error, 'request failed', fields: fields);
      return;
    }

    _logger.log(_requestLevel(status), 'request', fields: fields);
  }

  /// Records a retry attempt.
  void retry({
    required String method,
    required String path,
    required int attempt,
    required Object error,
  }) {
    _logger.log(
      LogLevel.warn,
      'retry',
      fields: {
        'method': method,
        'path': path,
        'attempt': attempt,
        'error': error.toString(),
      },
    );
  }

  /// Records a rate-limit wait event.
  void rateLimited({
    required String method,
    required String path,
    required Duration wait,
  }) {
    _logger.log(
      LogLevel.warn,
      'rate limited',
      fields: {'method': method, 'path': path, 'wait': wait},
    );
  }

  /// Records a circuit breaker open event.
  void circuitOpen({required String method, required String path}) {
    _logger.log(
      LogLevel.error,
      'circuit breaker open',
      fields: {'method': method, 'path': path},
    );
  }

  LogLevel _requestLevel(int status) {
    if (status >= 500) return LogLevel.error;
    if (status >= 400) return LogLevel.warn;
    return LogLevel.info;
  }
}
