import 'package:polydart/src/transport/rate_limit.dart';
import 'package:test/test.dart';

import '../shared/transport_test_harness.dart';

void main() {
  group('tryAcquire', () {
    test('drains the bucket then refuses', () {
      final clock = FakeClock();
      final rl = RateLimiter(requestsPerSecond: 5, now: clock.call);
      final acquired = drainRateLimiter(rl);
      expect(acquired, 5);
      expect(rl.tryAcquire(), isFalse);
    });

    test('refills tokens proportional to elapsed time', () {
      final clock = FakeClock();
      final rl = RateLimiter(requestsPerSecond: 10, now: clock.call);
      drainRateLimiter(rl);
      // 200 ms passes — that's 2 tokens at 10 req/s.
      clock.advance(const Duration(milliseconds: 200));
      expect(rl.tryAcquire(), isTrue);
      expect(rl.tryAcquire(), isTrue);
      expect(rl.tryAcquire(), isFalse);
    });

    test('cap at capacity', () {
      final clock = FakeClock();
      final rl = RateLimiter(requestsPerSecond: 3, now: clock.call);
      // wait a long time without taking
      clock.advance(const Duration(minutes: 5));
      expect(rl.available, 3);
    });

    test('stop returns false', () {
      final rl = RateLimiter(requestsPerSecond: 5);
      rl.stop();
      expect(rl.tryAcquire(), isFalse);
      expect(rl.isStopped, isTrue);
    });
  });

  group('acquire', () {
    test('immediate when token available', () async {
      final rl = RateLimiter(requestsPerSecond: 5);
      await rl.acquire(); // does not throw / hang
    });

    test('waits when bucket empty', () async {
      final rl = RateLimiter(requestsPerSecond: 50);
      // drain the bucket
      drainRateLimiter(rl);
      final stopwatch = Stopwatch()..start();
      await rl.acquire();
      stopwatch.stop();
      // at 50/s we wait ~20ms for a token
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(10));
    });
  });
}
