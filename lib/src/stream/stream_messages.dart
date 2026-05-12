/// Typed Polymarket CLOB market WebSocket events.
///
/// Mirrors `pkg/stream/client.go` (`BookMessage`, `PriceLevel`,
/// `PriceChangeMessage`, `PriceChangeEntry`, `LastTradeMessage`,
/// `BestBidAskMessage`, `TickSizeChangeMessage`). JSON tags match polygolem
/// verbatim so the same wire payloads decode in both SDKs.
library;

import 'package:meta/meta.dart';

String _str(Object? v) => (v ?? '').toString();

List<PriceLevel> _levels(Object? raw) {
  if (raw is! List) return const <PriceLevel>[];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map(
        (m) => PriceLevel.fromJson(m.map((k, v) => MapEntry(k.toString(), v))),
      )
      .toList(growable: false);
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
    final raw = json['price_changes'];
    final changes = raw is List
        ? raw
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (m) => PriceChangeEntry.fromJson(
                  m.map((k, v) => MapEntry(k.toString(), v)),
                ),
              )
              .toList(growable: false)
        : const <PriceChangeEntry>[];
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
