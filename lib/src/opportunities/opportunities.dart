/// Read-only opportunity scanners for Polymarket research candidates.
///
/// Mirrors polygolem `internal/workflows/opportunities`. Results are discovery
/// hints only, not trading advice, and no live mutation path is provided.
library;

import '../gamma/gamma_params.dart';
import '../marketresolver/market_resolver.dart' show cryptoWindowSlug;
import '../types/clob_token_ids.dart' show parseClobTokenIds;
import '../types/market.dart' show Event, Market;

const String opportunityTypeWideSpread = 'wide-spread';
const String opportunityTypeLowLiquidityHighVolume =
    'low-liquidity-high-volume';
const String opportunityTypeNewMarkets = 'new-markets';
const String opportunityTypeClosingSoon = 'closing-soon';
const String opportunityTypeNegativeRisk = 'negative-risk';
const String opportunityTypeCrypto5m = 'crypto-5m';

const List<String> supportedCrypto5mAssets = <String>[
  'BTC',
  'ETH',
  'SOL',
  'XRP',
  'BNB',
  'DOGE',
  'HYPE',
];

abstract interface class OpportunityMarketLister {
  Future<List<Market>> markets([GetMarketsParams params]);
}

abstract interface class OpportunityEventFetcher {
  Future<Event?> eventBySlug(String slug);
}

abstract interface class OpportunityPricer {
  Future<String> price(String tokenId, String side);
  Future<String> spread(String tokenId);
}

final class OpportunityConfig {
  const OpportunityConfig({required this.gamma, this.events, this.pricer});

  final OpportunityMarketLister gamma;
  final OpportunityEventFetcher? events;
  final OpportunityPricer? pricer;
}

final class OpportunityRequest {
  const OpportunityRequest({
    this.type = '',
    this.limit = 0,
    this.hours = 0,
    this.asset = '',
  });

  final String type;
  final int limit;
  final int hours;
  final String asset;
}

final class OpportunityResponse {
  const OpportunityResponse({
    required this.type,
    required this.count,
    required this.opportunities,
  });

  final String type;
  final int count;
  final List<Opportunity> opportunities;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'count': count,
    'opportunities': opportunities.map((o) => o.toJson()).toList(),
  };
}

final class Opportunity {
  const Opportunity({
    required this.type,
    this.marketId = '',
    this.question = '',
    this.slug = '',
    this.conditionId = '',
    this.tokenIds = const <String>[],
    this.endDate = '',
    this.asset = '',
    this.volume24hr = 0,
    this.liquidity = 0,
    this.liquidityClob = 0,
    this.spread = 0,
    this.price = '',
    this.spreadText = '',
    this.reasons = const <String>[],
  });

  final String type;
  final String marketId;
  final String question;
  final String slug;
  final String conditionId;
  final List<String> tokenIds;
  final String endDate;
  final String asset;
  final double volume24hr;
  final double liquidity;
  final double liquidityClob;
  final double spread;
  final String price;
  final String spreadText;
  final List<String> reasons;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'market_id': marketId,
    'question': question,
    if (slug.isNotEmpty) 'slug': slug,
    if (conditionId.isNotEmpty) 'condition_id': conditionId,
    if (tokenIds.isNotEmpty) 'token_ids': tokenIds,
    if (endDate.isNotEmpty) 'end_date': endDate,
    if (asset.isNotEmpty) 'asset': asset,
    if (volume24hr != 0) 'volume_24h': volume24hr,
    if (liquidity != 0) 'liquidity': liquidity,
    if (liquidityClob != 0) 'liquidity_clob': liquidityClob,
    if (spread != 0) 'spread': spread,
    if (price.isNotEmpty) 'price': price,
    if (spreadText.isNotEmpty) 'clob_spread': spreadText,
    'reasons': reasons,
  };
}

final class OpportunityRunner {
  OpportunityRunner(OpportunityConfig config)
    : _gamma = config.gamma,
      _events = config.events ?? _eventsFromGamma(config.gamma),
      _pricer = config.pricer;

  final OpportunityMarketLister _gamma;
  final OpportunityEventFetcher? _events;
  final OpportunityPricer? _pricer;

  DateTime Function() now = () => DateTime.now().toUtc();

  Future<OpportunityResponse> run(OpportunityRequest req) async {
    final scannerType = req.type.isEmpty ? opportunityTypeWideSpread : req.type;
    if (scannerType == opportunityTypeCrypto5m) {
      return _runCrypto5m(req);
    }
    final markets = await _activeMarkets(req.limit);
    final opportunities = switch (scannerType) {
      opportunityTypeWideSpread => _wideSpread(markets),
      opportunityTypeLowLiquidityHighVolume => _lowLiquidityHighVolume(markets),
      opportunityTypeNewMarkets => _newMarkets(markets),
      opportunityTypeClosingSoon => _closingSoon(markets, now(), req.hours),
      opportunityTypeNegativeRisk => _negativeRisk(markets),
      _ => throw ArgumentError.value(
        scannerType,
        'type',
        'unknown opportunity type',
      ),
    };
    final limited = _limit(opportunities, _normalizedLimit(req.limit));
    return OpportunityResponse(
      type: scannerType,
      count: limited.length,
      opportunities: limited,
    );
  }

  Future<List<Market>> _activeMarkets(int limit) => _gamma.markets(
    GetMarketsParams(
      active: true,
      closed: false,
      limit: _scanFetchLimit(limit),
    ),
  );

  Future<OpportunityResponse> _runCrypto5m(OpportunityRequest req) async {
    final events = _events;
    if (events == null) {
      throw StateError('crypto-5m opportunities require Gamma event lookup');
    }
    final assets = req.asset.trim().isEmpty
        ? supportedCrypto5mAssets
        : <String>[req.asset.trim().toUpperCase()];
    final windowStart = _windowStartAt5m(now());
    final opportunities = <Opportunity>[];
    for (final asset in assets) {
      final slug = cryptoWindowSlug(asset, '5m', windowStart);
      if (slug.isEmpty) continue;
      final event = await events.eventBySlug(slug);
      if (event == null) continue;
      for (final market in event.markets) {
        if (!market.active || market.closed) continue;
        final tokenIds = parseClobTokenIds(market.clobTokenIds);
        var price = '';
        var spread = '';
        final pricer = _pricer;
        if (pricer != null && tokenIds.isNotEmpty) {
          try {
            price = await pricer.price(tokenIds.first, 'BUY');
          } on Object {
            price = '';
          }
          try {
            spread = await pricer.spread(tokenIds.first);
          } on Object {
            spread = '';
          }
        }
        opportunities.add(
          Opportunity(
            type: opportunityTypeCrypto5m,
            asset: asset,
            marketId: market.id,
            question: market.question,
            slug: event.slug,
            conditionId: market.conditionId,
            tokenIds: tokenIds,
            endDate: market.endDateIso,
            price: price,
            spreadText: spread,
            reasons: const <String>['active 5-minute crypto market'],
          ),
        );
        break;
      }
    }
    final limited = _limit(opportunities, _normalizedLimit(req.limit));
    return OpportunityResponse(
      type: opportunityTypeCrypto5m,
      count: limited.length,
      opportunities: limited,
    );
  }
}

OpportunityEventFetcher? _eventsFromGamma(OpportunityMarketLister gamma) {
  if (gamma is OpportunityEventFetcher) return gamma as OpportunityEventFetcher;
  return null;
}

List<Opportunity> _wideSpread(List<Market> markets) {
  final opportunities = <Opportunity>[];
  for (final market in markets) {
    if (!market.active || market.closed || market.spread <= 0) continue;
    opportunities.add(
      _opportunityFromMarket(
        opportunityTypeWideSpread,
        market,
        'spread ${market.spread.toStringAsFixed(4)}',
      ),
    );
  }
  opportunities.sort((a, b) => b.spread.compareTo(a.spread));
  return opportunities;
}

List<Opportunity> _lowLiquidityHighVolume(List<Market> markets) {
  final opportunities = <Opportunity>[];
  for (final market in markets) {
    if (!market.active || market.closed || market.volume24hr <= 0) continue;
    final liquidity = _firstPositive(
      market.liquidityClob,
      market.liquidityNum,
      market.liquidityAmm,
    );
    if (liquidity <= 0 || market.volume24hr <= liquidity) continue;
    final opp = _opportunityFromMarket(
      opportunityTypeLowLiquidityHighVolume,
      market,
      '24h volume ${market.volume24hr.toStringAsFixed(2)} exceeds liquidity ${liquidity.toStringAsFixed(2)}',
      liquidity: liquidity,
    );
    opportunities.add(opp);
  }
  opportunities.sort(
    (a, b) => _ratio(b.volume24hr, _firstPositive(b.liquidity, b.liquidityClob))
        .compareTo(
          _ratio(a.volume24hr, _firstPositive(a.liquidity, a.liquidityClob)),
        ),
  );
  return opportunities;
}

List<Opportunity> _newMarkets(List<Market> markets) {
  final opportunities = <Opportunity>[];
  for (final market in markets) {
    if (!market.active || market.closed || !market.isNew) continue;
    opportunities.add(
      _opportunityFromMarket(
        opportunityTypeNewMarkets,
        market,
        'market is flagged new by Gamma',
      ),
    );
  }
  opportunities.sort((a, b) => b.marketId.compareTo(a.marketId));
  return opportunities;
}

List<Opportunity> _closingSoon(List<Market> markets, DateTime now, int hours) {
  final windowHours = hours <= 0 ? 24 : hours;
  final start = now.toUtc();
  final deadline = start.add(Duration(hours: windowHours));
  final opportunities = <Opportunity>[];
  for (final market in markets) {
    if (!market.active || market.closed) continue;
    final end = _marketEndTime(market);
    if (end == null || end.isBefore(start) || end.isAfter(deadline)) continue;
    opportunities.add(
      _opportunityFromMarket(
        opportunityTypeClosingSoon,
        market,
        'ends within $windowHours hours',
      ),
    );
  }
  opportunities.sort((a, b) {
    final left = DateTime.tryParse(a.endDate)?.toUtc() ?? DateTime(9999);
    final right = DateTime.tryParse(b.endDate)?.toUtc() ?? DateTime(9999);
    return left.compareTo(right);
  });
  return opportunities;
}

List<Opportunity> _negativeRisk(List<Market> markets) {
  final opportunities = <Opportunity>[];
  for (final market in markets) {
    if (!market.active || market.closed || !market.negRiskOther) continue;
    opportunities.add(
      _opportunityFromMarket(
        opportunityTypeNegativeRisk,
        market,
        'market is marked as negative-risk related',
      ),
    );
  }
  return opportunities;
}

Opportunity _opportunityFromMarket(
  String scannerType,
  Market market,
  String reason, {
  double liquidity = 0,
}) => Opportunity(
  type: scannerType,
  marketId: market.id,
  question: market.question,
  slug: market.slug,
  conditionId: market.conditionId,
  tokenIds: parseClobTokenIds(market.clobTokenIds),
  endDate: market.endDateIso,
  volume24hr: market.volume24hr,
  liquidity: liquidity,
  liquidityClob: market.liquidityClob,
  spread: market.spread,
  reasons: _compactReasons(<String>[reason]),
);

List<String> _compactReasons(List<String> reasons) => reasons
    .map((r) => r.trim())
    .where((r) => r.isNotEmpty)
    .toList(growable: false);

DateTime? _marketEndTime(Market market) {
  if (market.endDateIso.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(market.endDateIso);
    if (parsed != null) return parsed.toUtc();
  }
  return market.endDate?.toUtc();
}

double _firstPositive(double a, [double b = 0, double c = 0]) {
  for (final value in <double>[a, b, c]) {
    if (value > 0) return value;
  }
  return 0;
}

double _ratio(double numerator, double denominator) =>
    denominator <= 0 ? 0 : numerator / denominator;

int _normalizedLimit(int limit) => limit <= 0 ? 20 : limit;

int _scanFetchLimit(int limit) {
  final resultLimit = _normalizedLimit(limit);
  final fetchLimit = resultLimit * 5;
  if (fetchLimit < 100) return 100;
  if (fetchLimit > 500) return 500;
  return fetchLimit;
}

List<Opportunity> _limit(List<Opportunity> opportunities, int limit) =>
    opportunities.length > limit
    ? opportunities.sublist(0, limit)
    : opportunities;

DateTime _windowStartAt5m(DateTime at) {
  final utc = at.toUtc();
  final seconds = utc.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
  final windowSeconds = seconds - (seconds % 300);
  return DateTime.fromMillisecondsSinceEpoch(
    windowSeconds * Duration.millisecondsPerSecond,
    isUtc: true,
  );
}
