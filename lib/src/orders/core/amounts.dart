/// Order amount math.
///
/// Mirrors `ComputeAmounts`, `RoundToTick`, `ValidatePriceAgainstTick`,
/// `BuildSalt`, `DefaultExpiration` from polygolem. Pure compute — no
/// signing, no I/O.
library;

import 'dart:math' show Random;

import '../../errors/errors.dart';
import '../../types/enums.dart';
import '../order_intent.dart';
import 'decimal_math.dart';

/// USDC has 6 decimals on Polygon. Polymarket order amounts are denominated
/// in this fixed-point form (1 USDC = 1_000_000 wei).
const int usdcDecimals = 6;

/// CLOB minimum collateral notional for a marketable BUY (not a share minimum).
const int minimumMarketableBuyAmount = 1;

/// Validates the computed collateral amount without increasing the user's order.
void validateMarketableBuyAmount(BigInt makerAmount) {
  if (makerAmount <
      BigInt.from(minimumMarketableBuyAmount) * pow10(usdcDecimals)) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: r'Minimum marketable buy amount is $1.',
      field: 'amount',
    );
  }
}

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
  final price = intent.price.raw;
  final size = intent.size.raw;
  final sizeAmount = decimalUnitsRoundedAtScale(size, usdcDecimals);
  final notionalAmount = decimalProductUnitsRoundedAtScale(
    size,
    price,
    usdcDecimals,
  );
  if (intent.side == Side.buy) {
    return (makerAmount: notionalAmount, takerAmount: sizeAmount);
  }
  return (makerAmount: sizeAmount, takerAmount: notionalAmount);
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
    validateMarketableBuyAmount(makerAmount);
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

/// Rounds [value] down to the current [tickSize] multiple, matching
/// polygolem's `RoundToTick` integer-quotient behavior. Both inputs are
/// parsed as decimals.
String roundToTick(String value, String tickSize) =>
    roundDecimalDownToTick(value, tickSize);

/// Throws [ValidationException] when [price] is outside `[tickSize, 1 - tickSize]`.
void validatePriceAgainstTick(String price, String tickSize) {
  final p = _parseFiniteDecimal(price, field: 'price');
  final t = _parseFiniteDecimal(tickSize, field: 'tickSize');
  if (t <= 0 || t >= 1) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'tickSize $tickSize must be finite and between 0 and 1',
      field: 'tickSize',
    );
  }
  if (p < t || p > 1 - t) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message:
          'price $price must be within [$t, ${1 - t}] for tick size $tickSize',
      field: 'price',
    );
  }
}

double _parseFiniteDecimal(String raw, {required String field}) {
  final value = double.tryParse(raw);
  if (value == null || !value.isFinite) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: '$field must be a finite decimal',
      field: field,
    );
  }
  return value;
}

/// Builds a deterministic salt from a seed. For tests / replays.
String buildSalt(int seed) => seed.toString();

final Random _rand = Random.secure();
const int _uint32ExclusiveMax = 0x100000000;

/// Generates a cryptographically random salt exactly representable as a JSON
/// number in JavaScript (0 through 2^53 - 1), before the order is signed.
String generateOrderSalt() {
  // Use BigInt for the shift: JavaScript bitwise operations truncate to 32 bits.
  final hi = _rand.nextInt(0x200000);
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
