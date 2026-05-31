/// Pure market-order price selection from an order-book side.
///
/// Keeps [createMarketOrder] I/O separate from the fill-price decision so
/// malformed books and insufficient-liquidity cases are replayable in tests.
library;

import 'package:meta/meta.dart';

import '../errors/errors.dart';
import '../types/clob.dart';
import '../types/decimal.dart';
import '../types/enums.dart';

@immutable
final class MarketOrderPricePlan {
  const MarketOrderPricePlan({
    required this.price,
    required this.filledAmount,
    required this.requiredAmount,
    required this.levelsConsumed,
    required this.fillsCompletely,
  }) : assert(levelsConsumed > 0),
       assert(filledAmount >= 0),
       assert(requiredAmount > 0);

  /// Limit/fill price selected from the worst consumed opposing book level.
  final String price;

  /// BUY: USDC notional available through consumed asks.
  /// SELL: share size available through consumed bids.
  final double filledAmount;

  final double requiredAmount;
  final int levelsConsumed;
  final bool fillsCompletely;
}

@immutable
final class MarketOrderFillStep {
  const MarketOrderFillStep({
    required this.level,
    required this.fillContribution,
    required this.cumulativeFilled,
  }) : assert(fillContribution > 0),
       assert(cumulativeFilled > 0);

  final OrderBookLevel level;

  /// BUY: USDC notional at this ask level. SELL: share size at this bid level.
  final double fillContribution;
  final double cumulativeFilled;
}

MarketOrderPricePlan selectMarketOrderPrice({
  required List<OrderBookLevel> levels,
  required Side side,
  required double amount,
  required OrderType orderType,
}) {
  validateMarketOrderAmount(amount);

  if (levels.isEmpty) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'no opposing orders',
    );
  }

  final steps = marketOrderFillSteps(levels: levels, side: side);
  for (var i = 0; i < steps.length; i++) {
    final step = steps[i];
    if (step.cumulativeFilled >= amount) {
      return MarketOrderPricePlan(
        price: step.level.price,
        filledAmount: step.cumulativeFilled,
        requiredAmount: amount,
        levelsConsumed: i + 1,
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
  final lastVisibleStep = steps.last;
  return MarketOrderPricePlan(
    price: lastVisibleStep.level.price,
    filledAmount: lastVisibleStep.cumulativeFilled,
    requiredAmount: amount,
    levelsConsumed: steps.length,
    fillsCompletely: false,
  );
}

List<MarketOrderFillStep> marketOrderFillSteps({
  required List<OrderBookLevel> levels,
  required Side side,
}) {
  var filled = 0.0;
  final steps = <MarketOrderFillStep>[];
  for (final level in levels) {
    final price = _parsePositiveLevelValue(level.price, 'book price');
    final size = _parsePositiveLevelValue(level.size, 'book size');
    final contribution = side == Side.buy ? price * size : size;
    filled += contribution;
    steps.add(
      MarketOrderFillStep(
        level: level,
        fillContribution: contribution,
        cumulativeFilled: filled,
      ),
    );
  }
  return steps;
}

double parsePositiveMarketOrderAmount(String amount) {
  final decimal = Decimal.tryParse(amount);
  if (decimal == null) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'amount must be a decimal',
      field: 'amount',
    );
  }
  final value = decimal.toDouble();
  if (!value.isFinite) {
    validateMarketOrderAmount(value);
  }
  if (value <= 0) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'amount must be positive',
      field: 'amount',
    );
  }
  return value;
}

void validateMarketOrderAmount(double amount) {
  if (!amount.isFinite || amount <= 0) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'amount must be finite and positive',
      field: 'amount',
    );
  }
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
