import 'package:polydart/src/risk/breaker.dart';
import 'package:test/test.dart';

void main() {
  group('trip reasons', () {
    test('map to Polygolem strings', () {
      expect(TripReason.consecutiveErrors.value, 'consecutive_errors');
      expect(TripReason.dailyLossLimit.value, 'daily_loss_limit');
      expect(TripReason.positionPerMarket.value, 'position_per_market');
      expect(TripReason.totalPosition.value, 'total_position');
      expect(TripReason.manualHalt.value, 'manual_halt');
      expect(tripReasonFromString('manual_halt'), TripReason.manualHalt);
      expect(tripReasonFromString('nope'), isNull);
    });
  });

  group('policy', () {
    test('defaultPolicy returns conservative defaults', () {
      final policy = defaultPolicy();

      expect(policy.maxOrderUsd, 10.0);
      expect(policy.maxOpenOrders, 5);
      expect(policy.dailyLossLimitUsd, 100.0);
      expect(policy.dailyPnlResetHour, 0);
      expect(policy.maxConsecutiveErrors, 5);
      expect(policy.cooldownSecs, 300);
      expect(policy.maxPositionPerMarket, 50.0);
      expect(policy.maxTotalPosition, 200.0);
    });
  });

  group('breaker', () {
    test('starts closed', () {
      final breaker = Breaker();

      expect(breaker.canProceed(), isTrue);
      expect(breaker.halted(), isFalse);
    });

    test('opens on consecutive errors and records reason', () {
      final breaker = Breaker(
        policy: defaultPolicy().copyWith(maxConsecutiveErrors: 3),
      );

      expect(breaker.recordError(), isFalse);
      expect(breaker.recordError(), isFalse);
      expect(breaker.recordError(), isTrue);

      expect(breaker.canProceed(), isFalse);
      final status = breaker.status();
      expect(status.halted, isTrue);
      expect(status.tripReason, TripReason.consecutiveErrors);
      expect(status.tripReasonMessage, 'consecutive_errors');
      expect(status.consecutiveErrors, 3);
    });

    test('recordSuccess clears consecutive errors', () {
      final breaker = Breaker(
        policy: defaultPolicy().copyWith(maxConsecutiveErrors: 5),
      );

      for (var i = 0; i < 4; i++) {
        breaker.recordError();
      }
      breaker.recordSuccess();
      for (var i = 0; i < 4; i++) {
        breaker.recordError();
      }

      expect(breaker.canProceed(), isTrue);
      expect(breaker.status().consecutiveErrors, 4);
    });

    test('daily loss limit halts trading and records reason', () {
      final breaker = Breaker(
        policy: defaultPolicy().copyWith(dailyLossLimitUsd: 50),
      );

      expect(breaker.recordLoss(60), isTrue);
      expect(breaker.canProceed(), isFalse);
      expect(breaker.status().tripReason, TripReason.dailyLossLimit);
      expect(breaker.status().dailyLossUsd, 60);
    });

    test('cooldown zero requires explicit reset', () {
      final breaker = Breaker(
        policy: defaultPolicy().copyWith(
          maxConsecutiveErrors: 1,
          cooldownSecs: 0,
        ),
      );

      breaker.recordError();
      expect(breaker.canProceed(), isFalse);

      breaker.reset();
      expect(breaker.canProceed(), isTrue);
    });

    test('cooldown reopens automatically after elapsed time', () {
      var now = DateTime.utc(2026);
      final breaker = Breaker(
        policy: defaultPolicy().copyWith(
          maxConsecutiveErrors: 1,
          cooldownSecs: 300,
        ),
        now: () => now,
      );

      breaker.recordError();
      now = now.add(const Duration(seconds: 300));
      expect(breaker.status().cooldownReady, isFalse);
      expect(breaker.canProceed(), isFalse);

      now = now.add(const Duration(seconds: 1));
      expect(breaker.status().cooldownReady, isTrue);
      expect(breaker.canProceed(), isTrue);
      expect(breaker.status().halted, isFalse);
      expect(breaker.status().consecutiveErrors, 0);
    });

    test('halt records manual halt reason', () {
      final breaker = Breaker();

      breaker.halt();

      expect(breaker.halted(), isTrue);
      expect(breaker.status().tripReason, TripReason.manualHalt);
    });

    test('status includes positions and absolute total', () {
      final breaker = Breaker();

      breaker.recordPosition('token1', 5);
      breaker.recordPosition('token2', -3);

      final status = breaker.status();
      expect(status.positions, {'token1': 5.0, 'token2': -3.0});
      expect(status.totalPositionUsd, 8.0);
    });

    test('position per market limit halts trading', () {
      final breaker = Breaker(
        policy: defaultPolicy().copyWith(maxPositionPerMarket: 10),
      );

      expect(breaker.recordPosition('token1', 15), isTrue);
      expect(breaker.canProceed(), isFalse);
      expect(breaker.status().tripReason, TripReason.positionPerMarket);
    });

    test('total position limit halts trading', () {
      final breaker = Breaker(
        policy: defaultPolicy().copyWith(maxTotalPosition: 10),
      );

      expect(breaker.recordPosition('token1', 6), isFalse);
      expect(breaker.recordPosition('token2', 6), isTrue);
      expect(breaker.canProceed(), isFalse);
      expect(breaker.status().tripReason, TripReason.totalPosition);
    });

    test('daily loss resets at configured UTC hour', () {
      var now = DateTime.utc(2026, 1, 1, 23);
      final breaker = Breaker(
        policy: defaultPolicy().copyWith(
          dailyLossLimitUsd: 100,
          dailyPnlResetHour: 2,
        ),
        now: () => now,
      );

      breaker.recordLoss(50);
      expect(breaker.status().dailyLossUsd, 50);

      now = DateTime.utc(2026, 1, 2, 1);
      expect(breaker.canProceed(), isTrue);
      expect(breaker.status().dailyLossUsd, 50);

      now = DateTime.utc(2026, 1, 2, 2);
      expect(breaker.canProceed(), isTrue);
      expect(breaker.status().dailyLossUsd, 0);
    });

    test('reset clears breaker state', () {
      final breaker = Breaker(
        policy: defaultPolicy().copyWith(maxConsecutiveErrors: 1),
      );

      breaker.recordError();
      breaker.recordLoss(20);
      breaker.recordPosition('token1', 10);
      breaker.reset();

      final status = breaker.status();
      expect(status.halted, isFalse);
      expect(status.tripReason, isNull);
      expect(status.consecutiveErrors, 0);
      expect(status.dailyLossUsd, 0);
      expect(status.positions, isEmpty);
      expect(status.totalPositionUsd, 0);
    });
  });
}
