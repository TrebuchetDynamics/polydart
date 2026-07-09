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
final class MarketOrderSimulationLevel {
  const MarketOrderSimulationLevel({
    required this.price,
    required this.availableSize,
    required this.filledSize,
    required this.notional,
  });

  final String price;
  final String availableSize;
  final String filledSize;
  final String notional;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'price': price,
    'available_size': availableSize,
    'filled_size': filledSize,
    'notional': notional,
  };
}

@immutable
final class MarketOrderSimulationResult {
  const MarketOrderSimulationResult({
    required this.tokenId,
    required this.market,
    required this.side,
    required this.inputAmount,
    required this.inputAmountType,
    required this.limitPrice,
    required this.complete,
    required this.filledSize,
    required this.notional,
    required this.averagePrice,
    required this.expectedFillPrice,
    required this.bestPrice,
    required this.worstPrice,
    required this.slippage,
    required this.slippageBps,
    required this.unfilledAmount,
    required this.bookHash,
    required this.bookTimestamp,
    required this.levels,
  });

  final String tokenId;
  final String market;
  final Side side;
  final String inputAmount;
  final String inputAmountType;
  final String limitPrice;
  final bool complete;
  final String filledSize;
  final String notional;
  final String averagePrice;
  final String expectedFillPrice;
  final String bestPrice;
  final String worstPrice;
  final String slippage;
  final String slippageBps;
  final String unfilledAmount;
  final String bookHash;
  final String bookTimestamp;
  final List<MarketOrderSimulationLevel> levels;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'token_id': tokenId,
    if (market.isNotEmpty) 'market': market,
    'side': side.label.toLowerCase(),
    'input_amount': inputAmount,
    'input_amount_type': inputAmountType,
    if (limitPrice.isNotEmpty) 'limit_price': limitPrice,
    'complete': complete,
    'filled_size': filledSize,
    'notional': notional,
    if (averagePrice.isNotEmpty) 'average_price': averagePrice,
    if (expectedFillPrice.isNotEmpty) 'expected_fill_price': expectedFillPrice,
    if (bestPrice.isNotEmpty) 'best_price': bestPrice,
    if (worstPrice.isNotEmpty) 'worst_price': worstPrice,
    if (slippage.isNotEmpty) 'slippage': slippage,
    if (slippageBps.isNotEmpty) 'slippage_bps': slippageBps,
    'unfilled_amount': unfilledAmount,
    if (bookHash.isNotEmpty) 'book_hash': bookHash,
    if (bookTimestamp.isNotEmpty) 'book_timestamp': bookTimestamp,
    'levels': levels.map((level) => level.toJson()).toList(),
  };
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

MarketOrderSimulationResult simulateMarketOrderBook({
  required OrderBook book,
  required String tokenId,
  required Side side,
  required String amount,
  String limitPrice = '',
}) {
  final amountValue = parsePositiveMarketOrderAmount(amount);
  final limit = limitPrice.trim().isEmpty
      ? null
      : parsePositiveMarketOrderAmount(limitPrice);
  final levels = _simulationLevels(book: book, side: side);
  final bestPrice = levels.isEmpty ? '' : _fmt(levels.first.price);
  var remaining = amountValue;
  var filledSize = 0.0;
  var notional = 0.0;
  var worstPrice = '';
  final fills = <MarketOrderSimulationLevel>[];
  for (final level in levels) {
    if (limit != null &&
        ((side == Side.buy && level.price > limit) ||
            (side == Side.sell && level.price < limit))) {
      break;
    }
    final fillSize = side == Side.buy
        ? (remaining >= level.size * level.price
              ? level.size
              : remaining / level.price)
        : (remaining < level.size ? remaining : level.size);
    if (fillSize <= 0) continue;
    final fillNotional = fillSize * level.price;
    filledSize += fillSize;
    notional += fillNotional;
    fills.add(
      MarketOrderSimulationLevel(
        price: _fmt(level.price),
        availableSize: _fmt(level.size),
        filledSize: _fmt(fillSize),
        notional: _fmt(fillNotional),
      ),
    );
    worstPrice = _fmt(level.price);
    remaining -= side == Side.buy ? fillNotional : fillSize;
    if (remaining <= 0) {
      remaining = 0;
      break;
    }
  }
  var average = '';
  var slippage = '';
  var slippageBps = '';
  if (filledSize > 0) {
    final avg = notional / filledSize;
    average = _fmt(avg);
    if (levels.isNotEmpty && levels.first.price > 0) {
      final slip = side == Side.buy
          ? avg - levels.first.price
          : levels.first.price - avg;
      slippage = _fmt(slip);
      slippageBps = (slip / levels.first.price * 10000).toStringAsFixed(4);
    }
  }
  return MarketOrderSimulationResult(
    tokenId: book.assetId.isNotEmpty ? book.assetId : tokenId,
    market: book.market,
    side: side,
    inputAmount: _fmt(amountValue),
    inputAmountType: side == Side.buy ? 'usdc' : 'shares',
    limitPrice: limit == null ? '' : _fmt(limit),
    complete: remaining == 0,
    filledSize: _fmt(filledSize),
    notional: _fmt(notional),
    averagePrice: average,
    expectedFillPrice: average,
    bestPrice: bestPrice,
    worstPrice: worstPrice,
    slippage: slippage,
    slippageBps: slippageBps,
    unfilledAmount: _fmt(remaining),
    bookHash: book.hash,
    bookTimestamp: book.timestamp,
    levels: List<MarketOrderSimulationLevel>.unmodifiable(fills),
  );
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

List<_SimulationLevel> _simulationLevels({
  required OrderBook book,
  required Side side,
}) {
  final raw = side == Side.buy ? book.asks : book.bids;
  final out = <_SimulationLevel>[];
  for (final level in raw) {
    final price = double.tryParse(level.price);
    final size = double.tryParse(level.size);
    if (price == null || size == null || price <= 0 || size <= 0) continue;
    out.add(_SimulationLevel(price: price, size: size));
  }
  out.sort(
    (a, b) => side == Side.buy
        ? a.price.compareTo(b.price)
        : b.price.compareTo(a.price),
  );
  return out;
}

String _fmt(double value) {
  if (value == 0) return '0.000000';
  return value.toStringAsFixed(6);
}

@immutable
final class _SimulationLevel {
  const _SimulationLevel({required this.price, required this.size});

  final double price;
  final double size;
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
