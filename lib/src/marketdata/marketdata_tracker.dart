/// In-memory market-data tracker for Polymarket market-stream messages.
library;

import 'package:meta/meta.dart';
import 'package:polydart/src/stream/stream_messages.dart';

/// One price level in a tracked order-book snapshot.
@immutable
final class Level {
  const Level({required this.price, required this.size});

  final String price;
  final String size;
}

/// Latest normalized market-data view for one CLOB token.
@immutable
final class Snapshot {
  Snapshot({
    required this.eventType,
    required this.assetId,
    required this.market,
    required this.timestamp,
    required this.bestBid,
    required this.bestAsk,
    required this.spread,
    required this.midpoint,
    required this.tickSize,
    required this.previousTickSize,
    required this.lastTradePrice,
    required this.lastTradeSize,
    required this.lastTradeSide,
    required this.transactionHash,
    required this.updateHash,
    required Iterable<Level> bids,
    required Iterable<Level> asks,
  }) : bids = List<Level>.unmodifiable(bids),
       asks = List<Level>.unmodifiable(asks);

  Snapshot.empty(String assetId)
    : this(
        eventType: '',
        assetId: assetId,
        market: '',
        timestamp: '',
        bestBid: '',
        bestAsk: '',
        spread: '',
        midpoint: '',
        tickSize: '',
        previousTickSize: '',
        lastTradePrice: '',
        lastTradeSize: '',
        lastTradeSide: '',
        transactionHash: '',
        updateHash: '',
        bids: const <Level>[],
        asks: const <Level>[],
      );

  final String eventType;
  final String assetId;
  final String market;
  final String timestamp;
  final String bestBid;
  final String bestAsk;
  final String spread;
  final String midpoint;
  final String tickSize;
  final String previousTickSize;
  final String lastTradePrice;
  final String lastTradeSize;
  final String lastTradeSide;
  final String transactionHash;
  final String updateHash;
  final List<Level> bids;
  final List<Level> asks;

  Snapshot _copyWith({
    String? eventType,
    String? assetId,
    String? market,
    String? timestamp,
    String? bestBid,
    String? bestAsk,
    String? spread,
    String? midpoint,
    String? tickSize,
    String? previousTickSize,
    String? lastTradePrice,
    String? lastTradeSize,
    String? lastTradeSide,
    String? transactionHash,
    String? updateHash,
    Iterable<Level>? bids,
    Iterable<Level>? asks,
  }) => Snapshot(
    eventType: eventType ?? this.eventType,
    assetId: assetId ?? this.assetId,
    market: market ?? this.market,
    timestamp: timestamp ?? this.timestamp,
    bestBid: bestBid ?? this.bestBid,
    bestAsk: bestAsk ?? this.bestAsk,
    spread: spread ?? this.spread,
    midpoint: midpoint ?? this.midpoint,
    tickSize: tickSize ?? this.tickSize,
    previousTickSize: previousTickSize ?? this.previousTickSize,
    lastTradePrice: lastTradePrice ?? this.lastTradePrice,
    lastTradeSize: lastTradeSize ?? this.lastTradeSize,
    lastTradeSide: lastTradeSide ?? this.lastTradeSide,
    transactionHash: transactionHash ?? this.transactionHash,
    updateHash: updateHash ?? this.updateHash,
    bids: bids ?? this.bids,
    asks: asks ?? this.asks,
  );
}

/// Tracks the latest normalized market-data snapshot per asset ID.
final class MarketDataTracker {
  final Map<String, Snapshot> _snapshots = <String, Snapshot>{};

  /// Records a full book snapshot and returns the normalized latest view.
  Snapshot applyBook(BookMessage message) {
    var next = _snapshotFor(message.assetId)._copyWith(
      eventType: _firstNonEmpty(<String>[message.eventType, 'book']),
      assetId: message.assetId,
      market: _firstNonEmpty(<String>[
        message.market,
        _snapshotFor(message.assetId).market,
      ]),
      timestamp: message.timestamp,
      updateHash: message.hash,
      bids: _sortLevels(_levelsFromStream(message.bids), bid: true),
      asks: _sortLevels(_levelsFromStream(message.asks), bid: false),
    );
    next = _refreshPrices(next);
    _snapshots[message.assetId] = next;
    return next;
  }

  /// Applies one price-change message and returns one snapshot per changed asset.
  List<Snapshot> applyPriceChange(PriceChangeMessage message) {
    final out = <Snapshot>[];
    for (final change in message.changes) {
      if (change.assetId.trim().isEmpty) continue;

      final current = _snapshotFor(change.assetId);
      var next = current._copyWith(
        eventType: _firstNonEmpty(<String>[message.eventType, 'price_change']),
        assetId: change.assetId,
        market: _firstNonEmpty(<String>[message.market, current.market]),
        timestamp: message.timestamp,
        updateHash: change.hash,
      );

      next = _applyLevelChange(next, change);
      final useStreamBest =
          change.bestBid.isNotEmpty || change.bestAsk.isNotEmpty;
      if (useStreamBest) {
        next = next._copyWith(
          bestBid: change.bestBid.isNotEmpty ? change.bestBid : next.bestBid,
          bestAsk: change.bestAsk.isNotEmpty ? change.bestAsk : next.bestAsk,
        );
        next = _refreshMidpoint(next);
      } else {
        next = _refreshPrices(next);
      }

      _snapshots[change.assetId] = next;
      out.add(next);
    }
    return out;
  }

  /// Records the latest trade for one asset and returns the latest view.
  Snapshot applyLastTrade(LastTradeMessage message) {
    final current = _snapshotFor(message.assetId);
    var next = current._copyWith(
      eventType: _firstNonEmpty(<String>[
        message.eventType,
        'last_trade_price',
      ]),
      assetId: message.assetId,
      market: _firstNonEmpty(<String>[message.market, current.market]),
      timestamp: message.timestamp,
      lastTradePrice: message.price,
      lastTradeSize: message.size,
      lastTradeSide: message.side,
      transactionHash: message.transactionHash,
    );
    next = _refreshPrices(next);
    _snapshots[message.assetId] = next;
    return next;
  }

  /// Records a top-of-book update and returns the latest view.
  Snapshot applyBestBidAsk(BestBidAskMessage message) {
    final current = _snapshotFor(message.assetId);
    var next = current._copyWith(
      eventType: _firstNonEmpty(<String>[message.eventType, 'best_bid_ask']),
      assetId: message.assetId,
      market: _firstNonEmpty(<String>[message.market, current.market]),
      timestamp: message.timestamp,
      bestBid: _firstNonEmpty(<String>[message.bestBid, current.bestBid]),
      bestAsk: _firstNonEmpty(<String>[message.bestAsk, current.bestAsk]),
    );
    next = _refreshMidpoint(next);
    next = next._copyWith(
      spread: _firstNonEmpty(<String>[message.spread, next.spread]),
    );
    _snapshots[message.assetId] = next;
    return next;
  }

  /// Records the latest tick-size metadata for one asset.
  Snapshot applyTickSizeChange(TickSizeChangeMessage message) {
    final current = _snapshotFor(message.assetId);
    final next = current._copyWith(
      eventType: _firstNonEmpty(<String>[
        message.eventType,
        'tick_size_change',
      ]),
      assetId: message.assetId,
      market: _firstNonEmpty(<String>[message.market, current.market]),
      timestamp: message.timestamp,
      previousTickSize: message.oldTickSize,
      tickSize: message.newTickSize,
    );
    _snapshots[message.assetId] = next;
    return next;
  }

  /// Returns the latest snapshot for [assetId], or null when it is unknown.
  Snapshot? snapshot(String assetId) => _snapshots[assetId];

  Snapshot _snapshotFor(String assetId) =>
      _snapshots[assetId] ?? Snapshot.empty(assetId);
}

List<Level> _levelsFromStream(List<PriceLevel> rows) => rows
    .map((row) => Level(price: row.price, size: row.size))
    .toList(growable: false);

Snapshot _applyLevelChange(Snapshot snapshot, PriceChangeEntry change) {
  switch (change.side.trim().toUpperCase()) {
    case 'BUY':
    case 'BID':
    case 'BIDS':
      return snapshot._copyWith(
        bids: _sortLevels(
          _upsertLevel(snapshot.bids, change.price, change.size),
          bid: true,
        ),
      );
    case 'SELL':
    case 'ASK':
    case 'ASKS':
      return snapshot._copyWith(
        asks: _sortLevels(
          _upsertLevel(snapshot.asks, change.price, change.size),
          bid: false,
        ),
      );
  }
  return snapshot;
}

List<Level> _upsertLevel(List<Level> levels, String price, String size) {
  if (price.trim().isEmpty) return levels;
  if (_isZeroSize(size)) {
    return levels
        .where((level) => level.price != price)
        .toList(growable: false);
  }

  var replaced = false;
  final out = <Level>[
    for (final level in levels)
      if (level.price == price) ...<Level>[
        Level(price: level.price, size: size),
      ] else
        level,
  ];
  replaced = levels.any((level) => level.price == price);
  if (!replaced) out.add(Level(price: price, size: size));
  return out;
}

bool _isZeroSize(String size) {
  final value = double.tryParse(size.trim());
  return value != null && value == 0;
}

List<Level> _sortLevels(List<Level> levels, {required bool bid}) {
  final out = List<Level>.of(levels);
  out.sort((left, right) {
    final leftPrice = double.tryParse(left.price.trim());
    final rightPrice = double.tryParse(right.price.trim());
    final leftOk = leftPrice != null;
    final rightOk = rightPrice != null;
    if (!leftOk || !rightOk) {
      if (leftOk == rightOk) return 0;
      return leftOk ? -1 : 1;
    }
    return bid
        ? rightPrice.compareTo(leftPrice)
        : leftPrice.compareTo(rightPrice);
  });
  return out;
}

Snapshot _refreshPrices(Snapshot snapshot) {
  final next = snapshot._copyWith(
    bestBid: _topPrice(snapshot.bids),
    bestAsk: _topPrice(snapshot.asks),
  );
  return _refreshMidpoint(next);
}

String _topPrice(List<Level> levels) =>
    levels.isEmpty ? '' : levels.first.price;

Snapshot _refreshMidpoint(Snapshot snapshot) => snapshot._copyWith(
  midpoint: _midpoint(snapshot.bestBid, snapshot.bestAsk) ?? '',
  spread: _spread(snapshot.bestBid, snapshot.bestAsk) ?? '',
);

String? _midpoint(String bid, String ask) {
  final bidValue = double.tryParse(bid.trim());
  final askValue = double.tryParse(ask.trim());
  if (bidValue == null || askValue == null) return null;
  return ((bidValue + askValue) / 2).toString();
}

String? _spread(String bid, String ask) {
  final bidValue = double.tryParse(bid.trim());
  final askValue = double.tryParse(ask.trim());
  if (bidValue == null || askValue == null) return null;
  return (askValue - bidValue).toString();
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value;
  }
  return '';
}
