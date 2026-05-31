/// Market-detail bundle composition helpers.

library;

import '../clob/clob_auth_types.dart';
import '../clob/clob_client.dart';
import '../clob/clob_params.dart';
import '../gamma/gamma_client.dart';
import '../gamma/gamma_params.dart';
import '../types/clob.dart';
import '../types/clob_token_ids.dart';
import '../types/market.dart';

// ---------------------------------------------------------------------------
// MarketDetailBundle — composite detail fetch result
// ---------------------------------------------------------------------------

/// One fetch result inside a [MarketDetailBundle].
///
/// Carries either a value or the error that occurred, so consumers can
/// render partial data gracefully.
final class BundleField<T> {
  const BundleField._({required this.value, this.error});

  /// Factory for a successful fetch.
  factory BundleField.ok(T value) => BundleField._(value: value);

  /// Factory for a failed fetch.
  factory BundleField.err(Object error) =>
      BundleField._(value: null, error: error);

  /// The value when the fetch succeeded, or `null` on failure.
  final T? value;

  /// The error when the fetch failed, or `null` on success.
  final Object? error;

  /// Whether the fetch succeeded.
  bool get isOk => error == null;

  /// Whether the fetch failed.
  bool get isError => error != null;

  @override
  String toString() =>
      isOk ? 'BundleField.ok($value)' : 'BundleField.err($error)';
}

/// Composite result of fetching all data for a market detail screen.
///
/// Every field is individually nullable — a failed order-book fetch does not
/// prevent trades or market data from being available.
final class MarketDetailBundle {
  const MarketDetailBundle({
    required this.market,
    required this.event,
    required this.orderBooks,
    required this.priceHistory,
    required this.trades,
    required this.elapsed,
  });

  final BundleField<Market> market;
  final BundleField<Event?> event;
  final BundleField<Map<String, OrderBook>> orderBooks;
  final BundleField<Map<String, PriceHistory>> priceHistory;
  final BundleField<List<TradeRecord>> trades;
  final Duration elapsed;
}

/// Fetches [MarketDetailBundle] — market + event + order books + trades +
/// price history — with per-field error resilience.
class MarketDetailFetcher {
  /// Fetches all detail-screen data for the market identified by [conditionId].
  static Future<MarketDetailBundle> fetch({
    required GammaClient gamma,
    required ClobClient clob,
    required String conditionId,
    List<String>? tokenIds,
    String priceHistoryInterval = '1h',
  }) async {
    final stopwatch = Stopwatch()..start();
    final normalizedConditionId = conditionId.trim();

    final marketField = await _fetchMarket(gamma, normalizedConditionId);
    final candidateData = _MarketDetailCandidateData.from(
      marketField: marketField,
      explicitTokenIds: tokenIds,
      priceHistoryInterval: priceHistoryInterval,
    );
    final effectiveTokenIds = candidateData.tokenIds;
    final effectiveInterval = candidateData.priceHistoryInterval;

    BundleField<Event?> eventField;
    BundleField<Map<String, OrderBook>> orderBooksField;
    BundleField<Map<String, PriceHistory>> priceHistoryField;
    BundleField<List<TradeRecord>> tradesField;

    try {
      eventField = await _fetchEvent(gamma, marketField, normalizedConditionId);
    } catch (e) {
      eventField = BundleField.err(e);
    }
    try {
      orderBooksField = await _fetchOrderBooks(clob, effectiveTokenIds);
    } catch (e) {
      orderBooksField = BundleField.err(e);
    }
    try {
      priceHistoryField = await _fetchPriceHistory(
        clob,
        effectiveTokenIds,
        effectiveInterval,
      );
    } catch (e) {
      priceHistoryField = BundleField.err(e);
    }
    try {
      tradesField = await _fetchTrades(clob, effectiveTokenIds);
    } catch (e) {
      tradesField = BundleField.err(e);
    }

    stopwatch.stop();
    return MarketDetailBundle(
      market: marketField,
      event: eventField,
      orderBooks: orderBooksField,
      priceHistory: priceHistoryField,
      trades: tradesField,
      elapsed: stopwatch.elapsed,
    );
  }

  static Future<BundleField<Market>> _fetchMarket(
    GammaClient gamma,
    String conditionId,
  ) async {
    try {
      final markets = await gamma.markets(
        GetMarketsParams(conditionIds: [conditionId], limit: 1),
      );
      if (markets.isEmpty) {
        return BundleField.err(Exception('Market not found: $conditionId'));
      }
      return BundleField.ok(markets.first);
    } catch (e) {
      return BundleField.err(e);
    }
  }

  static Future<BundleField<Event?>> _fetchEvent(
    GammaClient gamma,
    BundleField<Market> marketField,
    String conditionId,
  ) async {
    if (!marketField.isOk) return BundleField.ok(null);
    final market = marketField.value!;
    if (market.events.isNotEmpty) {
      final eventId = market.events.first.id.trim();
      if (eventId.isNotEmpty) {
        final event = await gamma.eventById(eventId);
        if (event != null) return BundleField.ok(event);
      }
    }
    final slug = market.slug.trim();
    if (slug.isNotEmpty && slug != conditionId) {
      final event = await gamma.eventBySlug(slug);
      if (event != null) return BundleField.ok(event);
    }
    return BundleField.ok(null);
  }

  static Future<BundleField<Map<String, OrderBook>>> _fetchOrderBooks(
    ClobClient clob,
    List<String> tokenIds,
  ) async {
    if (tokenIds.isEmpty) return BundleField.ok(const {});
    final books = await clob.orderBooks(
      tokenIds.map((id) => BookParams(tokenId: id)).toList(),
    );
    final result = <String, OrderBook>{};
    for (final book in books) {
      final key = book.assetId.isNotEmpty ? book.assetId : '';
      if (key.isNotEmpty) result[key] = book;
    }
    return BundleField.ok(result);
  }

  static Future<BundleField<Map<String, PriceHistory>>> _fetchPriceHistory(
    ClobClient clob,
    List<String> tokenIds,
    String interval,
  ) async {
    if (tokenIds.isEmpty || interval.isEmpty) {
      return BundleField.ok(const {});
    }
    final result = <String, PriceHistory>{};
    for (final tokenId in tokenIds) {
      try {
        result[tokenId] = await clob.pricesHistory(
          PriceHistoryParams(market: tokenId, interval: interval),
        );
      } catch (_) {}
    }
    return BundleField.ok(result);
  }

  static Future<BundleField<List<TradeRecord>>> _fetchTrades(
    ClobClient clob,
    List<String> tokenIds,
  ) async {
    if (tokenIds.isEmpty) return BundleField.ok(const []);
    final allTrades = <TradeRecord>[];
    for (final tokenId in tokenIds) {
      try {
        allTrades.addAll(await clob.publicTrades(market: tokenId));
      } catch (_) {}
    }
    final seen = <String>{};
    final deduped = <TradeRecord>[];
    for (final TradeRecord trade in allTrades) {
      if (seen.add(_tradeDedupKey(trade))) {
        deduped.add(trade);
      }
    }
    deduped.sort(
      (TradeRecord a, TradeRecord b) => b.createdAt.compareTo(a.createdAt),
    );
    return BundleField.ok(deduped);
  }

  static String _tradeDedupKey(TradeRecord trade) {
    final id = trade.id.trim();
    if (id.isNotEmpty) return 'id:$id';
    return [
      'fallback',
      trade.transactionHash.trim(),
      trade.market.trim(),
      trade.assetId.trim(),
      trade.side.trim(),
      trade.price.trim(),
      trade.size.trim(),
      trade.createdAt.trim(),
    ].join('|');
  }
}

/// Replayable candidate inputs derived before detail-field fanout.
final class _MarketDetailCandidateData {
  const _MarketDetailCandidateData({
    required this.tokenIds,
    required this.priceHistoryInterval,
  });

  final List<String> tokenIds;
  final String priceHistoryInterval;

  factory _MarketDetailCandidateData.from({
    required BundleField<Market> marketField,
    required List<String>? explicitTokenIds,
    required String priceHistoryInterval,
  }) {
    return _MarketDetailCandidateData(
      tokenIds:
          explicitTokenIds ??
          (marketField.isOk
              ? _tokenIdsFromMarket(marketField.value!)
              : const <String>[]),
      priceHistoryInterval: priceHistoryInterval,
    );
  }

  static List<String> _tokenIdsFromMarket(Market market) {
    if (market.tokenIds.isNotEmpty) return market.tokenIds;
    if (market.tokens.isNotEmpty) {
      return market.tokens.map((t) => t.tokenId).toList(growable: false);
    }
    return parseClobTokenIds(market.clobTokenIds);
  }
}
