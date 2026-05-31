/// Typed Polymarket CLOB market WebSocket events.
///
/// Mirrors `pkg/stream/client.go` (`BookMessage`, `PriceLevel`,
/// `PriceChangeMessage`, `PriceChangeEntry`, `LastTradeMessage`,
/// `BestBidAskMessage`, `TickSizeChangeMessage`, `NewMarketMessage`,
/// `MarketResolvedMessage`). JSON tags match polygolem verbatim so the same
/// wire payloads decode in both SDKs.
library;

import 'package:meta/meta.dart';

String _str(Object? v) => (v ?? '').toString();

bool _bool(Object? v) {
  if (v is bool) return v;
  if (v is String) return v.toLowerCase() == 'true';
  return false;
}

List<String> _strings(Object? raw) {
  if (raw is! List) return const <String>[];
  return raw.map(_str).toList(growable: false);
}

Map<String, dynamic> _map(Object? raw) {
  if (raw is! Map) return const <String, dynamic>{};
  return raw.map<String, dynamic>((k, v) => MapEntry(k.toString(), v));
}

List<PriceLevel> _levels(Object? raw) {
  if (raw is! List) return const <PriceLevel>[];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map(
        (m) => PriceLevel.fromJson(m.map((k, v) => MapEntry(k.toString(), v))),
      )
      .toList(growable: false);
}

Map<String, dynamic> _objectCandidateAt(
  List<Object?> candidates,
  int index,
  String fieldName,
) {
  final candidate = candidates[index];
  if (candidate is! Map) {
    throw FormatException(
      'stream: expected $fieldName[$index] to be a JSON object',
      candidate,
    );
  }
  return candidate.map<String, dynamic>((k, v) => MapEntry(k.toString(), v));
}

List<PriceChangeEntry> _priceChangeEntries(Object? raw) {
  if (raw is! List) return const <PriceChangeEntry>[];
  return <PriceChangeEntry>[
    for (var i = 0; i < raw.length; i++)
      PriceChangeEntry.fromJson(_objectCandidateAt(raw, i, 'price_changes')),
  ];
}

/// Single bid or ask in a [BookMessage].
@immutable
final class PriceLevel {
  const PriceLevel({required this.price, required this.size});

  factory PriceLevel.fromJson(Map<String, dynamic> json) =>
      PriceLevel(price: _str(json['price']), size: _str(json['size']));

  final String price;
  final String size;
}

/// Full order-book snapshot for a single asset (`event_type: "book"`).
@immutable
final class BookMessage {
  const BookMessage({
    required this.eventType,
    required this.assetId,
    required this.market,
    required this.timestamp,
    required this.hash,
    required this.bids,
    required this.asks,
  });

  factory BookMessage.fromJson(Map<String, dynamic> json) => BookMessage(
    eventType: _str(json['event_type']),
    assetId: _str(json['asset_id']),
    market: _str(json['market']),
    timestamp: _str(json['timestamp']),
    hash: _str(json['hash']),
    bids: _levels(json['bids']),
    asks: _levels(json['asks']),
  );

  final String eventType;
  final String assetId;
  final String market;
  final String timestamp;
  final String hash;
  final List<PriceLevel> bids;
  final List<PriceLevel> asks;
}

/// One price-level mutation inside a [PriceChangeMessage].
@immutable
final class PriceChangeEntry {
  const PriceChangeEntry({
    required this.assetId,
    required this.price,
    required this.side,
    required this.size,
    required this.hash,
    this.bestBid = '',
    this.bestAsk = '',
  });

  factory PriceChangeEntry.fromJson(Map<String, dynamic> json) =>
      PriceChangeEntry(
        assetId: _str(json['asset_id']),
        price: _str(json['price']),
        side: _str(json['side']),
        size: _str(json['size']),
        hash: _str(json['hash']),
        bestBid: _str(json['best_bid']),
        bestAsk: _str(json['best_ask']),
      );

  final String assetId;
  final String price;
  final String side;
  final String size;
  final String hash;
  final String bestBid;
  final String bestAsk;
}

/// Incremental book mutation (`event_type: "price_change"`).
@immutable
final class PriceChangeMessage {
  const PriceChangeMessage({
    required this.eventType,
    required this.market,
    required this.changes,
    required this.timestamp,
  });

  factory PriceChangeMessage.fromJson(Map<String, dynamic> json) {
    final changes = _priceChangeEntries(json['price_changes']);
    return PriceChangeMessage(
      eventType: _str(json['event_type']),
      market: _str(json['market']),
      changes: changes,
      timestamp: _str(json['timestamp']),
    );
  }

  final String eventType;
  final String market;
  final List<PriceChangeEntry> changes;
  final String timestamp;
}

/// Latest trade fill (`event_type: "last_trade_price"`).
@immutable
final class LastTradeMessage {
  const LastTradeMessage({
    required this.eventType,
    required this.assetId,
    required this.market,
    required this.price,
    required this.side,
    required this.size,
    required this.feeRateBps,
    required this.timestamp,
    this.transactionHash = '',
  });

  factory LastTradeMessage.fromJson(Map<String, dynamic> json) =>
      LastTradeMessage(
        eventType: _str(json['event_type']),
        assetId: _str(json['asset_id']),
        market: _str(json['market']),
        price: _str(json['price']),
        side: _str(json['side']),
        size: _str(json['size']),
        feeRateBps: _str(json['fee_rate_bps']),
        timestamp: _str(json['timestamp']),
        transactionHash: _str(json['transaction_hash']),
      );

  final String eventType;
  final String assetId;
  final String market;
  final String price;
  final String side;
  final String size;
  final String feeRateBps;
  final String timestamp;
  final String transactionHash;
}

/// Top-of-book update (`event_type: "best_bid_ask"`).
@immutable
final class BestBidAskMessage {
  const BestBidAskMessage({
    required this.eventType,
    required this.assetId,
    required this.market,
    required this.bestBid,
    required this.bestAsk,
    required this.spread,
    required this.timestamp,
  });

  factory BestBidAskMessage.fromJson(Map<String, dynamic> json) =>
      BestBidAskMessage(
        eventType: _str(json['event_type']),
        assetId: _str(json['asset_id']),
        market: _str(json['market']),
        bestBid: _str(json['best_bid']),
        bestAsk: _str(json['best_ask']),
        spread: _str(json['spread']),
        timestamp: _str(json['timestamp']),
      );

  final String eventType;
  final String assetId;
  final String market;
  final String bestBid;
  final String bestAsk;
  final String spread;
  final String timestamp;
}

/// Tick-size update (`event_type: "tick_size_change"`).
@immutable
final class TickSizeChangeMessage {
  const TickSizeChangeMessage({
    required this.eventType,
    required this.assetId,
    required this.market,
    required this.oldTickSize,
    required this.newTickSize,
    required this.timestamp,
  });

  factory TickSizeChangeMessage.fromJson(Map<String, dynamic> json) =>
      TickSizeChangeMessage(
        eventType: _str(json['event_type']),
        assetId: _str(json['asset_id']),
        market: _str(json['market']),
        oldTickSize: _str(json['old_tick_size']),
        newTickSize: _str(json['new_tick_size']),
        timestamp: _str(json['timestamp']),
      );

  final String eventType;
  final String assetId;
  final String market;
  final String oldTickSize;
  final String newTickSize;
  final String timestamp;
}

/// Market lifecycle creation event (`event_type: "new_market"`).
@immutable
final class NewMarketMessage {
  const NewMarketMessage({
    required this.eventType,
    required this.id,
    required this.question,
    required this.market,
    required this.slug,
    required this.description,
    required this.assetIds,
    required this.outcomes,
    this.eventMessage = const <String, dynamic>{},
    required this.timestamp,
    required this.tags,
    required this.conditionId,
    required this.clobTokenIds,
    required this.active,
    this.sportsMarketType = '',
    this.line = '',
    this.gameStartTime = '',
    this.orderPriceMinTickSize = '',
    this.groupItemTitle = '',
    this.takerBaseFee = '',
    this.feesEnabled = false,
    this.feeSchedule = const <String, dynamic>{},
  });

  factory NewMarketMessage.fromJson(Map<String, dynamic> json) =>
      NewMarketMessage(
        eventType: _str(json['event_type']),
        id: _str(json['id']),
        question: _str(json['question']),
        market: _str(json['market']),
        slug: _str(json['slug']),
        description: _str(json['description']),
        assetIds: _strings(json['assets_ids']),
        outcomes: _strings(json['outcomes']),
        eventMessage: _map(json['event_message']),
        timestamp: _str(json['timestamp']),
        tags: _strings(json['tags']),
        conditionId: _str(json['condition_id']),
        clobTokenIds: _strings(json['clob_token_ids']),
        active: _bool(json['active']),
        sportsMarketType: _str(json['sports_market_type']),
        line: _str(json['line']),
        gameStartTime: _str(json['game_start_time']),
        orderPriceMinTickSize: _str(json['order_price_min_tick_size']),
        groupItemTitle: _str(json['group_item_title']),
        takerBaseFee: _str(json['taker_base_fee']),
        feesEnabled: _bool(json['fees_enabled']),
        feeSchedule: _map(json['fee_schedule']),
      );

  final String eventType;
  final String id;
  final String question;
  final String market;
  final String slug;
  final String description;
  final List<String> assetIds;
  final List<String> outcomes;
  final Map<String, dynamic> eventMessage;
  final String timestamp;
  final List<String> tags;
  final String conditionId;
  final List<String> clobTokenIds;
  final bool active;
  final String sportsMarketType;
  final String line;
  final String gameStartTime;
  final String orderPriceMinTickSize;
  final String groupItemTitle;
  final String takerBaseFee;
  final bool feesEnabled;
  final Map<String, dynamic> feeSchedule;
}

/// Market lifecycle resolution event (`event_type: "market_resolved"`).
@immutable
final class MarketResolvedMessage {
  const MarketResolvedMessage({
    required this.eventType,
    required this.id,
    required this.market,
    required this.assetIds,
    required this.winningAssetId,
    required this.winningOutcome,
    required this.timestamp,
    required this.tags,
  });

  factory MarketResolvedMessage.fromJson(Map<String, dynamic> json) =>
      MarketResolvedMessage(
        eventType: _str(json['event_type']),
        id: _str(json['id']),
        market: _str(json['market']),
        assetIds: _strings(json['assets_ids']),
        winningAssetId: _str(json['winning_asset_id']),
        winningOutcome: _str(json['winning_outcome']),
        timestamp: _str(json['timestamp']),
        tags: _strings(json['tags']),
      );

  final String eventType;
  final String id;
  final String market;
  final List<String> assetIds;
  final String winningAssetId;
  final String winningOutcome;
  final String timestamp;
  final List<String> tags;
}

/// Authenticated user-channel order event (`event_type: "order"`).
@immutable
final class UserOrderMessage {
  const UserOrderMessage({
    required this.eventType,
    this.id = '',
    this.orderId = '',
    this.market = '',
    this.assetId = '',
    this.side = '',
    this.price = '',
    this.size = '',
    this.status = '',
    this.timestamp = '',
  });

  factory UserOrderMessage.fromJson(Map<String, dynamic> json) =>
      UserOrderMessage(
        eventType: _str(json['event_type'] ?? json['type']),
        id: _str(json['id']),
        orderId: _str(json['order_id'] ?? json['orderID']),
        market: _str(json['market']),
        assetId: _str(json['asset_id']),
        side: _str(json['side']),
        price: _str(json['price']),
        size: _str(json['size']),
        status: _str(json['status']),
        timestamp: _str(json['timestamp']),
      );

  final String eventType;
  final String id;
  final String orderId;
  final String market;
  final String assetId;
  final String side;
  final String price;
  final String size;
  final String status;
  final String timestamp;
}

/// Authenticated user-channel trade/fill event (`event_type: "trade"`).
@immutable
final class UserTradeMessage {
  const UserTradeMessage({
    required this.eventType,
    this.id = '',
    this.tradeId = '',
    this.orderId = '',
    this.market = '',
    this.assetId = '',
    this.side = '',
    this.price = '',
    this.size = '',
    this.feeRateBps = '',
    this.timestamp = '',
    this.transactionHash = '',
  });

  factory UserTradeMessage.fromJson(Map<String, dynamic> json) =>
      UserTradeMessage(
        eventType: _str(json['event_type'] ?? json['type']),
        id: _str(json['id']),
        tradeId: _str(json['trade_id'] ?? json['tradeID']),
        orderId: _str(json['order_id'] ?? json['orderID']),
        market: _str(json['market']),
        assetId: _str(json['asset_id']),
        side: _str(json['side']),
        price: _str(json['price']),
        size: _str(json['size']),
        feeRateBps: _str(json['fee_rate_bps']),
        timestamp: _str(json['timestamp']),
        transactionHash: _str(json['transaction_hash']),
      );

  final String eventType;
  final String id;
  final String tradeId;
  final String orderId;
  final String market;
  final String assetId;
  final String side;
  final String price;
  final String size;
  final String feeRateBps;
  final String timestamp;
  final String transactionHash;
}
