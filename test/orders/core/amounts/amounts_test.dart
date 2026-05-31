import 'package:polydart/src/orders/amounts.dart';
import 'package:polydart/src/orders/order_builder.dart';
import 'package:polydart/src/types/enums.dart';
import 'package:test/test.dart';

import '../support/core_order_test_support.dart';

void main() {
  group('computeAmounts (1e6 USDC fixed-point)', () {
    test('BUY: maker = size*price, taker = size', () {
      final intent = OrderBuilder(
        tokenId: 'tok-1',
        side: Side.buy,
      ).price('0.55').size('10').tickSize('0.01').build();
      final amts = computeAmounts(intent);
      // 10 * 0.55 = 5.5 USDC = 5_500_000 micro-USDC
      expect(amts.makerAmount, BigInt.from(5500000));
      // 10 tokens = 10_000_000 micro-USDC
      expect(amts.takerAmount, BigInt.from(10000000));
    });

    test('SELL: maker = size, taker = size*price', () {
      final intent = OrderBuilder(
        tokenId: 'tok-1',
        side: Side.sell,
      ).price('0.45').size('5').tickSize('0.01').build();
      final amts = computeAmounts(intent);
      expect(amts.makerAmount, BigInt.from(5000000));
      // 5 * 0.45 = 2.25 USDC = 2_250_000 micro-USDC
      expect(amts.takerAmount, BigInt.from(2250000));
    });

    test('market BUY truncates USDC budget and taker size like polygolem', () {
      final intent = OrderBuilder(
        tokenId: 'tok-1',
        side: Side.buy,
      ).price('0.120000').amountUsdc('1.011700').tickSize('0.01').build();
      final amts = computeAmounts(intent);

      expect(amts.makerAmount, BigInt.from(1010000));
      expect(amts.takerAmount, BigInt.from(8416600));
    });
  });

  group('roundToTick', () {
    test('floors to the current tick like polygolem', () {
      expect(roundToTick('0.553', '0.01'), '0.55');
      expect(roundToTick('0.555', '0.01'), '0.55');
      expect(roundToTick('0.559', '0.01'), '0.55');
      expect(roundToTick('0.560', '0.01'), '0.56');
    });

    test('preserves precision of tickSize', () {
      expect(roundToTick('0.1234', '0.001'), '0.123');
    });

    test('does not drop exact tick multiples due to floating point drift', () {
      expect(roundToTick('0.29', '0.01'), '0.29');
      expect(roundToTick('0.57', '0.01'), '0.57');
      expect(roundToTick('0.58', '0.01'), '0.58');
    });

    test('rejects non-positive tick', () {
      expect(() => roundToTick('0.5', '0'), throwsValidationException);
      expect(() => roundToTick('0.5', '-0.01'), throwsValidationException);
    });
  });

  group('validatePriceAgainstTick', () {
    test('accepts in-range', () {
      validatePriceAgainstTick('0.55', '0.01');
      validatePriceAgainstTick('0.99', '0.01');
    });

    test('rejects below tick', () {
      expect(
        () => validatePriceAgainstTick('0.005', '0.01'),
        throwsValidationException,
      );
    });

    test('rejects above 1-tick', () {
      expect(
        () => validatePriceAgainstTick('0.995', '0.01'),
        throwsValidationException,
      );
    });

    test('rejects non-finite price and non-positive tick', () {
      expect(
        () => validatePriceAgainstTick('NaN', '0.01'),
        throwsValidationException,
      );
      expect(
        () => validatePriceAgainstTick('0.50', 'NaN'),
        throwsValidationException,
      );
      expect(
        () => validatePriceAgainstTick('0.50', '0'),
        throwsValidationException,
      );
      expect(
        () => validatePriceAgainstTick('0.50', '-0.01'),
        throwsValidationException,
      );
    });
  });

  group('salts', () {
    test('buildSalt is deterministic', () {
      expect(buildSalt(42), '42');
      expect(buildSalt(0), '0');
    });

    test('generateOrderSalt is unique across calls', () {
      final salts = <String>{for (var i = 0; i < 50; i++) generateOrderSalt()};
      expect(salts.length, greaterThan(40));
    });
  });

  test('defaultExpiration is now + 365 days', () {
    final epoch = DateTime.utc(2026, 1, 1);
    final exp = defaultExpiration(now: () => epoch);
    final expected =
        epoch.add(const Duration(days: 365)).millisecondsSinceEpoch ~/ 1000;
    expect(exp, expected);
  });
}
