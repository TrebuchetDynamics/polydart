import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  test('OpportunityRunner finds wide-spread opportunities', () async {
    final lister = _FakeMarketLister(<Market>[
      _market(
        id: 'tight',
        question: 'Tight book?',
        spread: 0.01,
        volume24hr: 50,
        liquidityClob: 100,
        clobTokenIds: '["tight-yes","tight-no"]',
      ),
      _market(
        id: 'wide',
        question: 'Wide book?',
        spread: 0.22,
        volume24hr: 250,
        liquidityClob: 40,
        clobTokenIds: '["wide-yes","wide-no"]',
      ),
      _market(
        id: 'closed',
        question: 'Closed wide?',
        spread: 0.5,
        closed: true,
      ),
    ]);

    final got = await OpportunityRunner(
      OpportunityConfig(gamma: lister),
    ).run(const OpportunityRequest(type: opportunityTypeWideSpread, limit: 1));

    expect(lister.lastParams?.active, isTrue);
    expect(lister.lastParams?.closed, isFalse);
    expect(lister.lastParams?.limit, 100);
    expect(got.type, opportunityTypeWideSpread);
    expect(got.count, 1);
    expect(got.opportunities.single.marketId, 'wide');
    expect(got.opportunities.single.question, 'Wide book?');
    expect(got.opportunities.single.spread, 0.22);
    expect(got.opportunities.single.tokenIds, <String>['wide-yes', 'wide-no']);
    expect(got.opportunities.single.reasons.single, isNotEmpty);
  });

  test('OpportunityRunner finds market opportunity types', () async {
    final now = DateTime.utc(2026, 6, 12, 12);
    final lister = _FakeMarketLister(<Market>[
      _market(
        id: 'volume',
        question: 'High volume thin book?',
        volume24hr: 500,
        liquidityClob: 25,
      ),
      _market(
        id: 'deep',
        question: 'Deep book?',
        volume24hr: 500,
        liquidityClob: 1000,
      ),
      _market(id: 'new', question: 'New market?', isNew: true),
      _market(id: 'old', question: 'Old market?'),
      _market(
        id: 'soon',
        question: 'Closing soon?',
        endDateIso: now.add(const Duration(hours: 2)).toIso8601String(),
      ),
      _market(
        id: 'later',
        question: 'Closing later?',
        endDateIso: now.add(const Duration(hours: 48)).toIso8601String(),
      ),
      _market(id: 'neg', question: 'Negative risk?', negRiskOther: true),
    ]);
    final runner = OpportunityRunner(OpportunityConfig(gamma: lister))
      ..now = () => now;

    final cases =
        <({String name, String type, OpportunityRequest request, String want})>[
          (
            name: 'low liquidity high volume',
            type: opportunityTypeLowLiquidityHighVolume,
            request: const OpportunityRequest(
              type: opportunityTypeLowLiquidityHighVolume,
              limit: 1,
            ),
            want: 'volume',
          ),
          (
            name: 'new markets',
            type: opportunityTypeNewMarkets,
            request: const OpportunityRequest(
              type: opportunityTypeNewMarkets,
              limit: 1,
            ),
            want: 'new',
          ),
          (
            name: 'closing soon',
            type: opportunityTypeClosingSoon,
            request: const OpportunityRequest(
              type: opportunityTypeClosingSoon,
              hours: 6,
              limit: 1,
            ),
            want: 'soon',
          ),
          (
            name: 'negative risk',
            type: opportunityTypeNegativeRisk,
            request: const OpportunityRequest(
              type: opportunityTypeNegativeRisk,
              limit: 1,
            ),
            want: 'neg',
          ),
        ];

    for (final tc in cases) {
      final got = await runner.run(tc.request);
      expect(got.type, tc.type, reason: tc.name);
      expect(got.count, 1, reason: tc.name);
      expect(got.opportunities.single.marketId, tc.want, reason: tc.name);
    }
  });

  test('OpportunityRunner finds crypto 5m opportunities for asset', () async {
    final now = DateTime.utc(2026, 6, 12, 12, 3);
    final source = _FakeGamma(<String, Event>{
      'btc-updown-5m-1781265600': Event.fromJson(<String, dynamic>{
        'id': 'event-btc',
        'title': 'BTC Up or Down - June 12, 12:00PM',
        'slug': 'btc-updown-5m-1781265600',
        'active': true,
        'markets': <Map<String, dynamic>>[
          _marketJson(
            id: 'market-btc',
            question: 'BTC up or down?',
            conditionId: 'condition-btc',
            clobTokenIds: '["btc-up","btc-down"]',
            endDateIso: '2026-06-12T12:05:00Z',
          ),
        ],
      }),
    });
    final runner = OpportunityRunner(
      OpportunityConfig(gamma: source, pricer: _FakePricer()),
    )..now = () => now;

    final got = await runner.run(
      const OpportunityRequest(
        type: opportunityTypeCrypto5m,
        asset: 'BTC',
        limit: 1,
      ),
    );

    expect(got.type, opportunityTypeCrypto5m);
    expect(got.count, 1);
    final opp = got.opportunities.single;
    expect(opp.marketId, 'market-btc');
    expect(opp.asset, 'BTC');
    expect(opp.price, '0.64');
    expect(opp.spreadText, '0.05');
  });
}

final class _FakeMarketLister implements OpportunityMarketLister {
  _FakeMarketLister(this.items);

  final List<Market> items;
  GetMarketsParams? lastParams;

  @override
  Future<List<Market>> markets([
    GetMarketsParams params = const GetMarketsParams(),
  ]) async {
    lastParams = params;
    return items;
  }
}

final class _FakeGamma
    implements OpportunityMarketLister, OpportunityEventFetcher {
  _FakeGamma(this.events);

  final Map<String, Event> events;

  @override
  Future<Event?> eventBySlug(String slug) async => events[slug];

  @override
  Future<List<Market>> markets([
    GetMarketsParams params = const GetMarketsParams(),
  ]) async => const <Market>[];
}

final class _FakePricer implements OpportunityPricer {
  @override
  Future<String> price(String tokenId, String side) async => '0.64';

  @override
  Future<String> spread(String tokenId) async => '0.05';
}

Market _market({
  required String id,
  required String question,
  bool active = true,
  bool closed = false,
  bool isNew = false,
  bool negRiskOther = false,
  double spread = 0,
  double volume24hr = 0,
  double liquidityClob = 0,
  String clobTokenIds = '[]',
  String endDateIso = '',
  String conditionId = '',
}) => Market.fromJson(
  _marketJson(
    id: id,
    question: question,
    active: active,
    closed: closed,
    isNew: isNew,
    negRiskOther: negRiskOther,
    spread: spread,
    volume24hr: volume24hr,
    liquidityClob: liquidityClob,
    clobTokenIds: clobTokenIds,
    endDateIso: endDateIso,
    conditionId: conditionId,
  ),
);

Map<String, dynamic> _marketJson({
  required String id,
  required String question,
  bool active = true,
  bool closed = false,
  bool isNew = false,
  bool negRiskOther = false,
  double spread = 0,
  double volume24hr = 0,
  double liquidityClob = 0,
  String clobTokenIds = '[]',
  String endDateIso = '',
  String conditionId = '',
}) => <String, dynamic>{
  'id': id,
  'question': question,
  'condition_id': conditionId,
  'slug': id,
  'active': active,
  'closed': closed,
  'archived': false,
  'new': isNew,
  'accepting_orders': true,
  'enable_order_book': true,
  'liquidityNum': liquidityClob,
  'volumeNum': volume24hr,
  'volume24hr': volume24hr,
  'liquidityClob': liquidityClob,
  'spread': spread,
  'lastTradePrice': 0,
  'bestBid': 0,
  'bestAsk': 0,
  'clobTokenIds': clobTokenIds,
  'negRiskOther': negRiskOther,
  if (endDateIso.isNotEmpty) 'endDateIso': endDateIso,
};
