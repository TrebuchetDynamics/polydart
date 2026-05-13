/// Order amount math.
///
/// Mirrors `ComputeAmounts`, `RoundToTick`, `ValidatePriceAgainstTick`,
/// `BuildSalt`, `DefaultExpiration` from polygolem. Pure compute — no
/// signing, no I/O.
library;

import 'dart:math' show Random;

import '../errors/errors.dart';
import '../types/enums.dart';
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
OrderAmounts computeAmounts(OrderIntent intent) {
  if (intent.amountUsdc != null && !intent.amountUsdc!.isZero) {
    return _computeMarketBuyAmounts(intent);
  }
  final price = intent.price.toDouble();
  final size = intent.size.toDouble();
  if (intent.side == Side.buy) {
    return (makerAmount: _toFixed(size * price), takerAmount: _toFixed(size));
  }
  return (makerAmount: _toFixed(size), takerAmount: _toFixed(size * price));
}

OrderAmounts _computeMarketBuyAmounts(OrderIntent intent) {
  if (intent.side != Side.buy) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'market-order amount is currently supported for BUY only',
    );
  }
  if (intent.price.isZero) {
    throw const ValidationException(
      code: ErrorCode.missingField,
      message: 'price required for market-order amount computation',
      field: 'price',
    );
  }

  final makerCents = _decimalUnitsAtScale(intent.amountUsdc!.raw, 2);
  final makerAmount = makerCents * _pow10(usdcDecimals - 2);
  if (makerAmount <= BigInt.zero) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'amount must be at least 0.01 for market buy orders',
      field: 'amount',
    );
  }

  final price = _decimalRatio(intent.price.raw);
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
  final targetDecimals = _minInt(_decimalsOf(tickRaw) + 2, usdcDecimals);
  final targetScale = _pow10(targetDecimals);
  final fixedScale = _pow10(usdcDecimals);
  final targetTaker =
      (makerAmount * price.denominator * targetScale) ~/
      (fixedScale * price.numerator);
  final takerAmount = targetTaker * _pow10(usdcDecimals - targetDecimals);

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

/// Rounds [value] to the nearest multiple of [tickSize]. Both inputs are
/// parsed as decimals.
String roundToTick(String value, String tickSize) {
  final v = double.parse(value);
  final t = double.parse(tickSize);
  if (t == 0) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'tickSize must be non-zero',
    );
  }
  final rounded = (v / t).round() * t;
  return rounded.toStringAsFixed(_decimalsOf(tickSize));
}

int _decimalsOf(String s) {
  final dot = s.indexOf('.');
  if (dot < 0) return 0;
  return s.substring(dot + 1).replaceFirst(RegExp(r'0+$'), '').length;
}

({BigInt numerator, BigInt denominator}) _decimalRatio(String raw) {
  final value = raw.trim();
  final negative = value.startsWith('-');
  final body = negative ? value.substring(1) : value;
  final dot = body.indexOf('.');
  final whole = dot < 0 ? body : body.substring(0, dot);
  final fractional = dot < 0 ? '' : body.substring(dot + 1);
  final digits = whole + fractional;
  final numerator = BigInt.parse(digits.isEmpty ? '0' : digits);
  final signedNumerator = negative ? -numerator : numerator;
  return (numerator: signedNumerator, denominator: _pow10(fractional.length));
}

BigInt _decimalUnitsAtScale(String raw, int scale) {
  final ratio = _decimalRatio(raw);
  if (ratio.numerator < BigInt.zero) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'amount must be non-negative',
      field: 'amount',
    );
  }
  return (ratio.numerator * _pow10(scale)) ~/ ratio.denominator;
}

BigInt _pow10(int exponent) {
  var out = BigInt.one;
  for (var i = 0; i < exponent; i++) {
    out *= BigInt.from(10);
  }
  return out;
}

int _minInt(int a, int b) => a < b ? a : b;

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

/// Generates a fresh random uint64-style salt suitable for new orders.
String generateOrderSalt() {
  // Two 32-bit halves combined into a 64-bit positive int.
  final hi = _rand.nextInt(1 << 32);
  final lo = _rand.nextInt(1 << 32);
  final combined = (BigInt.from(hi) << 32) | BigInt.from(lo);
  return combined.toString();
}

/// Default expiration: now + 365 days, in Unix seconds.
int defaultExpiration({DateTime Function()? now}) {
  final n = now == null ? DateTime.now() : now();
  return n.add(const Duration(days: 365)).toUtc().millisecondsSinceEpoch ~/
      1000;
}
