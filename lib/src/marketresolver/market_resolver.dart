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
import '../marketdiscovery/market_filter.dart';
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
    final target = _normalizedOutcomeLabel(outcomeLabel);
    for (var i = 0; i < outcomes.length; i++) {
      if (_normalizedOutcomeLabel(outcomes[i]) == target) return tokenIds[i];
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

enum CryptoMarketCandidateRejection {
  notEnrichable,
  outcomeTokenCountMismatch,
  missingUpToken,
  missingDownToken,
  ambiguousUpOutcome,
  ambiguousDownOutcome,
}

@immutable
final class CryptoMarketCandidateInspection {
  const CryptoMarketCandidateInspection({
    required this.rejections,
    this.upTokenId = '',
    this.downTokenId = '',
  });

  final Set<CryptoMarketCandidateRejection> rejections;
  final String upTokenId;
  final String downTokenId;

  bool get isEligible => rejections.isEmpty;
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

@immutable
final class CryptoWindowRequest {
  const CryptoWindowRequest({
    required this.asset,
    required this.timeframe,
    required this.windowStart,
  });

  factory CryptoWindowRequest.from({
    required String asset,
    required String timeframe,
    required DateTime windowStart,
  }) {
    return CryptoWindowRequest(
      asset: normalizeCryptoAsset(asset),
      timeframe: normalizeCryptoTimeframe(timeframe),
      windowStart: _truncateToSecond(windowStart)!,
    );
  }

  final String asset;
  final String timeframe;
  final DateTime windowStart;
}

final class MarketResolver {
  MarketResolver({GammaClient? gamma}) : _gamma = gamma ?? GammaClient();

  final GammaClient _gamma;

  /// Closes the underlying Gamma transport.
  void close() => _gamma.close();

  /// Resolves active CLOB-enabled crypto up/down markets for [asset].
  Future<List<CryptoMarket>> resolveCryptoMarkets(String asset) async {
    final normalizedAsset = normalizeCryptoAsset(asset);
    final searches = await Future.wait(
      cryptoQueries(
        normalizedAsset,
      ).map((query) => _searchQuery(normalizedAsset, query)),
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
    final request = CryptoWindowRequest.from(
      asset: asset,
      timeframe: timeframe,
      windowStart: windowStart,
    );
    final slug = cryptoWindowSlug(
      request.asset,
      request.timeframe,
      request.windowStart,
    );
    if (slug.isNotEmpty) {
      final event = await _gamma.eventBySlug(slug);
      if (event != null) {
        final expected = request.windowStart;
        final result = _firstAcceptingMarketForWindow(
          request.asset,
          request.timeframe,
          expected,
          _marketsFromGammaWithSource(
            request.asset,
            event.resolutionSource,
            event.markets,
          ),
        );
        if (result != null) {
          if (result.startDate != expected) {
            return ResolveResult(
              status: MarketStatus.windowMismatch,
              asset: request.asset,
              timeframe: request.timeframe,
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
    return resolveTokenIds(request.asset, request.timeframe);
  }

  /// Strict window resolver for live-order paths. Never falls back from a
  /// deterministic slug miss to an unanchored search.
  Future<ResolveResult> resolveTokenIdsForWindow(
    String asset,
    String timeframe,
    DateTime windowStart,
  ) async {
    final request = CryptoWindowRequest.from(
      asset: asset,
      timeframe: timeframe,
      windowStart: windowStart,
    );
    final expected = request.windowStart;
    final slug = cryptoWindowSlug(request.asset, request.timeframe, expected);
    if (slug.isEmpty) {
      return ResolveResult(
        status: MarketStatus.unresolved,
        asset: request.asset,
        timeframe: request.timeframe,
        source: 'no_slug_for_asset_timeframe',
      );
    }
    final event = await _gamma.eventBySlug(slug);
    if (event == null) {
      return ResolveResult(
        status: MarketStatus.unresolved,
        asset: request.asset,
        timeframe: request.timeframe,
        source: 'gamma:slug_miss:$slug',
      );
    }
    final result = _firstAcceptingMarketForWindow(
      request.asset,
      request.timeframe,
      expected,
      _marketsFromGammaWithSource(
        request.asset,
        event.resolutionSource,
        event.markets,
      ),
    );
    if (result == null) {
      return ResolveResult(
        status: MarketStatus.unresolved,
        asset: request.asset,
        timeframe: request.timeframe,
        source: 'gamma:slug_event_no_accepting_market:$slug',
      );
    }
    if (result.startDate != expected) {
      return ResolveResult(
        status: MarketStatus.windowMismatch,
        asset: request.asset,
        timeframe: request.timeframe,
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
    final normalizedAsset = normalizeCryptoAsset(asset);
    final normalizedTimeframe = normalizeCryptoTimeframe(timeframe);
    try {
      final markets = await resolveCryptoMarkets(normalizedAsset);
      final result = _firstAcceptingMarket(
        normalizedAsset,
        normalizedTimeframe,
        markets,
      );
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
        asset: normalizedAsset,
        timeframe: normalizedTimeframe,
        source: 'gamma:no_match (found ${markets.length} markets)',
      );
    } on Object catch (error) {
      return ResolveResult(
        status: MarketStatus.unresolved,
        asset: normalizedAsset,
        timeframe: normalizedTimeframe,
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
    if (!shouldEnrichMarket(market)) continue;
    final tokenIds = parseClobTokenIds(market.clobTokenIds);
    final inspection = inspectCryptoMarketCandidate(market, tokenIds: tokenIds);
    if (!inspection.isEligible) continue;
    markets.add(
      CryptoMarket(
        conditionId: market.conditionId,
        asset: asset,
        timeframe: inferTimeframe(market.slug, market.question),
        upTokenId: inspection.upTokenId,
        downTokenId: inspection.downTokenId,
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
    if (_isAcceptingTimeframeMarket(market, timeframe)) {
      return _resolveResultForCryptoMarket(asset, timeframe, market);
    }
  }
  return null;
}

ResolveResult? _firstAcceptingMarketForWindow(
  String asset,
  String timeframe,
  DateTime expectedStart,
  List<CryptoMarket> markets,
) {
  ResolveResult? firstAccepting;
  for (final market in markets) {
    if (!_isAcceptingTimeframeMarket(market, timeframe)) continue;
    final result = _resolveResultForCryptoMarket(asset, timeframe, market);
    if (market.startDate == expectedStart) return result;
    firstAccepting ??= result;
  }
  return firstAccepting;
}

bool _isAcceptingTimeframeMarket(CryptoMarket market, String timeframe) =>
    market.timeframe == timeframe && market.accepting && !market.closed;

ResolveResult _resolveResultForCryptoMarket(
  String asset,
  String timeframe,
  CryptoMarket market,
) => ResolveResult(
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

DateTime? _cryptoMarketWindowStart(Market market) =>
    _truncateToSecond(market.eventStartTime ?? market.startDate);

/// Explains whether a Gamma market has exactly one usable up/down token pair.
CryptoMarketCandidateInspection inspectCryptoMarketCandidate(
  Market market, {
  List<String>? tokenIds,
}) {
  final rejections = <CryptoMarketCandidateRejection>{};
  if (!shouldEnrichMarket(market)) {
    rejections.add(CryptoMarketCandidateRejection.notEnrichable);
  }
  final ids = tokenIds ?? parseClobTokenIds(market.clobTokenIds);
  if (market.outcomes.length != ids.length) {
    rejections.add(CryptoMarketCandidateRejection.outcomeTokenCountMismatch);
  }

  var up = '';
  var down = '';
  var upCount = 0;
  var downCount = 0;
  final pairCount = market.outcomes.length < ids.length
      ? market.outcomes.length
      : ids.length;
  for (var i = 0; i < pairCount; i++) {
    final tokenId = ids[i];
    if (tokenId.isEmpty) continue;
    final outcome = _normalizedOutcomeLabel(market.outcomes[i]);
    if (_isUpOutcome(outcome)) {
      upCount++;
      up = tokenId;
    } else if (_isDownOutcome(outcome)) {
      downCount++;
      down = tokenId;
    }
  }

  if (upCount == 0) {
    rejections.add(CryptoMarketCandidateRejection.missingUpToken);
  }
  if (downCount == 0) {
    rejections.add(CryptoMarketCandidateRejection.missingDownToken);
  }
  if (upCount > 1) {
    rejections.add(CryptoMarketCandidateRejection.ambiguousUpOutcome);
  }
  if (downCount > 1) {
    rejections.add(CryptoMarketCandidateRejection.ambiguousDownOutcome);
  }

  return CryptoMarketCandidateInspection(
    rejections: Set.unmodifiable(rejections),
    upTokenId: rejections.isEmpty ? up : '',
    downTokenId: rejections.isEmpty ? down : '',
  );
}

String _normalizedOutcomeLabel(String value) => value.toLowerCase().trim();

bool _isUpOutcome(String normalizedOutcome) =>
    normalizedOutcome == 'up' || normalizedOutcome == 'yes';

bool _isDownOutcome(String normalizedOutcome) =>
    normalizedOutcome == 'down' || normalizedOutcome == 'no';

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
  final normalizedAsset = normalizeCryptoAsset(asset);
  final names = <String, List<String>>{
    'BTC': <String>['bitcoin'],
    'ETH': <String>['ethereum'],
    'SOL': <String>['solana'],
    'XRP': <String>['xrp'],
    'DOGE': <String>['doge'],
    'BNB': <String>['bnb'],
  };
  final nameList =
      names[normalizedAsset] ?? <String>[normalizedAsset.toLowerCase()];
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
  final normalizedTimeframe = normalizeCryptoTimeframe(timeframe);
  final prefix = prefixes[normalizeCryptoAsset(asset)];
  if (prefix == null) return '';
  if (!_supportedCryptoWindowTimeframes.contains(normalizedTimeframe)) {
    return '';
  }
  return '$prefix-updown-$normalizedTimeframe-${windowStart.toUtc().millisecondsSinceEpoch ~/ 1000}';
}

const Set<String> _supportedCryptoWindowTimeframes = <String>{
  '5m',
  '15m',
  '4h',
};

const List<(String, String)> _cryptoTimeframeAliases = <(String, String)>[
  ('15m', '15m'),
  ('15 min', '15m'),
  ('15-minute', '15m'),
  ('5m', '5m'),
  ('5 min', '5m'),
  ('5-minute', '5m'),
  ('4h', '4h'),
  ('4 hour', '4h'),
  ('4-hour', '4h'),
];

String inferTimeframe(String slug, String question) {
  final fromSlug = _inferTimeframeFromText(slug);
  if (fromSlug.isNotEmpty) return fromSlug;
  return _inferTimeframeFromText(question);
}

String _inferTimeframeFromText(String value) {
  final text = value.toLowerCase();
  for (final (alias, timeframe) in _cryptoTimeframeAliases) {
    if (text.contains(alias)) return timeframe;
  }
  return '';
}

/// Normalizes caller-supplied crypto resolver asset symbols.
String normalizeCryptoAsset(String value) => value.trim().toUpperCase();

/// Normalizes caller-supplied crypto resolver timeframe labels.
String normalizeCryptoTimeframe(String value) {
  final text = value.toLowerCase().trim();
  for (final (alias, timeframe) in _cryptoTimeframeAliases) {
    if (text == alias) return timeframe;
  }
  return text;
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
