// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/gamma/gamma_client.dart';
import 'package:polydart/src/marketresolver/market_resolver.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:test/test.dart';

Map<String, dynamic> _marketJson({
  String slug = 'btc-updown-5m-1778061900',
  String question = 'Bitcoin Up or Down - 5m?',
  String conditionId = '0xc',
  String eventStartTime = '2026-05-06T10:05:00Z',
  String resolutionSource = 'UMA',
  bool active = true,
  bool closed = false,
  bool archived = false,
  bool acceptingOrders = true,
  bool enableOrderBook = true,
  String outcomes = '["Up","Down"]',
}) => <String, dynamic>{
  'id': '1',
  'question': question,
  'conditionId': conditionId,
  'slug': slug,
  'outcomes': outcomes,
  'clobTokenIds': '["111","222"]',
  'active': active,
  'closed': closed,
  'archived': archived,
  'acceptingOrders': acceptingOrders,
  'enableOrderBook': enableOrderBook,
  'resolutionSource': resolutionSource,
  'orderMinSize': 5.0,
  'orderPriceMinTickSize': 0.01,
  'startDate': '2026-05-06T10:00:00Z',
  'eventStartTime': eventStartTime,
  'endDate': '2026-05-06T10:10:00Z',
};

Map<String, dynamic> _eventJson({
  String slug = 'btc-updown-5m-1778061900',
  String resolutionSource = 'event-source',
  List<Map<String, dynamic>>? markets,
}) => <String, dynamic>{
  'id': 'event-1',
  'slug': slug,
  'title': 'BTC up/down',
  'active': true,
  'closed': false,
  'archived': false,
  'featured': false,
  'resolutionSource': resolutionSource,
  'markets': markets ?? <Map<String, dynamic>>[_marketJson(slug: slug)],
};

GammaClient _gammaWithMock(MockClient mock) => GammaClient(
  transport: HttpTransport(
    config: const TransportConfig(
      baseUrl: GammaClient.defaultBaseUrl,
      retryMax: 0,
    ),
    inner: mock,
  ),
);

void main() {
  group('parseClobTokenIds', () {
    test('empty / null forms', () {
      expect(parseClobTokenIds(''), isEmpty);
      expect(parseClobTokenIds('[]'), isEmpty);
      expect(parseClobTokenIds('null'), isEmpty);
    });

    test('JSON-encoded array', () {
      expect(parseClobTokenIds('["t1","t2"]'), ['t1', 't2']);
    });

    test('JSON with surrounding whitespace', () {
      expect(parseClobTokenIds('  ["t1","t2"]  '), ['t1', 't2']);
    });

    test('trims token values and drops whitespace-only tokens', () {
      expect(parseClobTokenIds('[" t1 "," ","t2"]'), ['t1', 't2']);
    });

    test('legacy unquoted-style fallback', () {
      // Manual parser kicks in only for non-JSON shapes.
      expect(parseClobTokenIds('"t1","t2"'), ['t1', 't2']);
    });
  });

  group('ResolvedMarket', () {
    test('isAvailable requires aligned outcomes/tokenIds', () {
      const r = ResolvedMarket(
        conditionId: '0xc',
        questionId: '0xq',
        slug: 's',
        question: 'q',
        outcomes: ['Yes', 'No'],
        tokenIds: ['t1', 't2'],
        acceptingOrders: true,
        closed: false,
        archived: false,
        enableOrderBook: true,
      );
      expect(r.isAvailable, isTrue);
      expect(r.yesTokenId, 't1');
      expect(r.noTokenId, 't2');
    });

    test('mismatched lengths fail isAvailable', () {
      const r = ResolvedMarket(
        conditionId: '0xc',
        questionId: '0xq',
        slug: 's',
        question: 'q',
        outcomes: ['Yes', 'No'],
        tokenIds: ['t1'],
        acceptingOrders: true,
        closed: false,
        archived: false,
        enableOrderBook: true,
      );
      expect(r.isAvailable, isFalse);
      expect(r.yesTokenId, isNull);
    });

    test('tokenIdFor handles up/down aliases', () {
      const r = ResolvedMarket(
        conditionId: '0xc',
        questionId: '',
        slug: 's',
        question: 'q',
        outcomes: ['Up', 'Down'],
        tokenIds: ['t1', 't2'],
        acceptingOrders: true,
        closed: false,
        archived: false,
        enableOrderBook: true,
      );
      expect(r.yesTokenId, 't1');
      expect(r.noTokenId, 't2');
    });
  });

  group('crypto resolver helpers', () {
    test('cryptoWindowSlug matches Polygolem deterministic format', () {
      final window = DateTime.fromMillisecondsSinceEpoch(
        1778114700000,
        isUtc: true,
      );
      expect(cryptoWindowSlug('BTC', '5m', window), 'btc-updown-5m-1778114700');
      expect(
        cryptoWindowSlug('HYPE', '4h', window),
        'hype-updown-4h-1778114700',
      );
      expect(cryptoWindowSlug('MYST', '5m', window), isEmpty);
      expect(cryptoWindowSlug('BTC', '1h', window), isEmpty);
    });

    test('cryptoQueries mirrors Polygolem asset aliases', () {
      expect(cryptoQueries('BTC'), ['bitcoin 5m', 'bitcoin 15m']);
      expect(cryptoQueries('ABC'), ['abc 5m', 'abc 15m']);
    });

    test('inferTimeframe recognizes 5m and 15m labels', () {
      expect(inferTimeframe('btc-updown-5m-1', ''), '5m');
      expect(inferTimeframe('', 'Bitcoin 15m window'), '15m');
      expect(inferTimeframe('hype-updown-4h-1778114700', ''), '4h');
      expect(inferTimeframe('other', 'no timeframe'), isEmpty);
    });

    test('normalizes caller-supplied timeframe aliases before slugging', () {
      final window = DateTime.parse('2026-05-06T10:05:00Z');
      expect(normalizeCryptoTimeframe(' 5M '), '5m');
      expect(normalizeCryptoTimeframe('15 min'), '15m');
      expect(
        cryptoWindowSlug(' btc ', '5M', window),
        'btc-updown-5m-1778061900',
      );
    });
  });

  group('MarketResolver', () {
    test('resolveBySlug populates the result', () async {
      final mock = MockClient((req) async {
        // marketBySlug calls /markets?slug=… and expects a JSON list.
        return http.Response(
          jsonEncode([
            _marketJson(
              slug: 'btc-100k',
              question: 'BTC > 100k?',
              resolutionSource: '',
            )..['outcomes'] = '["Yes","No"]',
          ]),
          200,
        );
      });
      final resolver = MarketResolver(gamma: _gammaWithMock(mock));

      final r = await resolver.resolveBySlug('btc-100k');
      expect(r, isNotNull);
      expect(r!.conditionId, '0xc');
      expect(r.tokenIds, ['111', '222']);
      expect(r.outcomes, ['Yes', 'No']);
      expect(r.yesTokenId, '111');
      expect(r.isAvailable, isTrue);
    });

    test('resolveTokenIdsForWindow normalizes padded outcome labels', () async {
      final window = DateTime.parse('2026-05-06T10:05:00Z');
      final mock = MockClient((req) async {
        return http.Response(
          jsonEncode([
            _eventJson(
              markets: <Map<String, dynamic>>[
                _marketJson(outcomes: '[" Up "," Down "]'),
              ],
            ),
          ]),
          200,
        );
      });
      final resolver = MarketResolver(gamma: _gammaWithMock(mock));

      final result = await resolver.resolveTokenIdsForWindow(
        'BTC',
        '5m',
        window,
      );
      expect(result.status, MarketStatus.available);
      expect(result.upTokenId, '111');
      expect(result.downTokenId, '222');
    });

    test('resolveTokenIdsForWindow returns strict 4h slug match', () async {
      final window = DateTime.parse('2026-05-06T10:05:00Z');
      final mock = MockClient((req) async {
        expect(req.url.path, '/events');
        expect(req.url.queryParameters['slug'], 'hype-updown-4h-1778061900');
        return http.Response(
          jsonEncode([
            _eventJson(
              slug: 'hype-updown-4h-1778061900',
              markets: <Map<String, dynamic>>[
                _marketJson(
                  slug: 'hype-updown-4h-1778061900',
                  question: 'HYPE Up or Down - 4h?',
                ),
              ],
            ),
          ]),
          200,
        );
      });
      final resolver = MarketResolver(gamma: _gammaWithMock(mock));

      final result = await resolver.resolveTokenIdsForWindow(
        'HYPE',
        '4h',
        window,
      );
      expect(result.status, MarketStatus.available);
      expect(
        result.source,
        'gamma:event_slug_strict:hype-updown-4h-1778061900',
      );
      expect(result.upTokenId, '111');
      expect(result.downTokenId, '222');
    });

    test('resolveTokenIdsForWindow normalizes timeframe aliases', () async {
      final window = DateTime.parse('2026-05-06T10:05:00Z');
      final mock = MockClient((req) async {
        expect(req.url.path, '/events');
        expect(req.url.queryParameters['slug'], 'btc-updown-5m-1778061900');
        return http.Response(jsonEncode([_eventJson()]), 200);
      });
      final resolver = MarketResolver(gamma: _gammaWithMock(mock));

      final result = await resolver.resolveTokenIdsForWindow(
        ' btc ',
        '5M',
        window,
      );
      expect(result.status, MarketStatus.available);
      expect(result.timeframe, '5m');
      expect(result.upTokenId, '111');
    });

    test('resolveTokenIdsForWindow returns strict slug match', () async {
      final window = DateTime.parse('2026-05-06T10:05:00Z');
      final mock = MockClient((req) async {
        expect(req.url.path, '/events');
        expect(req.url.queryParameters['slug'], 'btc-updown-5m-1778061900');
        expect(req.url.queryParameters['limit'], '1');
        return http.Response(jsonEncode([_eventJson()]), 200);
      });
      final resolver = MarketResolver(gamma: _gammaWithMock(mock));

      final result = await resolver.resolveTokenIdsForWindow(
        'BTC',
        '5m',
        window,
      );
      expect(result.status, MarketStatus.available);
      expect(result.upTokenId, '111');
      expect(result.downTokenId, '222');
      expect(result.conditionId, '0xc');
      expect(result.source, 'gamma:event_slug_strict:btc-updown-5m-1778061900');
      expect(result.resolutionSource, 'UMA');
      expect(result.minOrderSize, 5.0);
      expect(result.tickSize, 0.01);
    });

    test('resolveTokenIdsForWindow skips archived slug markets', () async {
      final window = DateTime.parse('2026-05-06T10:05:00Z');
      final mock = MockClient((req) async {
        return http.Response(
          jsonEncode([
            _eventJson(
              markets: <Map<String, dynamic>>[_marketJson(archived: true)],
            ),
          ]),
          200,
        );
      });
      final resolver = MarketResolver(gamma: _gammaWithMock(mock));

      final result = await resolver.resolveTokenIdsForWindow(
        'BTC',
        '5m',
        window,
      );
      expect(result.status, MarketStatus.unresolved);
      expect(result.source, contains('slug_event_no_accepting_market'));
    });

    test('resolveTokenIdsForWindow detects window mismatch', () async {
      final requested = DateTime.parse('2026-05-06T10:05:00Z');
      final mock = MockClient((req) async {
        return http.Response(
          jsonEncode([
            _eventJson(
              markets: <Map<String, dynamic>>[
                _marketJson(eventStartTime: '2026-05-06T10:10:00Z'),
              ],
            ),
          ]),
          200,
        );
      });
      final resolver = MarketResolver(gamma: _gammaWithMock(mock));

      final result = await resolver.resolveTokenIdsForWindow(
        'BTC',
        '5m',
        requested,
      );
      expect(result.status, MarketStatus.windowMismatch);
      expect(result.startDate, DateTime.parse('2026-05-06T10:10:00Z'));
      expect(result.source, contains('gamma:slug_hit_window_mismatch'));
    });

    test('resolveTokenIds falls back to active crypto search', () async {
      var searchCalls = 0;
      final mock = MockClient((req) async {
        if (req.url.path == '/public-search') {
          searchCalls++;
          if (req.url.queryParameters['q'] == 'bitcoin 5m') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'events': <Map<String, dynamic>>[
                  _eventJson(markets: <Map<String, dynamic>>[_marketJson()]),
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode(<String, dynamic>{'events': <Map<String, dynamic>>[]}),
            200,
          );
        }
        return http.Response('not found', 404);
      });
      final resolver = MarketResolver(gamma: _gammaWithMock(mock));

      final result = await resolver.resolveTokenIds('BTC', '5m');
      expect(searchCalls, 2);
      expect(result.status, MarketStatus.available);
      expect(result.source, 'gamma:crypto_search');
      expect(result.upTokenId, '111');
      expect(result.downTokenId, '222');
    });

    test('validateToken matches Polygolem resolver layer', () {
      final resolver = MarketResolver(
        gamma: _gammaWithMock(
          MockClient((_) async => http.Response('{}', 200)),
        ),
      );
      expect(resolver.validateToken(''), MarketStatus.unresolved);
      expect(resolver.validateToken('not-a-number'), MarketStatus.unresolved);
      expect(resolver.validateToken('123'), MarketStatus.available);
    });
  });
}
