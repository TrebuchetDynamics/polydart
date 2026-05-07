/// Token-bucket rate limiter.
///
/// Mirrors `internal/transport.RateLimiter`. Use one limiter per upstream
/// host. Inject a custom `now` for deterministic tests; production calls
/// default to [DateTime.now].
library;

import 'dart:async';

final class RateLimiter {
  RateLimiter({required this.requestsPerSecond, DateTime Function()? now})
    : assert(requestsPerSecond > 0, 'requestsPerSecond must be positive'),
      _capacity = requestsPerSecond.toDouble(),
      _tokens = requestsPerSecond.toDouble(),
      _now = now ?? DateTime.now,
      _lastRefill = (now ?? DateTime.now)();

  final int requestsPerSecond;
  final double _capacity;
  final DateTime Function() _now;

  double _tokens;
  DateTime _lastRefill;
  bool _stopped = false;

  /// Whether the limiter has been stopped.
  bool get isStopped => _stopped;

  /// Capacity of the bucket.
  int get capacity => _capacity.toInt();

  /// Approximate tokens currently available. Refills the bucket as a side
  /// effect.
  int get available {
    _refill();
    return _tokens.floor();
  }

  /// Acquires a token, awaiting as needed. Polls in small increments based
  /// on the configured rate.
  Future<void> acquire() async {
    while (true) {
      if (_stopped) {
        throw StateError('rate limiter stopped');
      }
      _refill();
      if (_tokens >= 1.0) {
        _tokens -= 1.0;
        return;
      }
      final tokensNeeded = 1.0 - _tokens;
      final waitUs = (1e6 * tokensNeeded / requestsPerSecond).ceil();
      await Future<void>.delayed(Duration(microseconds: waitUs));
    }
  }

  /// Attempts to acquire a token without awaiting. Returns false if no
  /// token is available.
  bool tryAcquire() {
    if (_stopped) return false;
    _refill();
    if (_tokens >= 1.0) {
      _tokens -= 1.0;
      return true;
    }
    return false;
  }

  /// Stops the limiter; subsequent acquires throw and tryAcquire returns
  /// false.
  void stop() => _stopped = true;

  void _refill() {
    if (_stopped) return;
    final now = _now();
    final elapsed = now.difference(_lastRefill);
    if (elapsed.isNegative || elapsed == Duration.zero) return;
    final tokensToAdd = elapsed.inMicroseconds / 1e6 * requestsPerSecond;
    _tokens += tokensToAdd;
    if (_tokens > _capacity) _tokens = _capacity;
    _lastRefill = now;
  }
}
