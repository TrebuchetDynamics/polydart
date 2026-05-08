/// Typed Polymarket CLOB market WebSocket events.
///
/// Mirrors `internal/stream/client.go` (`BookMessage`, `PriceLevel`,
/// `PriceChangeMessage`, `PriceChangeEntry`, `LastTradeMessage`). JSON tags
/// match polygolem verbatim so the same wire payloads decode in both SDKs.
library;

import 'package:meta/meta.dart';

String _str(Object? v) => (v ?? '').toString();

List<PriceLevel> _levels(Object? raw) {
  if (raw is! List) return const <PriceLevel>[];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map(
        (m) => PriceLevel.fromJson(
          m.map((k, v) => MapEntry(k.toString(), v)),
        ),
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
  });

  factory PriceChangeEntry.fromJson(Map<String, dynamic> json) =>
      PriceChangeEntry(
        assetId: _str(json['asset_id']),
        price: _str(json['price']),
        side: _str(json['side']),
        size: _str(json['size']),
        hash: _str(json['hash']),
      );

  final String assetId;
  final String price;
  final String side;
  final String size;
  final String hash;
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
      );

  final String eventType;
  final String assetId;
  final String market;
  final String price;
  final String side;
  final String size;
  final String feeRateBps;
  final String timestamp;
}
