/// Resolves a Polymarket slug or id into the canonical token / condition ids
/// needed to place an order or read a book.
///
/// Mirrors the read-side of `pkg/marketresolver`, including crypto up/down
/// helpers that resolve asset/timeframe windows into up/down token IDs.
library;

import 'dart:convert';

import 'package:meta/meta.dart';

import '../gamma/gamma_client.dart';
import '../gamma/gamma_params.dart';
import '../types/market.dart';

@immutable
final class ResolvedMarket {
  const ResolvedMarket({
    required this.conditionId,
    required this.questionId,
    required this.slug,
    required this.question,
    required this.outcomes,
    required this.tokenIds,
    required this.acceptingOrders,
    required this.closed,
    required this.archived,
    required this.enableOrderBook,
  });

  final String conditionId;
  final String questionId;
  final String slug;
  final String question;
  final List<String> outcomes;
  final List<String> tokenIds;
  final bool acceptingOrders;
  final bool closed;
  final bool archived;
  final bool enableOrderBook;

  /// True when [outcomes] and [tokenIds] line up and the market is taking
  /// orders — a strict precondition for live trading flows.
  bool get isAvailable =>
      acceptingOrders &&
      !closed &&
      !archived &&
      enableOrderBook &&
      outcomes.length == tokenIds.length &&
      tokenIds.isNotEmpty;

  /// Token id matching the supplied outcome label (case-insensitive).
  String? tokenIdFor(String outcomeLabel) {
    if (outcomes.length != tokenIds.length) return null;
    final target = outcomeLabel.toLowerCase().trim();
    for (var i = 0; i < outcomes.length; i++) {
      if (outcomes[i].toLowerCase().trim() == target) return tokenIds[i];
    }
    return null;
  }

  /// Token id for the canonical "yes/up" outcome, if present.
  String? get yesTokenId =>
      tokenIdFor('yes') ?? tokenIdFor('up') ?? tokenIdFor('over');

  /// Token id for the canonical "no/down" outcome, if present.
  String? get noTokenId =>
      tokenIdFor('no') ?? tokenIdFor('down') ?? tokenIdFor('under');
}

@immutable
final class CryptoMarket {
  const CryptoMarket({
    required this.conditionId,
    required this.asset,
    required this.timeframe,
    required this.upTokenId,
    required this.downTokenId,
    required this.accepting,
    required this.closed,
    required this.question,
    required this.slug,
    this.resolutionSource = '',
    this.minOrderSize = 0,
    this.tickSize = 0,
    this.startDate,
    this.endDate,
  });

  final String conditionId;
  final String asset;
  final String timeframe;
  final String upTokenId;
  final String downTokenId;
  final bool accepting;
  final bool closed;
  final String question;
  final String slug;
  final String resolutionSource;
  final double minOrderSize;
  final double tickSize;
  final DateTime? startDate;
  final DateTime? endDate;
}

enum MarketStatus {
  available('available'),
  unavailable('unavailable'),
  staleToken('stale_token'),
  unresolved('unresolved'),
  windowMismatch('window_mismatch');

  const MarketStatus(this.value);

  final String value;
}

@immutable
final class ResolveResult {
  const ResolveResult({
    required this.status,
    this.upTokenId = '',
    this.downTokenId = '',
    this.conditionId = '',
    this.asset = '',
    this.timeframe = '',
    this.question = '',
    this.slug = '',
    this.resolutionSource = '',
    this.minOrderSize = 0,
    this.tickSize = 0,
    this.source = '',
    this.startDate,
    this.endDate,
  });

  final MarketStatus status;
  final String upTokenId;
  final String downTokenId;
  final String conditionId;
  final String asset;
  final String timeframe;
  final String question;
  final String slug;
  final String resolutionSource;
  final double minOrderSize;
  final double tickSize;
  final String source;
  final DateTime? startDate;
  final DateTime? endDate;
}

final class MarketResolver {
  MarketResolver({GammaClient? gamma}) : _gamma = gamma ?? GammaClient();

  final GammaClient _gamma;

  /// Closes the underlying Gamma transport.
  void close() => _gamma.close();

  /// Resolves active CLOB-enabled crypto up/down markets for [asset].
  Future<List<CryptoMarket>> resolveCryptoMarkets(String asset) async {
    final searches = await Future.wait(
      cryptoQueries(
        asset.toUpperCase(),
      ).map((query) => _searchQuery(asset, query)),
    );
    final seen = <String>{};
    final out = <CryptoMarket>[];
    for (final market in searches.expand((x) => x)) {
      if (seen.add(market.conditionId)) out.add(market);
    }
    out.sort((a, b) {
      final assetCmp = a.asset.compareTo(b.asset);
      if (assetCmp != 0) return assetCmp;
      return a.timeframe.compareTo(b.timeframe);
    });
    return out;
  }

  /// Resolves token IDs for a specific crypto window, falling back to a broad
  /// asset/timeframe search only when the deterministic slug misses.
  Future<ResolveResult> resolveTokenIdsAt(
    String asset,
    String timeframe,
    DateTime windowStart,
  ) async {
    final slug = cryptoWindowSlug(asset, timeframe, windowStart);
    if (slug.isNotEmpty) {
      final event = await _gamma.eventBySlug(slug);
      if (event != null) {
        final result = _firstAcceptingMarket(
          asset,
          timeframe,
          _marketsFromGammaWithSource(
            asset,
            event.resolutionSource,
            event.markets,
          ),
        );
        if (result != null) {
          final expected = _truncateToSecond(windowStart);
          if (expected != null && result.startDate != expected) {
            return ResolveResult(
              status: MarketStatus.windowMismatch,
              asset: asset,
              timeframe: timeframe,
              startDate: result.startDate,
              endDate: result.endDate,
              source:
                  'gamma:slug_hit_window_mismatch:$slug:got=${_rfc3339(result.startDate)} want=${_rfc3339(expected)}',
            );
          }
          return ResolveResult(
            status: result.status,
            upTokenId: result.upTokenId,
            downTokenId: result.downTokenId,
            conditionId: result.conditionId,
            asset: result.asset,
            timeframe: result.timeframe,
            question: result.question,
            slug: result.slug,
            resolutionSource: result.resolutionSource,
            minOrderSize: result.minOrderSize,
            tickSize: result.tickSize,
            source: 'gamma:event_slug:$slug',
            startDate: result.startDate,
            endDate: result.endDate,
          );
        }
      }
    }
    return resolveTokenIds(asset, timeframe);
  }

  /// Strict window resolver for live-order paths. Never falls back from a
  /// deterministic slug miss to an unanchored search.
  Future<ResolveResult> resolveTokenIdsForWindow(
    String asset,
    String timeframe,
    DateTime windowStart,
  ) async {
    final expected = _truncateToSecond(windowStart);
    if (expected == null) {
      return ResolveResult(
        status: MarketStatus.unresolved,
        asset: asset,
        timeframe: timeframe,
        source: 'windowStart_zero',
      );
    }
    final slug = cryptoWindowSlug(asset, timeframe, expected);
    if (slug.isEmpty) {
      return ResolveResult(
        status: MarketStatus.unresolved,
        asset: asset,
        timeframe: timeframe,
        source: 'no_slug_for_asset_timeframe',
      );
    }
    final event = await _gamma.eventBySlug(slug);
    if (event == null) {
      return ResolveResult(
        status: MarketStatus.unresolved,
        asset: asset,
        timeframe: timeframe,
        source: 'gamma:slug_miss:$slug',
      );
    }
    final result = _firstAcceptingMarket(
      asset,
      timeframe,
      _marketsFromGammaWithSource(asset, event.resolutionSource, event.markets),
    );
    if (result == null) {
      return ResolveResult(
        status: MarketStatus.unresolved,
        asset: asset,
        timeframe: timeframe,
        source: 'gamma:slug_event_no_accepting_market:$slug',
      );
    }
    if (result.startDate != expected) {
      return ResolveResult(
        status: MarketStatus.windowMismatch,
        asset: asset,
        timeframe: timeframe,
        startDate: result.startDate,
        endDate: result.endDate,
        source:
            'gamma:slug_hit_window_mismatch:$slug:got=${_rfc3339(result.startDate)} want=${_rfc3339(expected)}',
      );
    }
    return ResolveResult(
      status: result.status,
      upTokenId: result.upTokenId,
      downTokenId: result.downTokenId,
      conditionId: result.conditionId,
      asset: result.asset,
      timeframe: result.timeframe,
      question: result.question,
      slug: result.slug,
      resolutionSource: result.resolutionSource,
      minOrderSize: result.minOrderSize,
      tickSize: result.tickSize,
      source: 'gamma:event_slug_strict:$slug',
      startDate: result.startDate,
      endDate: result.endDate,
    );
  }

  /// Resolves token IDs for [asset] and [timeframe] through broad Gamma search.
  Future<ResolveResult> resolveTokenIds(String asset, String timeframe) async {
    try {
      final markets = await resolveCryptoMarkets(asset);
      final result = _firstAcceptingMarket(asset, timeframe, markets);
      if (result != null) {
        return ResolveResult(
          status: result.status,
          upTokenId: result.upTokenId,
          downTokenId: result.downTokenId,
          conditionId: result.conditionId,
          asset: result.asset,
          timeframe: result.timeframe,
          question: result.question,
          slug: result.slug,
          resolutionSource: result.resolutionSource,
          minOrderSize: result.minOrderSize,
          tickSize: result.tickSize,
          source: 'gamma:crypto_search',
          startDate: result.startDate,
          endDate: result.endDate,
        );
      }
      return ResolveResult(
        status: MarketStatus.unresolved,
        asset: asset,
        timeframe: timeframe,
        source: 'gamma:no_match (found ${markets.length} markets)',
      );
    } on Object catch (error) {
      return ResolveResult(
        status: MarketStatus.unresolved,
        asset: asset,
        timeframe: timeframe,
        source: 'gamma_error:$error',
      );
    }
  }

  /// Basic token-id validation matching polygolem's resolver layer.
  MarketStatus validateToken(String tokenId) {
    if (tokenId.isEmpty) return MarketStatus.unresolved;
    return int.tryParse(tokenId) == null
        ? MarketStatus.unresolved
        : MarketStatus.available;
  }

  Future<List<CryptoMarket>> _searchQuery(String asset, String query) async {
    final response = await _gamma.search(
      SearchParams(query: query, limitPerType: 20, eventsStatus: 'active'),
    );
    final out = <CryptoMarket>[];
    for (final event in response.events) {
      var markets = event.markets;
      if (markets.isEmpty) {
        if (event.slug.isEmpty) continue;
        final fullEvent = await _gamma.eventBySlug(event.slug);
        if (fullEvent == null) continue;
        markets = fullEvent.markets;
      }
      for (final market in markets) {
        out.addAll(
          _marketsFromGammaWithSource(asset, event.resolutionSource, <Market>[
            market,
          ]),
        );
      }
    }
    return out;
  }

  /// Resolves by Gamma slug. Returns null if Gamma returns no record.
  Future<ResolvedMarket?> resolveBySlug(String slug) async {
    final m = await _gamma.marketBySlug(slug);
    if (m == null) return null;
    return _fromMarket(m);
  }

  /// Resolves by Gamma id.
  Future<ResolvedMarket?> resolveById(String id) async {
    final m = await _gamma.marketById(id);
    if (m == null) return null;
    return _fromMarket(m);
  }

  static ResolvedMarket _fromMarket(Market m) => ResolvedMarket(
    conditionId: m.conditionId,
    questionId: m.questionId,
    slug: m.slug,
    question: m.question,
    outcomes: m.outcomes,
    tokenIds: parseClobTokenIds(m.clobTokenIds),
    acceptingOrders: m.acceptingOrders,
    closed: m.closed,
    archived: m.archived,
    enableOrderBook: m.enableOrderBook,
  );
}

List<CryptoMarket> _marketsFromGammaWithSource(
  String asset,
  String fallbackResolutionSource,
  List<Market> gammaMarkets,
) {
  final markets = <CryptoMarket>[];
  for (final market in gammaMarkets) {
    if (!market.active || market.closed || !market.enableOrderBook) continue;
    final tokenIds = parseClobTokenIds(market.clobTokenIds);
    final (up, down) = _findUpDownTokenIds(market.outcomes, tokenIds);
    if (up.isEmpty || down.isEmpty) continue;
    markets.add(
      CryptoMarket(
        conditionId: market.conditionId,
        asset: asset,
        timeframe: inferTimeframe(market.slug, market.question),
        upTokenId: up,
        downTokenId: down,
        accepting: market.acceptingOrders,
        closed: market.closed,
        question: market.question,
        slug: market.slug,
        resolutionSource: _firstNonEmpty(
          market.resolutionSource,
          fallbackResolutionSource,
        ),
        minOrderSize: market.orderMinSize,
        tickSize: market.orderPriceMinTickSize,
        startDate: _cryptoMarketWindowStart(market),
        endDate: _truncateToSecond(market.endDate),
      ),
    );
  }
  return markets;
}

ResolveResult? _firstAcceptingMarket(
  String asset,
  String timeframe,
  List<CryptoMarket> markets,
) {
  for (final market in markets) {
    if (market.timeframe == timeframe && market.accepting && !market.closed) {
      return ResolveResult(
        status: MarketStatus.available,
        upTokenId: market.upTokenId,
        downTokenId: market.downTokenId,
        conditionId: market.conditionId,
        asset: asset,
        timeframe: timeframe,
        question: market.question,
        slug: market.slug,
        resolutionSource: market.resolutionSource,
        minOrderSize: market.minOrderSize,
        tickSize: market.tickSize,
        startDate: market.startDate,
        endDate: market.endDate,
      );
    }
  }
  return null;
}

DateTime? _cryptoMarketWindowStart(Market market) =>
    _truncateToSecond(market.eventStartTime ?? market.startDate);

(String, String) _findUpDownTokenIds(
  List<String> outcomes,
  List<String> tokenIds,
) {
  if (outcomes.length != tokenIds.length) return ('', '');
  var up = '';
  var down = '';
  for (var i = 0; i < outcomes.length; i++) {
    switch (outcomes[i].toLowerCase()) {
      case 'up':
      case 'yes':
        up = tokenIds[i];
      case 'down':
      case 'no':
        down = tokenIds[i];
    }
  }
  return (up, down);
}

String _firstNonEmpty(String a, String b) {
  final first = a.trim();
  if (first.isNotEmpty) return first;
  return b.trim();
}

DateTime? _truncateToSecond(DateTime? value) {
  if (value == null) return null;
  final utc = value.toUtc();
  return DateTime.utc(
    utc.year,
    utc.month,
    utc.day,
    utc.hour,
    utc.minute,
    utc.second,
  );
}

String _rfc3339(DateTime? value) =>
    value == null ? '' : value.toUtc().toIso8601String();

/// Crypto search queries used by the Go resolver.
List<String> cryptoQueries(String asset) {
  final names = <String, List<String>>{
    'BTC': <String>['bitcoin'],
    'ETH': <String>['ethereum'],
    'SOL': <String>['solana'],
    'XRP': <String>['xrp'],
    'DOGE': <String>['doge'],
    'BNB': <String>['bnb'],
  };
  final nameList = names[asset.toUpperCase()] ?? <String>[asset.toLowerCase()];
  return <String>[
    for (final name in nameList)
      for (final timeframe in const <String>['5m', '15m']) '$name $timeframe',
  ];
}

/// Deterministic Polymarket crypto up/down event slug.
String cryptoWindowSlug(String asset, String timeframe, DateTime windowStart) {
  final prefixes = <String, String>{
    'BTC': 'btc',
    'ETH': 'eth',
    'SOL': 'sol',
    'XRP': 'xrp',
    'DOGE': 'doge',
    'BNB': 'bnb',
    'HYPE': 'hype',
  };
  final prefix = prefixes[asset.toUpperCase()];
  if (prefix == null) return '';
  if (!const <String>{'5m', '15m', '4h'}.contains(timeframe)) return '';
  return '$prefix-updown-$timeframe-${windowStart.toUtc().millisecondsSinceEpoch ~/ 1000}';
}

String inferTimeframe(String slug, String question) {
  final text = '${slug.toLowerCase()} ${question.toLowerCase()}';
  for (final timeframe in const <String>[
    '15m',
    '15 min',
    '15-minute',
    '5m',
    '5 min',
    '5-minute',
  ]) {
    if (text.contains(timeframe)) {
      return timeframe.startsWith('5') ? '5m' : '15m';
    }
  }
  return '';
}

/// Parses Gamma's `clobTokenIds` field — a JSON-encoded array of strings
/// stored as a string. Tolerant of empty / `[]` / malformed input.
List<String> parseClobTokenIds(String raw) {
  final s = raw.trim();
  if (s.isEmpty || s == '[]' || s == 'null') return const <String>[];

  try {
    final decoded = jsonDecode(s);
    if (decoded is List) {
      return decoded
          .map(_trimmedTokenId)
          .where((tokenId) => tokenId.isNotEmpty)
          .toList(growable: false);
    }
  } on FormatException {
    // fall through to manual parse for legacy payloads
  }

  final out = <String>[];
  final buffer = StringBuffer();
  var inQuote = false;
  for (final code in s.runes) {
    final c = String.fromCharCode(code);
    if (c == '"') {
      inQuote = !inQuote;
      if (!inQuote) {
        final tokenId = _trimmedTokenId(buffer.toString());
        if (tokenId.isNotEmpty) out.add(tokenId);
        buffer.clear();
      }
    } else if (inQuote) {
      buffer.write(c);
    }
  }
  return out;
}

String _trimmedTokenId(Object? value) => value?.toString().trim() ?? '';
