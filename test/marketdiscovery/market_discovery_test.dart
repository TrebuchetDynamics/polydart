// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/clob/clob_client.dart';
import 'package:polydart/src/gamma/gamma_client.dart';
import 'package:polydart/src/marketdiscovery/market_discovery.dart';
import 'package:polydart/src/marketdiscovery/market_filter.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:polydart/src/types/market.dart';
import 'package:test/test.dart';

GammaClient _gamma(Future<http.Response> Function(http.BaseRequest) handler) =>
    GammaClient(
      transport: HttpTransport(
        config: const TransportConfig(
          baseUrl: GammaClient.defaultBaseUrl,
          retryMax: 0,
        ),
        inner: MockClient(handler),
      ),
    );

ClobClient _clob(Future<http.Response> Function(http.BaseRequest) handler) =>
    ClobClient(
      transport: HttpTransport(
        config: const TransportConfig(
          baseUrl: ClobClient.defaultBaseUrl,
          retryMax: 0,
        ),
        inner: MockClient(handler),
      ),
    );

Map<String, dynamic> _marketJson({
  String id = 'm1',
  bool active = true,
  bool closed = false,
  bool archived = false,
  bool enableOrderBook = true,
  String clobTokenIds = '["t1"]',
}) => <String, dynamic>{
  'id': id,
  'question': 'q',
  'slug': 's',
  'clobTokenIds': clobTokenIds,
  'active': active,
  'closed': closed,
  'archived': archived,
  'enableOrderBook': enableOrderBook,
};

void main() {
  group('shouldEnrichMarket', () {
    test('requires active open unarchived order-book markets', () {
      expect(shouldEnrichMarket(Market.fromJson(_marketJson())), isTrue);
      expect(
        shouldEnrichMarket(Market.fromJson(_marketJson(active: false))),
        isFalse,
      );
      expect(
        shouldEnrichMarket(Market.fromJson(_marketJson(closed: true))),
        isFalse,
      );
      expect(
        shouldEnrichMarket(Market.fromJson(_marketJson(archived: true))),
        isFalse,
      );
      expect(
        shouldEnrichMarket(
          Market.fromJson(_marketJson(enableOrderBook: false)),
        ),
        isFalse,
      );
    });
  });

  test('enrichMarket fans out CLOB reads in parallel', () async {
    final hit = <String>{};
    final clob = _clob((req) async {
      final path = req.url.path;
      hit.add(path);
      switch (path) {
        case '/tick-size':
          return http.Response(
            jsonEncode(<String, dynamic>{
              'minimum_tick_size': '0.01',
              'minimum_order_size': '5',
              'tick_size': '0.01',
            }),
            200,
          );
        case '/neg-risk':
          return http.Response(
            jsonEncode(<String, dynamic>{'neg_risk': true}),
            200,
          );
        case '/fee-rate':
          return http.Response(
            jsonEncode(<String, dynamic>{'fee_rate_bps': 12}),
            200,
          );
        case '/midpoint':
          return http.Response(
            jsonEncode(<String, dynamic>{'mid': '0.5'}),
            200,
          );
        case '/spread':
          return http.Response(
            jsonEncode(<String, dynamic>{'spread': '0.02'}),
            200,
          );
        case '/last-trade-price':
          return http.Response(
            jsonEncode(<String, dynamic>{'price': '0.5'}),
            200,
          );
        case '/book':
          return http.Response(
            jsonEncode(<String, dynamic>{
              'market': '0xc',
              'asset_id': 't1',
              'timestamp': '0',
              'hash': '0x',
              'bids': <Object>[],
              'asks': <Object>[],
            }),
            200,
          );
      }
      return http.Response('not found', 404);
    });

    final discovery = MarketDiscovery(gamma: GammaClient(), clob: clob);

    final market = Market.fromJson(
      _marketJson(id: '1', clobTokenIds: '["t1","t2"]'),
    );

    final enriched = await discovery.enrichMarket(market);
    expect(enriched.tickSize?.tickSize, '0.01');
    expect(enriched.midpoint, '0.5');
    expect(enriched.spread, '0.02');
    expect(enriched.lastPrice, '0.5');
    expect(enriched.orderBook?.assetId, 't1');
    expect(enriched.negRisk, isTrue);
    expect(enriched.feeRateBps, 12);
    expect(
      hit,
      containsAll(<String>[
        '/tick-size',
        '/neg-risk',
        '/fee-rate',
        '/midpoint',
        '/spread',
        '/last-trade-price',
        '/book',
      ]),
    );
  });

  test('enrichMarket handles missing tokens', () async {
    final clob = _clob((req) async => http.Response('ignored', 200));
    final discovery = MarketDiscovery(gamma: GammaClient(), clob: clob);
    final market = Market.fromJson(<String, dynamic>{
      'id': '1',
      'clobTokenIds': '',
    });
    final enriched = await discovery.enrichMarket(market);
    expect(enriched.tickSize, isNull);
    expect(enriched.midpoint, isNull);
    expect(enriched.orderBook, isNull);
    expect(enriched.negRisk, isNull);
    expect(enriched.feeRateBps, isNull);
  });

  test('CLOB failures are non-fatal', () async {
    final clob = _clob((req) async => http.Response('boom', 500));
    final discovery = MarketDiscovery(gamma: GammaClient(), clob: clob);
    final market = Market.fromJson(<String, dynamic>{
      'id': '1',
      'clobTokenIds': '["t1"]',
    });
    final enriched = await discovery.enrichMarket(market);
    expect(enriched.tickSize, isNull);
    expect(enriched.midpoint, isNull);
    expect(enriched.orderBook, isNull);
    expect(enriched.negRisk, isNull);
    expect(enriched.feeRateBps, isNull);
    expect(enriched.market.id, '1');
  });

  test('searchAndEnrich skips closed markets before CLOB reads', () async {
    var clobHits = 0;
    final gamma = _gamma((req) async {
      if (req.url.path == '/public-search') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'events': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'e1',
                'ticker': 'BTC',
                'slug': 'btc',
                'title': '',
                'description': '',
                'image': '',
                'icon': '',
                'active': true,
                'closed': false,
                'archived': false,
                'featured': false,
                'liquidity': 0,
                'volume': 0,
                'tags': <Object>[],
                'markets': <Map<String, dynamic>>[],
              },
            ],
            'tags': <Object>[],
            'profiles': <Object>[],
            'pagination': <String, dynamic>{
              'hasMore': false,
              'totalResults': 1,
            },
          }),
          200,
        );
      }
      if (req.url.path == '/events') {
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'e1',
              'ticker': 'BTC',
              'slug': 'btc',
              'title': '',
              'description': '',
              'image': '',
              'icon': '',
              'active': true,
              'closed': false,
              'archived': false,
              'featured': false,
              'liquidity': 0,
              'volume': 0,
              'tags': <Object>[],
              'markets': <Map<String, dynamic>>[
                _marketJson(id: 'closed', closed: true),
              ],
            },
          ]),
          200,
        );
      }
      return http.Response('not found', 404);
    });

    final clob = _clob((req) async {
      clobHits++;
      return http.Response('unexpected CLOB hit', 500);
    });

    final discovery = MarketDiscovery(gamma: gamma, clob: clob);
    final out = await discovery.searchAndEnrich('btc');
    expect(out, isEmpty);
    expect(clobHits, 0);
  });

  test(
    'searchAndEnrich fetches full events before enriching markets',
    () async {
      var clobHits = 0;
      var eventLookupCalled = false;
      final gamma = _gamma((req) async {
        if (req.url.path == '/public-search') {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'events': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'e1',
                  'ticker': 'BTC',
                  'slug': 'btc',
                  'title': '',
                  'description': '',
                  'image': '',
                  'icon': '',
                  'active': true,
                  'closed': false,
                  'archived': false,
                  'featured': false,
                  'liquidity': 0,
                  'volume': 0,
                  'tags': <Object>[],
                  'markets': <Map<String, dynamic>>[],
                },
              ],
              'tags': <Object>[],
              'profiles': <Object>[],
              'pagination': <String, dynamic>{
                'hasMore': false,
                'totalResults': 1,
              },
            }),
            200,
          );
        }
        if (req.url.path == '/events') {
          eventLookupCalled = true;
          expect(req.url.queryParameters['slug'], 'btc');
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'e1',
                'ticker': 'BTC',
                'slug': 'btc',
                'title': '',
                'description': '',
                'image': '',
                'icon': '',
                'active': true,
                'closed': false,
                'archived': false,
                'featured': false,
                'liquidity': 0,
                'volume': 0,
                'tags': <Object>[],
                'markets': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'm1',
                    'question': 'q',
                    'slug': 's',
                    'clobTokenIds': '["t1"]',
                    'active': true,
                    'enableOrderBook': true,
                  },
                ],
              },
            ]),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final clob = _clob((req) async {
        clobHits++;
        // Always 200 with empty payloads — enough to hit the success path.
        switch (req.url.path) {
          case '/tick-size':
            return http.Response(jsonEncode(<String, dynamic>{}), 200);
          case '/neg-risk':
            return http.Response(
              jsonEncode(<String, dynamic>{'neg_risk': false}),
              200,
            );
          case '/fee-rate':
            return http.Response(
              jsonEncode(<String, dynamic>{'fee_rate_bps': 0}),
              200,
            );
          case '/midpoint':
            return http.Response(
              jsonEncode(<String, dynamic>{'mid': '0.5'}),
              200,
            );
          case '/spread':
            return http.Response(
              jsonEncode(<String, dynamic>{'spread': '0.02'}),
              200,
            );
          case '/last-trade-price':
            return http.Response(
              jsonEncode(<String, dynamic>{'price': '0.5'}),
              200,
            );
          case '/book':
            return http.Response(
              jsonEncode(<String, dynamic>{
                'market': '',
                'asset_id': 't1',
                'timestamp': '0',
                'hash': '0x',
                'bids': <Object>[],
                'asks': <Object>[],
              }),
              200,
            );
        }
        return http.Response('?', 404);
      });

      final discovery = MarketDiscovery(gamma: gamma, clob: clob);
      final out = await discovery.searchAndEnrich('btc');
      expect(out, hasLength(1));
      expect(eventLookupCalled, isTrue);
      expect(out.first.midpoint, '0.5');
      expect(out.first.negRisk, isFalse);
      expect(out.first.feeRateBps, 0);
      expect(clobHits, greaterThanOrEqualTo(7));
    },
  );
}
