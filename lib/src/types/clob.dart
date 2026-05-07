/// CLOB API data types.
///
/// Mirrors the read-side of `internal/polytypes/clob.go`. Write-side request
/// shapes (orders, cancels) land in Phase 2.
library;

import 'package:meta/meta.dart';

import 'numeric_string.dart';

@immutable
final class OrderBookLevel {
  const OrderBookLevel({required this.price, required this.size});

  factory OrderBookLevel.fromJson(Map<String, dynamic> json) => OrderBookLevel(
    price: parseNumericString(json['price']),
    size: parseNumericString(json['size']),
  );

  final String price;
  final String size;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'price': price,
    'size': size,
  };

  @override
  bool operator ==(Object other) =>
      other is OrderBookLevel && other.price == price && other.size == size;

  @override
  int get hashCode => Object.hash(price, size);
}

@immutable
final class OrderBook {
  const OrderBook({
    required this.market,
    required this.assetId,
    required this.timestamp,
    required this.hash,
    required this.bids,
    required this.asks,
  });

  factory OrderBook.fromJson(Map<String, dynamic> json) => OrderBook(
    market: json['market']?.toString() ?? '',
    assetId: json['asset_id']?.toString() ?? '',
    timestamp: json['timestamp']?.toString() ?? '',
    hash: json['hash']?.toString() ?? '',
    bids: _levels(json['bids']),
    asks: _levels(json['asks']),
  );

  final String market;
  final String assetId;
  final String timestamp;
  final String hash;
  final List<OrderBookLevel> bids;
  final List<OrderBookLevel> asks;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'market': market,
    'asset_id': assetId,
    'timestamp': timestamp,
    'hash': hash,
    'bids': bids.map((l) => l.toJson()).toList(),
    'asks': asks.map((l) => l.toJson()).toList(),
  };
}

List<OrderBookLevel> _levels(Object? raw) {
  if (raw is! List) return const <OrderBookLevel>[];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => OrderBookLevel.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);
}

@immutable
final class TickSize {
  const TickSize({
    required this.minimumTickSize,
    required this.minimumOrderSize,
    required this.tickSize,
  });

  factory TickSize.fromJson(Map<String, dynamic> json) => TickSize(
    minimumTickSize: json['minimum_tick_size']?.toString() ?? '',
    minimumOrderSize: json['minimum_order_size']?.toString() ?? '',
    tickSize: json['tick_size']?.toString() ?? '',
  );

  final String minimumTickSize;
  final String minimumOrderSize;
  final String tickSize;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'minimum_tick_size': minimumTickSize,
    'minimum_order_size': minimumOrderSize,
    'tick_size': tickSize,
  };
}

@immutable
final class Token {
  const Token({
    required this.tokenId,
    required this.outcome,
    required this.price,
    required this.winner,
  });

  factory Token.fromJson(Map<String, dynamic> json) => Token(
    tokenId: json['token_id']?.toString() ?? '',
    outcome: json['outcome']?.toString() ?? '',
    price: parseNumericString(json['price']),
    winner: json['winner'] == true,
  );

  final String tokenId;
  final String outcome;
  final String price;
  final bool winner;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'token_id': tokenId,
    'outcome': outcome,
    'price': price,
    'winner': winner,
  };
}

/// CLOB market metadata. Subset of `polytypes.CLOBMarket` for v0.1.
@immutable
final class ClobMarket {
  const ClobMarket({
    required this.conditionId,
    required this.questionId,
    required this.tokens,
    required this.spread,
    required this.enableOrderBook,
    required this.acceptingOrders,
    required this.closed,
    required this.archived,
    required this.negRisk,
    required this.orderMinSize,
    required this.orderPriceMinTickSize,
  });

  factory ClobMarket.fromJson(Map<String, dynamic> json) {
    final rawTokens = json['tokens'];
    final tokens = (rawTokens is List)
        ? rawTokens
              .whereType<Map<dynamic, dynamic>>()
              .map((m) => Token.fromJson(m.cast<String, dynamic>()))
              .toList(growable: false)
        : const <Token>[];
    return ClobMarket(
      conditionId: json['condition_id']?.toString() ?? '',
      questionId: json['question_id']?.toString() ?? '',
      tokens: tokens,
      spread: _double(json['spread']),
      enableOrderBook: json['enable_order_book'] == true,
      acceptingOrders: json['accepting_orders'] == true,
      closed: json['closed'] == true,
      archived: json['archived'] == true,
      negRisk: json['neg_risk'] == true,
      orderMinSize: _double(json['order_min_size']),
      orderPriceMinTickSize: _double(json['order_price_min_tick_size']),
    );
  }

  final String conditionId;
  final String questionId;
  final List<Token> tokens;
  final double spread;
  final bool enableOrderBook;
  final bool acceptingOrders;
  final bool closed;
  final bool archived;
  final bool negRisk;
  final double orderMinSize;
  final double orderPriceMinTickSize;
}

@immutable
final class ClobPaginatedMarkets {
  const ClobPaginatedMarkets({
    required this.limit,
    required this.count,
    required this.nextCursor,
    required this.data,
  });

  factory ClobPaginatedMarkets.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    final data = (raw is List)
        ? raw
              .whereType<Map<dynamic, dynamic>>()
              .map((m) => ClobMarket.fromJson(m.cast<String, dynamic>()))
              .toList(growable: false)
        : const <ClobMarket>[];
    return ClobPaginatedMarkets(
      limit: _int(json['limit']),
      count: _int(json['count']),
      nextCursor: json['next_cursor']?.toString() ?? '',
      data: data,
    );
  }

  final int limit;
  final int count;
  final String nextCursor;
  final List<ClobMarket> data;
}

@immutable
final class MidpointResponse {
  const MidpointResponse({required this.midpoint});

  factory MidpointResponse.fromJson(Map<String, dynamic> json) =>
      MidpointResponse(midpoint: parseNumericString(json['mid']));

  final String midpoint;
}

@immutable
final class PriceResponse {
  const PriceResponse({required this.price, required this.spread});

  factory PriceResponse.fromJson(Map<String, dynamic> json) => PriceResponse(
    price: parseNumericString(json['price']),
    spread: parseNumericString(json['spread']),
  );

  final String price;
  final String spread;
}

@immutable
final class ServerTime {
  const ServerTime({required this.timestamp, required this.iso});

  factory ServerTime.fromJson(Map<String, dynamic> json) => ServerTime(
    timestamp: json['timestamp']?.toString() ?? '',
    iso: json['iso']?.toString() ?? '',
  );

  final String timestamp;
  final String iso;
}

@immutable
final class PricePoint {
  const PricePoint({
    required this.timestamp,
    required this.price,
    this.volume = '',
    this.interval = '',
  });

  factory PricePoint.fromJson(Map<String, dynamic> json) => PricePoint(
    timestamp: json['t']?.toString() ?? '',
    price: parseNumericString(json['p']),
    volume: parseNumericString(json['v']),
    interval: json['interval']?.toString() ?? '',
  );

  final String timestamp;
  final String price;
  final String volume;
  final String interval;
}

@immutable
final class PriceHistory {
  const PriceHistory({required this.history});

  factory PriceHistory.fromJson(Map<String, dynamic> json) {
    final raw = json['history'];
    final out = (raw is List)
        ? raw
              .whereType<Map<dynamic, dynamic>>()
              .map((m) => PricePoint.fromJson(m.cast<String, dynamic>()))
              .toList(growable: false)
        : const <PricePoint>[];
    return PriceHistory(history: out);
  }

  final List<PricePoint> history;
}

double _double(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw) ?? 0;
  return 0;
}

int _int(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? 0;
  return 0;
}
