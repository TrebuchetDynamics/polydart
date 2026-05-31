/// Composes Gamma + CLOB for "find liquid markets and price them" flows.
///
/// Mirrors `internal/marketdiscovery`: tick size, neg-risk, fee-rate,
/// midpoint, spread, last price, and order book enrichment.
library;

import 'package:meta/meta.dart';

import '../clob/clob_client.dart';
import '../gamma/gamma_client.dart';
import '../gamma/gamma_params.dart';
import '../marketresolver/market_resolver.dart';
import '../types/clob.dart';
import '../types/market.dart';
import 'market_filter.dart';

@immutable
final class EnrichedMarket {
  const EnrichedMarket({
    required this.market,
    this.tickSize,
    this.midpoint,
    this.spread,
    this.lastPrice,
    this.orderBook,
    this.negRisk,
    this.feeRateBps,
  });

  /// The Gamma view of the market.
  final Market market;

  /// CLOB tick / minimum-order metadata, when fetched.
  final TickSize? tickSize;

  /// Midpoint price (decimal string), when fetched.
  final String? midpoint;

  /// Bid-ask spread (decimal string), when fetched.
  final String? spread;

  /// Last trade price (decimal string), when fetched.
  final String? lastPrice;

  /// Top-of-book snapshot, when fetched.
  final OrderBook? orderBook;

  /// Whether the market is negative-risk, when fetched.
  final bool? negRisk;

  /// Maker fee rate in basis points, when fetched.
  final int? feeRateBps;
}

final class MarketDiscovery {
  MarketDiscovery({GammaClient? gamma, ClobClient? clob})
    : _gamma = gamma ?? GammaClient(),
      _clob = clob ?? ClobClient();

  final GammaClient _gamma;
  final ClobClient _clob;

  void close() {
    _gamma.close();
    _clob.close();
  }

  /// Fetches CLOB data for [market]'s first token id and returns an
  /// [EnrichedMarket]. Per-call CLOB failures are non-fatal — those
  /// fields stay null.
  Future<EnrichedMarket> enrichMarket(Market market) async {
    final tokenIds = parseClobTokenIds(market.clobTokenIds);
    if (tokenIds.isEmpty) return EnrichedMarket(market: market);

    final tokenId = tokenIds.first;

    final tickSize = _safe(() => _clob.tickSize(tokenId));
    final negRisk = _safe(() => _clob.negRisk(tokenId));
    final feeRateBps = _safe(() => _clob.feeRateBps(tokenId));
    final midpoint = _safe(() => _clob.midpoint(tokenId));
    final spread = _safe(() => _clob.spread(tokenId));
    final lastPrice = _safe(() => _clob.lastTradePrice(tokenId));
    final orderBook = _safe(() => _clob.orderBook(tokenId));

    return EnrichedMarket(
      market: market,
      tickSize: await tickSize,
      midpoint: await midpoint,
      spread: await spread,
      lastPrice: await lastPrice,
      orderBook: await orderBook,
      negRisk: await negRisk,
      feeRateBps: await feeRateBps,
    );
  }

  /// Lists active Gamma markets and enriches each.
  ///
  /// Markets that fail enrichment are still returned — only the CLOB
  /// fields are null.
  Future<List<EnrichedMarket>> enrichedMarkets({int limit = 50}) async {
    final markets = await _gamma.markets(
      GetMarketsParams(active: true, closed: false, limit: limit),
    );
    final out = <EnrichedMarket>[];
    for (final m in markets) {
      if (!shouldEnrichMarket(m)) continue;
      out.add(await enrichMarket(m));
    }
    return out;
  }

  /// Searches Gamma, fetches each full event by slug, then enriches attached
  /// markets. This mirrors polygolem because Gamma search events may omit the
  /// complete market list.
  Future<List<EnrichedMarket>> searchAndEnrich(
    String query, {
    int limit = 5,
  }) async {
    final resp = await _gamma.search(
      SearchParams(query: query, limitPerType: limit),
    );
    final out = <EnrichedMarket>[];
    for (final evt in resp.events) {
      final fullEvent = await _safe(() => _gamma.eventBySlug(evt.slug));
      if (fullEvent == null) continue;
      for (final m in fullEvent.markets) {
        if (!shouldEnrichMarket(m)) continue;
        out.add(await enrichMarket(m));
      }
    }
    return out;
  }

  static Future<T?> _safe<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on Exception {
      return null;
    }
  }
}
