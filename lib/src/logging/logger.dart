/// Pluggable logger surface.
///
/// The SDK never calls `print` directly outside this file; all diagnostic
/// output flows through a [Logger]. Default is [Logger.silent] which drops
/// everything, keeping the SDK quiet by default.
library;

import 'package:meta/meta.dart';

/// Severity. Order matters: a logger filters anything below its threshold.
enum LogLevel {
  debug(0),
  info(1),
  warn(2),
  error(3);

  const LogLevel(this.priority);
  final int priority;
}

/// Sink for SDK diagnostics.
abstract interface class Logger {
  /// Drops every record. Library default — quiet by design.
  static const Logger silent = _SilentLogger();

  /// Writes records via `print` at or above [level].
  static Logger console({LogLevel level = LogLevel.info}) =>
      _ConsoleLogger(level);

  void log(
    LogLevel level,
    String message, {
    Map<String, Object?>? fields,
    Object? error,
    StackTrace? stackTrace,
  });
}

/// Convenience methods. Avoids forcing every call site to spell out the level.
extension LoggerShortcuts on Logger {
  void debug(String m, {Map<String, Object?>? fields}) =>
      log(LogLevel.debug, m, fields: fields);

  void info(String m, {Map<String, Object?>? fields}) =>
      log(LogLevel.info, m, fields: fields);

  void warn(String m, {Map<String, Object?>? fields, Object? error}) =>
      log(LogLevel.warn, m, fields: fields, error: error);

  void err(
    String m, {
    Map<String, Object?>? fields,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      log(
        LogLevel.error,
        m,
        fields: fields,
        error: error,
        stackTrace: stackTrace,
      );
}

@immutable
final class _SilentLogger implements Logger {
  const _SilentLogger();

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?>? fields,
    Object? error,
    StackTrace? stackTrace,
  }) {}
}

final class _ConsoleLogger implements Logger {
  _ConsoleLogger(this._level);

  final LogLevel _level;

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?>? fields,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.priority < _level.priority) return;
    final buf = StringBuffer()
      ..write(level.name.toUpperCase().padRight(5))
      ..write(' ')
      ..write(message);
    if (fields != null && fields.isNotEmpty) {
      fields.forEach((k, v) {
        buf
          ..write(' ')
          ..write(k)
          ..write('=')
          ..write(v);
      });
    }
    if (error != null) {
      buf
        ..write(' err=')
        ..write(error);
    }
    // ignore: avoid_print
    print(buf.toString());
    if (stackTrace != null) {
      // ignore: avoid_print
      print(stackTrace);
    }
  }
}
