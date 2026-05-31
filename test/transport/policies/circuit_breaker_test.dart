import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/transport/circuit_breaker.dart';
import 'package:test/test.dart';

import '../shared/transport_test_harness.dart';

void main() {
  group('state transitions', () {
    test('opens after enough failures', () {
      final cb = CircuitBreaker(
        config: const CircuitBreakerConfig(maxFailures: 3),
      );
      expect(cb.state, CircuitState.closed);
      cb
        ..recordResult(StateError('x'))
        ..recordResult(StateError('x'))
        ..recordResult(StateError('x'));
      expect(cb.state, CircuitState.open);
      expect(cb.failures, 3);
    });

    test('blocks requests while open', () {
      final cb = CircuitBreaker(
        config: const CircuitBreakerConfig(maxFailures: 1),
      );
      cb.recordResult(StateError('x'));
      expect(
        () => cb.beforeRequest(),
        throwsA(
          isA<TransportException>().having(
            (e) => e.code,
            'code',
            ErrorCode.circuitOpen,
          ),
        ),
      );
    });

    test('open → half-open after reset timeout', () {
      final clock = FakeClock();
      final cb = CircuitBreaker(
        config: const CircuitBreakerConfig(
          maxFailures: 1,
          resetTimeout: Duration(seconds: 60),
          halfOpenMaxRequests: 2,
        ),
        now: clock.call,
      );
      cb.recordResult(StateError('x'));
      expect(cb.state, CircuitState.open);

      // not yet
      clock.advance(const Duration(seconds: 30));
      expect(() => cb.beforeRequest(), throwsA(isA<TransportException>()));

      // reset timeout elapsed
      clock.advance(const Duration(seconds: 31));
      cb.beforeRequest(); // first half-open probe allowed
      expect(cb.state, CircuitState.halfOpen);
    });

    test('half-open → closed after enough successes', () {
      final clock = FakeClock();
      final cb = CircuitBreaker(
        config: const CircuitBreakerConfig(
          maxFailures: 1,
          resetTimeout: Duration(seconds: 60),
          halfOpenMaxRequests: 2,
        ),
        now: clock.call,
      );
      cb.recordResult(StateError('x'));
      clock.advance(const Duration(seconds: 61));

      cb.beforeRequest();
      cb.recordResult(null);
      cb.beforeRequest();
      cb.recordResult(null);
      expect(cb.state, CircuitState.closed);
      expect(cb.failures, 0);
    });

    test('half-open → open on a single failure', () {
      final clock = FakeClock();
      final cb = CircuitBreaker(
        config: const CircuitBreakerConfig(
          maxFailures: 1,
          resetTimeout: Duration(seconds: 60),
        ),
        now: clock.call,
      );
      cb.recordResult(StateError('x'));
      clock.advance(const Duration(seconds: 61));
      cb.beforeRequest();
      cb.recordResult(StateError('still bad'));
      expect(cb.state, CircuitState.open);
    });

    test('half-open caps probe requests', () {
      final clock = FakeClock();
      final cb = CircuitBreaker(
        config: const CircuitBreakerConfig(
          maxFailures: 1,
          resetTimeout: Duration(seconds: 60),
          halfOpenMaxRequests: 2,
        ),
        now: clock.call,
      );
      cb.recordResult(StateError('x'));
      clock.advance(const Duration(seconds: 61));
      cb.beforeRequest();
      cb.beforeRequest();
      expect(
        () => cb.beforeRequest(),
        throwsA(
          isA<TransportException>().having(
            (e) => e.code,
            'code',
            ErrorCode.rateLimited,
          ),
        ),
      );
    });
  });

  group('protect', () {
    test('records success', () async {
      final cb = CircuitBreaker(
        config: const CircuitBreakerConfig(maxFailures: 2),
      );
      final v = await cb.protect(() async => 42);
      expect(v, 42);
      expect(cb.state, CircuitState.closed);
      expect(cb.failures, 0);
    });

    test('records failure and rethrows', () async {
      final cb = CircuitBreaker(
        config: const CircuitBreakerConfig(maxFailures: 1),
      );
      await expectLater(
        cb.protect<void>(() async => throw StateError('bad')),
        throwsA(isA<StateError>()),
      );
      expect(cb.state, CircuitState.open);
    });

    test('refuses while open', () async {
      final cb = CircuitBreaker(
        config: const CircuitBreakerConfig(maxFailures: 1),
      );
      await expectLater(
        cb.protect<void>(() async => throw StateError('bad')),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        cb.protect<int>(() async => 7),
        throwsA(isA<TransportException>()),
      );
    });
  });

  test('reset returns to closed/zero', () {
    final cb = CircuitBreaker(
      config: const CircuitBreakerConfig(maxFailures: 1),
    );
    cb.recordResult(StateError('x'));
    expect(cb.state, CircuitState.open);
    cb.reset();
    expect(cb.state, CircuitState.closed);
    expect(cb.failures, 0);
  });
}
