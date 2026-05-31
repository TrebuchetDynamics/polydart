/// Order amount math.
///
/// Mirrors `ComputeAmounts`, `RoundToTick`, `ValidatePriceAgainstTick`,
/// `BuildSalt`, `DefaultExpiration` from polygolem. Pure compute — no
/// signing, no I/O.
library;

import 'dart:math' show Random;

import '../errors/errors.dart';
import '../types/enums.dart';
import 'core/decimal_math.dart';
import 'order_intent.dart';

/// USDC has 6 decimals on Polygon. Polymarket order amounts are denominated
/// in this fixed-point form (1 USDC = 1_000_000 wei).
const int usdcDecimals = 6;
const int _usdcScale = 1000000;

/// Pair of (makerAmount, takerAmount) for an order, in canonical USDC
/// fixed-point (BigInt, in 1e6 units).
typedef OrderAmounts = ({BigInt makerAmount, BigInt takerAmount});

/// Computes maker and taker amounts in 1e6 USDC fixed-point.
///
/// BUY:  maker = size * price * 1e6 (USDC out), taker = size * 1e6 (tokens in)
/// SELL: maker = size * 1e6           (tokens out), taker = size * price * 1e6 (USDC in)
///
/// For market orders, [OrderIntent.amountUsdc] is side-dependent for parity
/// with Polygolem/Polymarket: BUY uses a USDC budget; SELL uses share size.
OrderAmounts computeAmounts(OrderIntent intent) {
  if (intent.amountUsdc != null && !intent.amountUsdc!.isZero) {
    return _computeMarketAmounts(intent);
  }
  final price = intent.price.toDouble();
  final size = intent.size.toDouble();
  if (intent.side == Side.buy) {
    return (makerAmount: _toFixed(size * price), takerAmount: _toFixed(size));
  }
  return (makerAmount: _toFixed(size), takerAmount: _toFixed(size * price));
}

OrderAmounts _computeMarketAmounts(OrderIntent intent) {
  if (intent.price.isZero) {
    throw const ValidationException(
      code: ErrorCode.missingField,
      message: 'price required for market-order amount computation',
      field: 'price',
    );
  }

  final price = decimalRatio(intent.price.raw);
  if (price.numerator <= BigInt.zero) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'price must be positive',
      field: 'price',
    );
  }

  final tickRaw = intent.tickSize.tickSize.isNotEmpty
      ? intent.tickSize.tickSize
      : intent.tickSize.minimumTickSize;
  final targetDecimals = minInt(decimalsOf(tickRaw) + 2, usdcDecimals);
  final targetScale = pow10(targetDecimals);
  final fixedScale = pow10(usdcDecimals);

  if (intent.side == Side.buy) {
    final makerCents = decimalUnitsAtScale(intent.amountUsdc!.raw, 2);
    final makerAmount = makerCents * pow10(usdcDecimals - 2);
    if (makerAmount <= BigInt.zero) {
      throw const ValidationException(
        code: ErrorCode.invalidValue,
        message: 'amount must be at least 0.01 for market buy orders',
        field: 'amount',
      );
    }
    final targetTaker =
        (makerAmount * price.denominator * targetScale) ~/
        (fixedScale * price.numerator);
    final takerAmount = targetTaker * pow10(usdcDecimals - targetDecimals);
    return (makerAmount: makerAmount, takerAmount: takerAmount);
  }

  final makerUnits = decimalUnitsAtScale(
    intent.amountUsdc!.raw,
    targetDecimals,
  );
  final makerAmount = makerUnits * pow10(usdcDecimals - targetDecimals);
  if (makerAmount <= BigInt.zero) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'amount must be at least the market sell precision',
      field: 'amount',
    );
  }
  final takerCents =
      (makerAmount * price.numerator * pow10(2)) ~/
      (fixedScale * price.denominator);
  final takerAmount = takerCents * pow10(usdcDecimals - 2);
  return (makerAmount: makerAmount, takerAmount: takerAmount);
}

BigInt _toFixed(double value) {
  if (value.isNaN || value.isInfinite || value < 0) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'amount must be a finite non-negative number',
    );
  }
  return BigInt.from((value * _usdcScale).round());
}

/// Rounds [value] down to the current [tickSize] multiple, matching
/// polygolem's `RoundToTick` integer-quotient behavior. Both inputs are
/// parsed as decimals.
String roundToTick(String value, String tickSize) =>
    roundDecimalDownToTick(value, tickSize);

/// Throws [ValidationException] when [price] is outside `[tickSize, 1 - tickSize]`.
void validatePriceAgainstTick(String price, String tickSize) {
  final p = double.parse(price);
  final t = double.parse(tickSize);
  if (p < t || p > 1 - t) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message:
          'price $price must be within [$t, ${1 - t}] for tick size $tickSize',
    );
  }
}

/// Builds a deterministic salt from a seed. For tests / replays.
String buildSalt(int seed) => seed.toString();

final Random _rand = Random.secure();
const int _uint32ExclusiveMax = 0x100000000;

/// Generates a fresh random uint64-style salt suitable for new orders.
String generateOrderSalt() {
  // Two 32-bit halves combined into a 64-bit positive int.
  final hi = _rand.nextInt(_uint32ExclusiveMax);
  final lo = _rand.nextInt(_uint32ExclusiveMax);
  final combined = (BigInt.from(hi) << 32) | BigInt.from(lo);
  return combined.toString();
}

/// Default expiration: now + 365 days, in Unix seconds.
int defaultExpiration({DateTime Function()? now}) {
  final n = now == null ? DateTime.now() : now();
  return n.add(const Duration(days: 365)).toUtc().millisecondsSinceEpoch ~/
      1000;
}
