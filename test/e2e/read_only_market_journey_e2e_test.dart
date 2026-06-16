import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  test(
    'read-only market journey composes Gamma, resolver, CLOB, and Data API',
    () async {
      final gammaHits = <String>[];
      final clobHits = <String>[];
      final dataHits = <String>[];

      final client = Polydart.readOnly(
        gammaTransport: HttpTransport(
          config: const TransportConfig(
            baseUrl: GammaClient.defaultBaseUrl,
            retryMax: 0,
          ),
          inner: MockClient((req) async {
            gammaHits.add('${req.method} ${req.url.path}?${req.url.query}');
            return _routeGamma(req);
          }),
        ),
        clobTransport: HttpTransport(
          config: const TransportConfig(
            baseUrl: ClobClient.defaultBaseUrl,
            retryMax: 0,
          ),
          inner: MockClient((req) async {
            clobHits.add('${req.method} ${req.url.path}?${req.url.query}');
            return _routeClob(req);
          }),
        ),
        dataTransport: HttpTransport(
          config: const TransportConfig(
            baseUrl: DataApiClient.defaultBaseUrl,
            retryMax: 0,
          ),
          inner: MockClient((req) async {
            dataHits.add('${req.method} ${req.url.path}?${req.url.query}');
            return _routeData(req);
          }),
        ),
      );
      addTearDown(client.close);

      final search = await client.gamma.search(
        const SearchParams(query: 'btc', limitPerType: 3),
      );
      expect(search.events.single.slug, 'btc-event');
      expect(search.events.single.markets.single.slug, 'btc-above-100k');

      final resolved = await client.resolver.resolveBySlug('btc-above-100k');
      expect(resolved, isNotNull);
      expect(resolved!.isAvailable, isTrue);
      expect(resolved.yesTokenId, 'token-yes');
      expect(resolved.noTokenId, 'token-no');

      final enriched = await client.discovery.enrichMarket(
        search.events.single.markets.single,
      );
      expect(enriched.tickSize!.minimumOrderSize, '5');
      expect(enriched.midpoint, '0.52');
      expect(enriched.spread, '0.04');
      expect(enriched.lastPrice, '0.51');
      expect(enriched.negRisk, isFalse);
      expect(enriched.feeRateBps, 0);
      expect(enriched.orderBook!.assetId, 'token-yes');

      final bundle = await client.marketBundle(conditionId: '0xcondition');
      expect(bundle.market.value!.slug, 'btc-above-100k');
      expect(bundle.event.value!.slug, 'btc-event');
      expect(
        bundle.orderBooks.value!.keys,
        containsAll(['token-yes', 'token-no']),
      );
      expect(
        bundle.priceHistory.value!['token-yes']!.history.single.price,
        '0.51',
      );
      expect(bundle.trades.value!.single.transactionHash, '0xtx');

      final dataTrades = await client.data.marketTrades(
        '0xcondition',
        limit: 2,
      );
      expect(dataTrades.single.market, '0xcondition');
      expect(dataTrades.single.assetId, 'token-yes');

      expect(
        gammaHits.any((hit) => hit.startsWith('GET /public-search?')),
        isTrue,
      );
      expect(
        gammaHits.any(
          (hit) =>
              hit.startsWith('GET /markets?') &&
              hit.contains('slug=btc-above-100k'),
        ),
        isTrue,
      );
      expect(clobHits, contains(startsWith('GET /midpoint?')));
      expect(clobHits, contains(startsWith('POST /books?')));
      expect(dataHits.single, startsWith('GET /trades?'));
    },
  );
}

Future<http.Response> _routeGamma(http.BaseRequest req) async {
  switch (req.url.path) {
    case '/public-search':
      expect(req.url.queryParameters['q'], 'btc');
      return _json(<String, dynamic>{
        'events': <Map<String, dynamic>>[
          _eventJson(markets: [_marketJson()]),
        ],
        'tags': <Object>[],
        'profiles': <Object>[],
        'pagination': <String, dynamic>{'hasMore': false, 'totalResults': 1},
      });
    case '/markets':
      final slug = req.url.queryParameters['slug'];
      final conditionIds =
          req.url.queryParametersAll['condition_ids'] ?? const <String>[];
      if (slug == 'btc-above-100k' || conditionIds.contains('0xcondition')) {
        return _json(<Map<String, dynamic>>[_marketJson()]);
      }
      return _json(<Map<String, dynamic>>[]);
    case '/events/e1':
      return _json(_eventJson(markets: [_marketJson()]));
  }
  return http.Response('unexpected Gamma request ${req.url}', 404);
}

Future<http.Response> _routeClob(http.BaseRequest req) async {
  final tokenId = req.url.queryParameters['token_id'];
  switch (req.url.path) {
    case '/tick-size':
      expect(tokenId, 'token-yes');
      return _json(<String, dynamic>{
        'minimum_tick_size': '0.01',
        'minimum_order_size': '5',
        'tick_size': '0.01',
      });
    case '/neg-risk':
      expect(tokenId, 'token-yes');
      return _json(<String, dynamic>{'neg_risk': false});
    case '/fee-rate':
      expect(tokenId, 'token-yes');
      return _json(<String, dynamic>{'fee_rate_bps': 0});
    case '/midpoint':
      expect(tokenId, 'token-yes');
      return _json(<String, dynamic>{'mid': '0.52'});
    case '/spread':
      expect(tokenId, 'token-yes');
      return _json(<String, dynamic>{'spread': '0.04'});
    case '/last-trade-price':
      expect(tokenId, 'token-yes');
      return _json(<String, dynamic>{'price': '0.51'});
    case '/book':
      return _json(_bookJson(tokenId ?? ''));
    case '/books':
      final body = jsonDecode((req as http.Request).body) as List<dynamic>;
      return _json(
        body
            .map((entry) => _bookJson((entry as Map)['token_id'].toString()))
            .toList(growable: false),
      );
    case '/prices-history':
      return _json(<String, dynamic>{
        'history': <Map<String, dynamic>>[
          <String, dynamic>{'t': '1714000000', 'p': '0.51'},
        ],
      });
    case '/trades':
      return _json(<String, dynamic>{
        'trades': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'trade-1',
            'status': 'matched',
            'market': '0xcondition',
            'asset_id': req.url.queryParameters['market'] ?? 'token-yes',
            'side': 'BUY',
            'price': '0.51',
            'size': '10',
            'transaction_hash': '0xtx',
            'created_at': '2026-05-13T00:00:00Z',
          },
        ],
      });
  }
  return http.Response('unexpected CLOB request ${req.url}', 404);
}

Future<http.Response> _routeData(http.BaseRequest req) async {
  switch (req.url.path) {
    case '/trades':
      expect(req.url.queryParameters['market'], '0xcondition');
      expect(req.url.queryParameters['limit'], '2');
      return _json(<Map<String, dynamic>>[
        <String, dynamic>{
          'conditionId': '0xcondition',
          'asset': 'token-yes',
          'side': 'BUY',
          'price': '0.51',
          'size': '10',
        },
      ]);
  }
  return http.Response('unexpected Data API request ${req.url}', 404);
}

Map<String, dynamic> _eventJson({required List<Map<String, dynamic>> markets}) {
  return <String, dynamic>{
    'id': 'e1',
    'ticker': 'BTC',
    'slug': 'btc-event',
    'title': 'Bitcoin event',
    'description': 'A mock Bitcoin event',
    'image': '',
    'icon': '',
    'active': true,
    'closed': false,
    'archived': false,
    'featured': false,
    'markets': markets,
    'tags': <Object>[],
  };
}

Map<String, dynamic> _marketJson() {
  return <String, dynamic>{
    'id': 'm1',
    'condition_id': '0xcondition',
    'question': 'Will BTC close above 100k?',
    'slug': 'btc-above-100k',
    'description': 'Mock market',
    'outcomes': ['Yes', 'No'],
    'outcomePrices': ['0.52', '0.48'],
    'active': true,
    'closed': false,
    'archived': false,
    'enableOrderBook': true,
    'acceptingOrders': true,
    'volumeNum': 1000000.0,
    'liquidityNum': 500000.0,
    'volume': '1000000',
    'endDateIso': '2026-12-31',
    'tokens': <Map<String, dynamic>>[
      <String, dynamic>{
        'token_id': 'token-yes',
        'outcome': 'Yes',
        'price': '0.52',
        'winner': false,
      },
      <String, dynamic>{
        'token_id': 'token-no',
        'outcome': 'No',
        'price': '0.48',
        'winner': false,
      },
    ],
    'tokenIds': ['token-yes', 'token-no'],
    'clobTokenIds': '["token-yes","token-no"]',
    'tags': <Object>[],
    'events': <Map<String, dynamic>>[
      <String, dynamic>{'id': 'e1'},
    ],
  };
}

Map<String, dynamic> _bookJson(String tokenId) {
  return <String, dynamic>{
    'market': '0xcondition',
    'asset_id': tokenId,
    'timestamp': '1714000000',
    'hash': '0xbook-$tokenId',
    'bids': <Map<String, dynamic>>[
      <String, dynamic>{'price': '0.50', 'size': '100'},
    ],
    'asks': <Map<String, dynamic>>[
      <String, dynamic>{'price': '0.54', 'size': '80'},
    ],
  };
}

http.Response _json(Object body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}
