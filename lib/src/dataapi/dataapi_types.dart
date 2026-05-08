/// Polymarket Data API data types.
///
/// Mirrors the `Position`, `Trade`, `Activity`, `MetaHolder`, `TotalValue`,
/// `TotalMarketsTraded`, `OpenInterest`, `TraderLeaderboardEntry`,
/// `LiveVolumeEntry`, and `LiveVolumeResponse` structs declared in
/// `internal/dataapi/client.go`. JSON tags match the Go struct tags
/// exactly so payloads round-trip without a translation layer.
library;

import 'package:meta/meta.dart';

@immutable
final class Position {
  const Position({
    required this.tokenId,
    required this.conditionId,
    required this.marketId,
    required this.side,
    required this.avgPrice,
    required this.size,
    required this.currentPrice,
    required this.unrealizedPnl,
  });

  factory Position.fromJson(Map<String, dynamic> json) => Position(
    tokenId: json['token_id']?.toString() ?? '',
    conditionId: json['condition_id']?.toString() ?? '',
    marketId: json['market_id']?.toString() ?? '',
    side: json['side']?.toString() ?? '',
    avgPrice: _double(json['avg_price']),
    size: _double(json['size']),
    currentPrice: _double(json['current_price']),
    unrealizedPnl: _double(json['unrealized_pnl']),
  );

  final String tokenId;
  final String conditionId;
  final String marketId;
  final String side;
  final double avgPrice;
  final double size;
  final double currentPrice;
  final double unrealizedPnl;
}

@immutable
final class ClosedPosition {
  const ClosedPosition({
    required this.tokenId,
    required this.conditionId,
    required this.marketId,
    required this.side,
    required this.avgPriceBuy,
    required this.avgPriceSell,
    required this.size,
    required this.realizedPnl,
  });

  factory ClosedPosition.fromJson(Map<String, dynamic> json) => ClosedPosition(
    tokenId: json['token_id']?.toString() ?? '',
    conditionId: json['condition_id']?.toString() ?? '',
    marketId: json['market_id']?.toString() ?? '',
    side: json['side']?.toString() ?? '',
    avgPriceBuy: _double(json['avg_price_buy']),
    avgPriceSell: _double(json['avg_price_sell']),
    size: _double(json['size']),
    realizedPnl: _double(json['realized_pnl']),
  );

  final String tokenId;
  final String conditionId;
  final String marketId;
  final String side;
  final double avgPriceBuy;
  final double avgPriceSell;
  final double size;
  final double realizedPnl;
}

@immutable
final class Trade {
  const Trade({
    required this.id,
    required this.market,
    required this.assetId,
    required this.side,
    required this.price,
    required this.size,
    required this.feeRateBps,
    required this.createdAt,
  });

  factory Trade.fromJson(Map<String, dynamic> json) => Trade(
    id: json['id']?.toString() ?? '',
    market: json['market']?.toString() ?? '',
    assetId: json['asset_id']?.toString() ?? '',
    side: json['side']?.toString() ?? '',
    price: _double(json['price']),
    size: _double(json['size']),
    feeRateBps: _int(json['fee_rate_bps']),
    createdAt: json['created_at']?.toString() ?? '',
  );

  final String id;
  final String market;
  final String assetId;
  final String side;
  final double price;
  final double size;
  final int feeRateBps;
  final String createdAt;
}

/// One on-chain or off-chain user activity event.
///
/// `price` and `size` are strings in the Go reference because the upstream
/// payload occasionally returns formatted decimals; preserve that.
@immutable
final class Activity {
  const Activity({
    required this.type,
    required this.market,
    required this.assetId,
    required this.side,
    required this.price,
    required this.size,
    required this.timestamp,
  });

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
    type: json['type']?.toString() ?? '',
    market: json['market']?.toString() ?? '',
    assetId: json['asset_id']?.toString() ?? '',
    side: json['side']?.toString() ?? '',
    price: json['price']?.toString() ?? '',
    size: json['size']?.toString() ?? '',
    timestamp: json['timestamp']?.toString() ?? '',
  );

  final String type;
  final String market;
  final String assetId;
  final String side;
  final String price;
  final String size;
  final String timestamp;
}

@immutable
final class MetaHolder {
  const MetaHolder({
    required this.address,
    required this.shares,
    required this.pnl,
    required this.volume,
  });

  factory MetaHolder.fromJson(Map<String, dynamic> json) => MetaHolder(
    address: json['address']?.toString() ?? '',
    shares: _double(json['shares']),
    pnl: _double(json['pnl']),
    volume: _double(json['volume']),
  );

  final String address;
  final double shares;
  final double pnl;
  final double volume;
}

@immutable
final class TotalValue {
  const TotalValue({
    required this.user,
    required this.value,
    required this.timestamp,
  });

  factory TotalValue.fromJson(Map<String, dynamic> json) => TotalValue(
    user: json['user']?.toString() ?? '',
    value: _double(json['value']),
    timestamp: json['timestamp']?.toString() ?? '',
  );

  final String user;
  final double value;
  final String timestamp;
}

@immutable
final class TotalMarketsTraded {
  const TotalMarketsTraded({required this.user, required this.marketsTraded});

  factory TotalMarketsTraded.fromJson(Map<String, dynamic> json) =>
      TotalMarketsTraded(
        user: json['user']?.toString() ?? '',
        marketsTraded: _int(json['markets_traded']),
      );

  final String user;
  final int marketsTraded;
}

@immutable
final class OpenInterest {
  const OpenInterest({
    required this.market,
    required this.assetId,
    required this.openValue,
  });

  factory OpenInterest.fromJson(Map<String, dynamic> json) => OpenInterest(
    market: json['market']?.toString() ?? '',
    assetId: json['asset_id']?.toString() ?? '',
    openValue: _double(json['open_value']),
  );

  final String market;
  final String assetId;
  final double openValue;
}

@immutable
final class TraderLeaderboardEntry {
  const TraderLeaderboardEntry({
    required this.rank,
    required this.user,
    required this.volume,
    required this.pnl,
    required this.roi,
  });

  factory TraderLeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      TraderLeaderboardEntry(
        rank: _int(json['rank']),
        user: json['user']?.toString() ?? '',
        volume: _double(json['volume']),
        pnl: _double(json['pnl']),
        roi: _double(json['roi']),
      );

  final int rank;
  final String user;
  final double volume;
  final double pnl;
  final double roi;
}

@immutable
final class LiveVolumeEntry {
  const LiveVolumeEntry({
    required this.eventId,
    required this.eventSlug,
    required this.title,
    required this.volume,
  });

  factory LiveVolumeEntry.fromJson(Map<String, dynamic> json) =>
      LiveVolumeEntry(
        eventId: json['event_id']?.toString() ?? '',
        eventSlug: json['event_slug']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        volume: _double(json['volume']),
      );

  final String eventId;
  final String eventSlug;
  final String title;
  final double volume;
}

@immutable
final class LiveVolumeResponse {
  const LiveVolumeResponse({required this.total, required this.events});

  factory LiveVolumeResponse.fromJson(Map<String, dynamic> json) =>
      LiveVolumeResponse(
        total: _int(json['total']),
        events: _liveVolumeEntries(json['events']),
      );

  final int total;
  final List<LiveVolumeEntry> events;
}

// ---- helpers ----

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

List<LiveVolumeEntry> _liveVolumeEntries(Object? raw) {
  if (raw is! List) return const <LiveVolumeEntry>[];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => LiveVolumeEntry.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);
}
