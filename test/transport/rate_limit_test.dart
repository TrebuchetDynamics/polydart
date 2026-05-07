import 'package:polydart/src/transport/rate_limit.dart';
import 'package:test/test.dart';

void main() {
  group('tryAcquire', () {
    test('drains the bucket then refuses', () {
      // ignore: prefer_final_locals — clock is rebound in some tests
      var clock = DateTime(2026, 1, 1);
      final rl = RateLimiter(requestsPerSecond: 5, now: () => clock);
      var acquired = 0;
      while (rl.tryAcquire()) {
        acquired++;
      }
      expect(acquired, 5);
      expect(rl.tryAcquire(), isFalse);
    });

    test('refills tokens proportional to elapsed time', () {
      var clock = DateTime(2026, 1, 1);
      final rl = RateLimiter(requestsPerSecond: 10, now: () => clock);
      while (rl.tryAcquire()) {}
      // 200 ms passes — that's 2 tokens at 10 req/s.
      clock = clock.add(const Duration(milliseconds: 200));
      expect(rl.tryAcquire(), isTrue);
      expect(rl.tryAcquire(), isTrue);
      expect(rl.tryAcquire(), isFalse);
    });

    test('cap at capacity', () {
      var clock = DateTime(2026, 1, 1);
      final rl = RateLimiter(requestsPerSecond: 3, now: () => clock);
      // wait a long time without taking
      clock = clock.add(const Duration(minutes: 5));
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
      while (rl.tryAcquire()) {}
      final stopwatch = Stopwatch()..start();
      await rl.acquire();
      stopwatch.stop();
      // at 50/s we wait ~20ms for a token
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(10));
    });
  });
}
