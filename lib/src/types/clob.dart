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
    this.minOrderSize = '',
    this.tickSize = '',
    this.negRisk = false,
    this.lastTradePrice = '',
  });

  factory OrderBook.fromJson(Map<String, dynamic> json) => OrderBook(
    market: json['market']?.toString() ?? '',
    assetId: _stringOf(json, const ['asset_id', 'assetId']),
    timestamp: json['timestamp']?.toString() ?? '',
    hash: json['hash']?.toString() ?? '',
    bids: _levels(json['bids']),
    asks: _levels(json['asks']),
    minOrderSize: _stringOf(json, const ['min_order_size', 'minOrderSize']),
    tickSize: _stringOf(json, const ['tick_size', 'tickSize']),
    negRisk: _bool(_firstOf(json, const ['neg_risk', 'negRisk'])),
    lastTradePrice: _stringOf(json, const [
      'last_trade_price',
      'lastTradePrice',
    ]),
  );

  final String market;
  final String assetId;
  final String timestamp;
  final String hash;
  final List<OrderBookLevel> bids;
  final List<OrderBookLevel> asks;
  final String minOrderSize;
  final String tickSize;
  final bool negRisk;
  final String lastTradePrice;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'market': market,
    'asset_id': assetId,
    'timestamp': timestamp,
    'hash': hash,
    'bids': bids.map((l) => l.toJson()).toList(),
    'asks': asks.map((l) => l.toJson()).toList(),
    if (minOrderSize.isNotEmpty) 'min_order_size': minOrderSize,
    if (tickSize.isNotEmpty) 'tick_size': tickSize,
    if (negRisk) 'neg_risk': negRisk,
    if (lastTradePrice.isNotEmpty) 'last_trade_price': lastTradePrice,
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
final class NegRiskInfo {
  const NegRiskInfo({
    required this.negRisk,
    this.negRiskMarketId = '',
    this.negRiskFeeBips = 0,
  });

  factory NegRiskInfo.fromJson(Map<String, dynamic> json) => NegRiskInfo(
    negRisk: _bool(_firstOf(json, const ['neg_risk', 'negRisk'])),
    negRiskMarketId: _stringOf(json, const [
      'neg_risk_market_id',
      'negRiskMarketID',
    ]),
    negRiskFeeBips: _int(
      _firstOf(json, const ['neg_risk_fee_bips', 'negRiskFeeBips']),
    ),
  );

  final bool negRisk;
  final String negRiskMarketId;
  final int negRiskFeeBips;
}

@immutable
final class TickSize {
  const TickSize({
    required this.minimumTickSize,
    required this.minimumOrderSize,
    required this.tickSize,
  });

  factory TickSize.fromJson(Map<String, dynamic> json) => TickSize(
    minimumTickSize: _stringOf(json, const [
      'minimum_tick_size',
      'minimumTickSize',
    ]),
    minimumOrderSize: _stringOf(json, const [
      'minimum_order_size',
      'minimumOrderSize',
    ]),
    tickSize: _stringOf(json, const ['tick_size', 'tickSize']),
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
    tokenId: _string(json, 'token_id', 't'),
    outcome: _string(json, 'outcome', 'o'),
    price: parseNumericString(_first(json, 'price', 'p')),
    winner: _bool(_first(json, 'winner', 'w')),
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
    this.gameStartTime = '',
    required this.spread,
    required this.enableOrderBook,
    required this.acceptingOrders,
    required this.closed,
    required this.archived,
    required this.negRisk,
    this.negRiskMarketId = '',
    this.negRiskRequestId = '',
    this.notificationsEnabled = false,
    required this.orderMinSize,
    required this.orderPriceMinTickSize,
    this.rewardsMinSize = 0,
    this.rewardsMaxSpread = 0,
    this.makerBaseFee = 0,
    this.takerBaseFee = 0,
    this.rfqEnabled = false,
    this.takerOrderDelay = false,
    this.blockaidCheckEnabled = false,
    this.minimumOrderAge = 0,
    this.feeDetails = const ClobFeeDetails(),
  });

  factory ClobMarket.fromJson(Map<String, dynamic> json) {
    final rawTokens = _first(json, 'tokens', 't');
    final rewards = _map(json['r']);
    final tokens = (rawTokens is List)
        ? rawTokens
              .whereType<Map<dynamic, dynamic>>()
              .map((m) => Token.fromJson(m.cast<String, dynamic>()))
              .toList(growable: false)
        : const <Token>[];
    return ClobMarket(
      conditionId: _string(json, 'condition_id', 'c'),
      questionId: _string(json, 'question_id', 'q'),
      tokens: tokens,
      gameStartTime: _string(json, 'game_start_time', 'gst'),
      spread: _double(json['spread']),
      enableOrderBook: _bool(_first(json, 'enable_order_book', 'cbos')),
      acceptingOrders: _bool(_first(json, 'accepting_orders', 'ao')),
      closed: json['closed'] == true,
      archived: json['archived'] == true,
      negRisk: _bool(_first(json, 'neg_risk', 'nr')),
      negRiskMarketId: json['neg_risk_market_id']?.toString() ?? '',
      negRiskRequestId: json['neg_risk_request_id']?.toString() ?? '',
      notificationsEnabled: json['notifications_enabled'] == true,
      orderMinSize: _double(_first(json, 'order_min_size', 'mos')),
      orderPriceMinTickSize: _double(
        _first(json, 'order_price_min_tick_size', 'mts'),
      ),
      rewardsMinSize: _double(_firstMap(rewards, 'rewards_min_size', 'mi')),
      rewardsMaxSpread: _double(_firstMap(rewards, 'rewards_max_spread', 'ma')),
      makerBaseFee: _int(_first(json, 'maker_base_fee', 'mbf')),
      takerBaseFee: _int(_first(json, 'taker_base_fee', 'tbf')),
      rfqEnabled: _bool(_first(json, 'rfq_enabled', 'rfqe')),
      takerOrderDelay: _bool(_first(json, 'taker_order_delay', 'itode')),
      blockaidCheckEnabled: _bool(
        _first(json, 'blockaid_check_enabled', 'ibce'),
      ),
      minimumOrderAge: _int(
        _first(json, 'minimum_order_age', 'oas') ??
            _firstMap(rewards, 'minimum_order_age', 'moas'),
      ),
      feeDetails: ClobFeeDetails.fromJson(
        _map(_firstOf(json, const ['fee_details', 'feeDetails', 'fd'])),
      ),
    );
  }

  final String conditionId;
  final String questionId;
  final List<Token> tokens;
  final String gameStartTime;
  final double spread;
  final bool enableOrderBook;
  final bool acceptingOrders;
  final bool closed;
  final bool archived;
  final bool negRisk;
  final String negRiskMarketId;
  final String negRiskRequestId;
  final bool notificationsEnabled;
  final double orderMinSize;
  final double orderPriceMinTickSize;
  final double rewardsMinSize;
  final double rewardsMaxSpread;
  final int makerBaseFee;
  final int takerBaseFee;
  final bool rfqEnabled;
  final bool takerOrderDelay;
  final bool blockaidCheckEnabled;
  final int minimumOrderAge;
  final ClobFeeDetails feeDetails;
}

@immutable
final class ClobFeeDetails {
  const ClobFeeDetails({
    this.rate = 0,
    this.exponent = 0,
    this.takerOnly = false,
  });

  factory ClobFeeDetails.fromJson(Map<String, dynamic> json) => ClobFeeDetails(
    rate: _double(_first(json, 'rate', 'r')),
    exponent: _double(_first(json, 'exponent', 'e')),
    takerOnly: _bool(_firstOf(json, const ['taker_only', 'takerOnly', 'to'])),
  );

  final double rate;
  final double exponent;
  final bool takerOnly;
}

@immutable
final class ClobMarketByTokenResponse {
  const ClobMarketByTokenResponse({
    required this.conditionId,
    required this.primaryTokenId,
    required this.secondaryTokenId,
  });

  factory ClobMarketByTokenResponse.fromJson(Map<String, dynamic> json) {
    return ClobMarketByTokenResponse(
      conditionId: json['condition_id']?.toString() ?? '',
      primaryTokenId: json['primary_token_id']?.toString() ?? '',
      secondaryTokenId: json['secondary_token_id']?.toString() ?? '',
    );
  }

  final String conditionId;
  final String primaryTokenId;
  final String secondaryTokenId;
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
    timestamp: _stringOf(json, const ['t', 'timestamp']),
    price: parseNumericString(_firstOf(json, const ['p', 'price'])),
    volume: parseNumericString(_firstOf(json, const ['v', 'volume'])),
    interval: json['interval']?.toString() ?? '',
  );

  final String timestamp;
  final String price;
  final String volume;
  final String interval;
}

@immutable
final class BuilderTrade {
  const BuilderTrade({
    required this.tradeId,
    required this.orderId,
    required this.market,
    required this.assetId,
    required this.side,
    required this.size,
    required this.price,
    required this.timestamp,
  });

  factory BuilderTrade.fromJson(Map<String, dynamic> json) => BuilderTrade(
    tradeId: _stringOf(json, const ['trade_id', 'tradeId']),
    orderId: _stringOf(json, const ['order_id', 'orderId']),
    market: json['market']?.toString() ?? '',
    assetId: _stringOf(json, const ['asset_id', 'assetId']),
    side: json['side']?.toString() ?? '',
    size: parseNumericString(json['size']),
    price: parseNumericString(json['price']),
    timestamp: _stringOf(json, const ['timestamp', 'createdAt']),
  );

  final String tradeId;
  final String orderId;
  final String market;
  final String assetId;
  final String side;
  final String size;
  final String price;
  final String timestamp;
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

bool _bool(Object? raw) {
  if (raw is bool) return raw;
  if (raw is String) return raw.toLowerCase() == 'true';
  return false;
}

Object? _firstOf(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key)) return json[key];
  }
  return null;
}

String _stringOf(Map<String, dynamic> json, List<String> keys) {
  return _firstOf(json, keys)?.toString() ?? '';
}

Object? _first(Map<String, dynamic> json, String first, String second) {
  if (json.containsKey(first)) return json[first];
  return json[second];
}

Object? _firstMap(Map<String, dynamic> json, String first, String second) {
  if (json.containsKey(first)) return json[first];
  return json[second];
}

String _string(Map<String, dynamic> json, String first, String second) {
  return _first(json, first, second)?.toString() ?? '';
}

Map<String, dynamic> _map(Object? raw) {
  if (raw is Map) return raw.cast<String, dynamic>();
  return const <String, dynamic>{};
}
