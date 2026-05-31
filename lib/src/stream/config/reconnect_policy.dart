/// Pure reconnect backoff helpers for stream clients.
///
/// Keeping the policy outside the socket lifecycle makes the first-attempt
/// timing and cap behavior replayable in tests.
library;

import 'stream_config.dart';

/// Returns the delay before a 1-based reconnect [attempt].
///
/// Attempt 1 uses [StreamConfig.reconnectDelay]; later attempts double until
/// [StreamConfig.reconnectMaxDelay] caps the delay.
Duration reconnectDelayForAttempt(StreamConfig config, int attempt) {
  if (attempt < 1) {
    throw RangeError.value(attempt, 'attempt', 'must be >= 1');
  }
  final baseMs = config.reconnectDelay.inMilliseconds;
  final capMs = config.reconnectMaxDelay.inMilliseconds;
  var delayMs = baseMs;
  for (var i = 1; i < attempt; i++) {
    delayMs *= 2;
    if (delayMs >= capMs) return Duration(milliseconds: capMs);
  }
  if (delayMs > capMs) return Duration(milliseconds: capMs);
  return Duration(milliseconds: delayMs);
}
