import 'package:polydart/src/transport/rate_limit.dart';

final class FakeClock {
  FakeClock([DateTime? initial]) : value = initial ?? DateTime(2026, 1, 1);

  DateTime value;

  DateTime call() => value;

  void advance(Duration duration) {
    value = value.add(duration);
  }
}

int drainRateLimiter(RateLimiter limiter) {
  var acquired = 0;
  while (limiter.tryAcquire()) {
    acquired++;
  }
  return acquired;
}
