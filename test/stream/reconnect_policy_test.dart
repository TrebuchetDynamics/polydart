import 'package:polydart/src/stream/config/stream_config.dart';
import 'package:polydart/src/stream/config/reconnect_policy.dart';
import 'package:test/test.dart';

void main() {
  group('reconnectDelayForAttempt', () {
    test('uses the configured initial delay for the first reconnect', () {
      final config = StreamConfig.defaults();

      expect(reconnectDelayForAttempt(config, 1), config.reconnectDelay);
    });

    test('doubles subsequent attempts until capped', () {
      const config = StreamConfig(
        url: defaultStreamUrl,
        reconnectDelay: Duration(seconds: 2),
        reconnectMaxDelay: Duration(seconds: 5),
      );

      expect(reconnectDelayForAttempt(config, 1), const Duration(seconds: 2));
      expect(reconnectDelayForAttempt(config, 2), const Duration(seconds: 4));
      expect(reconnectDelayForAttempt(config, 3), const Duration(seconds: 5));
      expect(reconnectDelayForAttempt(config, 4), const Duration(seconds: 5));
    });

    test('rejects zero-based attempt numbers', () {
      expect(
        () => reconnectDelayForAttempt(StreamConfig.defaults(), 0),
        throwsRangeError,
      );
    });
  });
}
