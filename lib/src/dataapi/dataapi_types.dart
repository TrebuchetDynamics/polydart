/// Polymarket Data API data types.
///
/// Mirrors the `Position`, `Trade`, `Activity`, `MetaHolder`, `TotalValue`,
/// `TotalMarketsTraded`, `OpenInterest`, `TraderLeaderboardEntry`,
/// `LiveVolumeEntry`, and `LiveVolumeResponse` structs declared in
/// `internal/dataapi/client.go`. Decoders accept both older snake_case fields
/// and current Polymarket V2 camelCase fields where polygolem does the same.
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
    this.eventId = '',
    this.proxyWallet = '',
    this.initialValue = 0,
    this.currentValue = 0,
    this.cashPnl = 0,
    this.percentPnl = 0,
    this.totalBought = 0,
    this.realizedPnl = 0,
    this.percentRealized = 0,
    this.redeemable = false,
    this.mergeable = false,
    this.negativeRisk = false,
    this.outcome = '',
    this.outcomeIndex = 0,
    this.oppositeOutcome = '',
    this.oppositeAsset = '',
    this.endDate = '',
    this.title = '',
    this.slug = '',
    this.eventSlug = '',
    this.icon = '',
  });

  factory Position.fromJson(Map<String, dynamic> json) => Position(
    tokenId: _string(json, 'asset', 'token_id'),
    conditionId: _string(json, 'conditionId', 'condition_id'),
    marketId: _string(json, 'market_id', 'market'),
    side: json['side']?.toString() ?? '',
    avgPrice: _double(_first(json, 'avgPrice', 'avg_price')),
    size: _double(json['size']),
    currentPrice: _double(_first(json, 'curPrice', 'current_price')),
    unrealizedPnl: _double(_first(json, 'unrealizedPnl', 'unrealized_pnl')),
    eventId: _string(json, 'eventId'),
    proxyWallet: _string(json, 'proxyWallet'),
    initialValue: _double(json['initialValue']),
    currentValue: _double(json['currentValue']),
    cashPnl: _double(json['cashPnl']),
    percentPnl: _double(json['percentPnl']),
    totalBought: _double(json['totalBought']),
    realizedPnl: _double(json['realizedPnl']),
    percentRealized: _double(json['percentRealizedPnl']),
    redeemable: _bool(json['redeemable']),
    mergeable: _bool(json['mergeable']),
    negativeRisk: _bool(json['negativeRisk']),
    outcome: _string(json, 'outcome'),
    outcomeIndex: _int(json['outcomeIndex']),
    oppositeOutcome: _string(json, 'oppositeOutcome'),
    oppositeAsset: _string(json, 'oppositeAsset'),
    endDate: _string(json, 'endDate'),
    title: _string(json, 'title'),
    slug: _string(json, 'slug'),
    eventSlug: _string(json, 'eventSlug'),
    icon: _string(json, 'icon'),
  );

  final String tokenId;
  final String conditionId;
  final String marketId;
  final String side;
  final double avgPrice;
  final double size;
  final double currentPrice;
  final double unrealizedPnl;
  final String eventId;
  final String proxyWallet;
  final double initialValue;
  final double currentValue;
  final double cashPnl;
  final double percentPnl;
  final double totalBought;
  final double realizedPnl;
  final double percentRealized;
  final bool redeemable;
  final bool mergeable;
  final bool negativeRisk;
  final String outcome;
  final int outcomeIndex;
  final String oppositeOutcome;
  final String oppositeAsset;
  final String endDate;
  final String title;
  final String slug;
  final String eventSlug;
  final String icon;
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
    this.proxyWallet = '',
    this.avgPrice = 0,
    this.totalBought = 0,
    this.currentPrice = 0,
    this.timestamp = '',
    this.title = '',
    this.slug = '',
    this.icon = '',
    this.eventSlug = '',
    this.outcome = '',
    this.outcomeIndex = 0,
    this.oppositeOutcome = '',
    this.oppositeAsset = '',
    this.endDate = '',
  });

  factory ClosedPosition.fromJson(Map<String, dynamic> json) {
    final avgPrice = _double(json['avgPrice']);
    return ClosedPosition(
      tokenId: _string(json, 'asset', 'token_id'),
      conditionId: _string(json, 'conditionId', 'condition_id'),
      marketId: _string(json, 'market_id'),
      side: _string(json, 'side'),
      avgPrice: avgPrice,
      avgPriceBuy: _double(_firstOf(json, const ['avg_price_buy', 'avgPrice'])),
      avgPriceSell: _double(json['avg_price_sell']),
      size: _double(_firstOf(json, const ['size', 'totalBought'])),
      totalBought: _double(json['totalBought']),
      realizedPnl: _double(_first(json, 'realizedPnl', 'realized_pnl')),
      proxyWallet: _string(json, 'proxyWallet'),
      currentPrice: _double(json['curPrice']),
      timestamp: _string(json, 'timestamp'),
      title: _string(json, 'title'),
      slug: _string(json, 'slug'),
      icon: _string(json, 'icon'),
      eventSlug: _string(json, 'eventSlug'),
      outcome: _string(json, 'outcome'),
      outcomeIndex: _int(json['outcomeIndex']),
      oppositeOutcome: _string(json, 'oppositeOutcome'),
      oppositeAsset: _string(json, 'oppositeAsset'),
      endDate: _string(json, 'endDate'),
    );
  }

  final String tokenId;
  final String conditionId;
  final String marketId;
  final String side;
  final double avgPriceBuy;
  final double avgPriceSell;
  final double size;
  final double realizedPnl;
  final String proxyWallet;
  final double avgPrice;
  final double totalBought;
  final double currentPrice;
  final String timestamp;
  final String title;
  final String slug;
  final String icon;
  final String eventSlug;
  final String outcome;
  final int outcomeIndex;
  final String oppositeOutcome;
  final String oppositeAsset;
  final String endDate;
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
    this.proxyWallet = '',
    this.outcome = '',
    this.outcomeIndex = 0,
    this.title = '',
    this.slug = '',
    this.eventSlug = '',
    this.icon = '',
    this.status = '',
    this.transactionHash = '',
    this.takerOrderId = '',
    this.traderSide = '',
  });

  factory Trade.fromJson(Map<String, dynamic> json) => Trade(
    id: _string(json, 'id'),
    market: _string(json, 'market', 'conditionId'),
    assetId: _stringOf(json, const ['asset_id', 'assetId', 'asset']),
    side: _string(json, 'side'),
    price: _double(json['price']),
    size: _double(json['size']),
    feeRateBps: _int(_first(json, 'fee_rate_bps', 'feeRateBps')),
    createdAt: _stringOf(json, const ['created_at', 'timestamp', 'match_time']),
    proxyWallet: _string(json, 'proxyWallet'),
    outcome: _string(json, 'outcome'),
    outcomeIndex: _int(json['outcomeIndex']),
    title: _string(json, 'title'),
    slug: _string(json, 'slug'),
    eventSlug: _string(json, 'eventSlug'),
    icon: _string(json, 'icon'),
    status: _string(json, 'status'),
    transactionHash: _string(json, 'transaction_hash', 'transactionHash'),
    takerOrderId: _string(json, 'taker_order_id', 'takerOrderId'),
    traderSide: _string(json, 'trader_side', 'traderSide'),
  );

  final String id;
  final String market;
  final String assetId;
  final String side;
  final double price;
  final double size;
  final int feeRateBps;
  final String createdAt;
  final String proxyWallet;
  final String outcome;
  final int outcomeIndex;
  final String title;
  final String slug;
  final String eventSlug;
  final String icon;
  final String status;
  final String transactionHash;
  final String takerOrderId;
  final String traderSide;
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
    assetId: _stringOf(json, const ['asset_id', 'assetId']),
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
    this.proxyWallet = '',
    this.amount = 0,
  });

  factory MetaHolder.fromJson(Map<String, dynamic> json) => MetaHolder(
    address: _stringOf(json, const ['address', 'proxyWallet']),
    proxyWallet: _stringOf(json, const ['proxyWallet', 'address']),
    shares: _double(_firstOf(json, const ['shares', 'amount'])),
    amount: _double(_firstOf(json, const ['amount', 'shares'])),
    pnl: _double(json['pnl']),
    volume: _double(json['volume']),
  );

  final String address;
  final String proxyWallet;
  final double shares;
  final double amount;
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

  factory TotalValue.fromJson(Object? json, {String defaultUser = ''}) {
    final map = _responseMap(json);
    return TotalValue(
      user: _stringOf(map, const ['user']).isEmpty
          ? defaultUser
          : _stringOf(map, const ['user']),
      value: _double(map['value']),
      timestamp: map['timestamp']?.toString() ?? '',
    );
  }

  final String user;
  final double value;
  final String timestamp;
}

@immutable
final class TotalMarketsTraded {
  const TotalMarketsTraded({
    required this.user,
    required this.marketsTraded,
    this.traded = 0,
  });

  factory TotalMarketsTraded.fromJson(Map<String, dynamic> json) {
    final marketsTraded = _int(json['markets_traded']);
    final traded = _int(json['traded']);
    return TotalMarketsTraded(
      user: json['user']?.toString() ?? '',
      marketsTraded: marketsTraded == 0 ? traded : marketsTraded,
      traded: traded == 0 ? marketsTraded : traded,
    );
  }

  final String user;
  final int marketsTraded;
  final int traded;
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
    openValue: _double(_firstOf(json, const ['open_value', 'value'])),
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
        user: _stringOf(json, const ['user', 'proxyWallet', 'userName']),
        volume: _double(_firstOf(json, const ['volume', 'vol'])),
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
final class LiveVolumeMarket {
  const LiveVolumeMarket({required this.market, required this.value});

  factory LiveVolumeMarket.fromJson(Map<String, dynamic> json) =>
      LiveVolumeMarket(
        market: json['market']?.toString() ?? '',
        value: _double(json['value']),
      );

  final String market;
  final double value;
}

@immutable
final class LiveVolumeResponse {
  const LiveVolumeResponse({
    required this.total,
    required this.events,
    this.markets = const <LiveVolumeMarket>[],
  });

  factory LiveVolumeResponse.fromJson(Object? json) {
    final map = _responseMap(json);
    return LiveVolumeResponse(
      total: _double(map['total']),
      events: _liveVolumeEntries(map['events']),
      markets: _liveVolumeMarkets(map['markets']),
    );
  }

  final double total;
  final List<LiveVolumeEntry> events;
  final List<LiveVolumeMarket> markets;
}

// ---- helpers ----

Object? _first(Map<String, dynamic> json, String first, String second) {
  return _firstOf(json, [first, second]);
}

Object? _firstOf(Map<String, dynamic> json, Iterable<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    if (value is String && value.isEmpty) continue;
    return value;
  }
  return null;
}

String _string(Map<String, dynamic> json, String first, [String? second]) {
  return _stringOf(json, second == null ? [first] : [first, second]);
}

String _stringOf(Map<String, dynamic> json, Iterable<String> keys) {
  return _firstOf(json, keys)?.toString() ?? '';
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

Map<String, dynamic> _responseMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.cast<String, dynamic>();
  if (raw is List) {
    if (raw.isEmpty) return const <String, dynamic>{};
    return _mapCandidateAt(raw, 0, 'response');
  }
  return const <String, dynamic>{};
}

List<LiveVolumeEntry> _liveVolumeEntries(Object? raw) =>
    _decodeObjectList(raw, 'live-volume.events', LiveVolumeEntry.fromJson);

List<LiveVolumeMarket> _liveVolumeMarkets(Object? raw) =>
    _decodeObjectList(raw, 'live-volume.markets', LiveVolumeMarket.fromJson);

List<T> _decodeObjectList<T>(
  Object? raw,
  String path,
  T Function(Map<String, dynamic>) decode,
) {
  if (raw is! List) return <T>[];
  final decoded = <T>[];
  for (var i = 0; i < raw.length; i++) {
    decoded.add(decode(_mapCandidateAt(raw, i, path)));
  }
  return decoded.toList(growable: false);
}

Map<String, dynamic> _mapCandidateAt(
  List<dynamic> candidates,
  int index,
  String path,
) {
  final candidate = candidates[index];
  if (candidate is! Map<dynamic, dynamic>) {
    throw FormatException(
      'Data API $path[$index]: expected JSON object',
      candidate,
    );
  }
  return candidate.cast<String, dynamic>();
}
