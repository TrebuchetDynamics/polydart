/// Circuit breaker.
///
/// Mirrors `internal/transport.CircuitBreaker`. Closed → Open after enough
/// failures; Open → HalfOpen after the reset timeout; HalfOpen → Closed
/// once a quota of probe requests succeeds, or back to Open on the first
/// half-open failure.
library;

import 'package:meta/meta.dart';

import '../errors/errors.dart';

enum CircuitState { closed, open, halfOpen }

@immutable
final class CircuitBreakerConfig {
  const CircuitBreakerConfig({
    this.maxFailures = 5,
    this.resetTimeout = const Duration(seconds: 60),
    this.halfOpenMaxRequests = 3,
  }) : assert(maxFailures > 0, 'maxFailures must be positive'),
       assert(halfOpenMaxRequests > 0, 'halfOpenMaxRequests must be positive');

  final int maxFailures;
  final Duration resetTimeout;
  final int halfOpenMaxRequests;
}

final class CircuitBreaker {
  CircuitBreaker({
    CircuitBreakerConfig config = const CircuitBreakerConfig(),
    DateTime Function()? now,
  }) : _config = config,
       _now = now ?? DateTime.now;

  final CircuitBreakerConfig _config;
  final DateTime Function() _now;

  CircuitState _state = CircuitState.closed;
  int _failures = 0;
  int _halfOpenRequests = 0;
  int _halfOpenSuccesses = 0;
  DateTime? _lastFailTime;

  CircuitState get state => _state;
  int get failures => _failures;

  /// Throws [TransportException] (`circuitOpen` or `rateLimited`) if a
  /// request is not currently allowed. Side-effect: open → half-open
  /// transition once the reset timeout has elapsed.
  void beforeRequest() {
    if (_state == CircuitState.open) {
      final last = _lastFailTime;
      final elapsed = last == null ? Duration.zero : _now().difference(last);
      if (elapsed > _config.resetTimeout) {
        _state = CircuitState.halfOpen;
        _halfOpenRequests = 0;
        _halfOpenSuccesses = 0;
      }
    }

    switch (_state) {
      case CircuitState.closed:
        return;
      case CircuitState.open:
        throw const TransportException(
          code: ErrorCode.circuitOpen,
          message: 'circuit breaker is open',
        );
      case CircuitState.halfOpen:
        if (_halfOpenRequests >= _config.halfOpenMaxRequests) {
          throw const TransportException(
            code: ErrorCode.rateLimited,
            message: 'circuit half-open: too many requests',
          );
        }
        _halfOpenRequests++;
        return;
    }
  }

  /// Records the outcome of a request. Pass null on success or the error
  /// object on failure.
  void recordResult(Object? error) {
    if (error != null) {
      _recordFailure();
    } else {
      _recordSuccess();
    }
  }

  /// Wraps an async operation. Calls [beforeRequest] up front and
  /// [recordResult] when [fn] completes.
  Future<T> protect<T>(Future<T> Function() fn) async {
    beforeRequest();
    try {
      final result = await fn();
      recordResult(null);
      return result;
    } catch (e) {
      recordResult(e);
      rethrow;
    }
  }

  void reset() {
    _state = CircuitState.closed;
    _failures = 0;
    _halfOpenRequests = 0;
    _halfOpenSuccesses = 0;
    _lastFailTime = null;
  }

  void _recordFailure() {
    _lastFailTime = _now();
    switch (_state) {
      case CircuitState.closed:
        _failures++;
        if (_failures >= _config.maxFailures) {
          _state = CircuitState.open;
        }
      case CircuitState.halfOpen:
        _state = CircuitState.open;
        _failures = _config.maxFailures;
      case CircuitState.open:
        break;
    }
  }

  void _recordSuccess() {
    switch (_state) {
      case CircuitState.closed:
        _failures = 0;
      case CircuitState.halfOpen:
        _halfOpenSuccesses++;
        if (_halfOpenSuccesses >= _config.halfOpenMaxRequests) {
          _state = CircuitState.closed;
          _failures = 0;
        }
      case CircuitState.open:
        break;
    }
  }
}
