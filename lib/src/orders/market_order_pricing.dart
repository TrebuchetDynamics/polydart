/// Pure market-order price selection from an order-book side.
///
/// Keeps [createMarketOrder] I/O separate from the fill-price decision so
/// malformed books and insufficient-liquidity cases are replayable in tests.
library;

import 'package:meta/meta.dart';

import '../errors/errors.dart';
import '../types/clob.dart';
import '../types/enums.dart';

@immutable
final class MarketOrderPricePlan {
  const MarketOrderPricePlan({
    required this.price,
    required this.filledAmount,
    required this.requiredAmount,
    required this.levelsConsumed,
    required this.fillsCompletely,
  });

  /// Limit/fill price selected from the opposing book side.
  final String price;

  /// BUY: USDC notional available through consumed asks.
  /// SELL: share size available through consumed bids.
  final double filledAmount;

  final double requiredAmount;
  final int levelsConsumed;
  final bool fillsCompletely;
}

MarketOrderPricePlan selectMarketOrderPrice({
  required List<OrderBookLevel> levels,
  required Side side,
  required double amount,
  required OrderType orderType,
}) {
  if (levels.isEmpty) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'no opposing orders',
    );
  }

  var filled = 0.0;
  var levelsConsumed = 0;
  for (final level in levels) {
    levelsConsumed++;
    final price = _parsePositiveLevelValue(level.price, 'book price');
    final size = _parsePositiveLevelValue(level.size, 'book size');
    filled += side == Side.buy ? price * size : size;
    if (filled >= amount) {
      return MarketOrderPricePlan(
        price: level.price,
        filledAmount: filled,
        requiredAmount: amount,
        levelsConsumed: levelsConsumed,
        fillsCompletely: true,
      );
    }
  }

  if (orderType == OrderType.fok) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'insufficient liquidity to fill order',
    );
  }
  return MarketOrderPricePlan(
    price: levels.first.price,
    filledAmount: filled,
    requiredAmount: amount,
    levelsConsumed: levelsConsumed,
    fillsCompletely: false,
  );
}

double _parsePositiveLevelValue(String raw, String field) {
  final value = double.tryParse(raw);
  if (value == null || !value.isFinite || value <= 0) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: '$field must be a finite positive decimal',
      field: field,
    );
  }
  return value;
}
