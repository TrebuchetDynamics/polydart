// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/clob/clob_client.dart';
import 'package:polydart/src/gamma/gamma_client.dart';
import 'package:polydart/src/marketdiscovery/market_discovery.dart';
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

void main() {
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

    final market = Market.fromJson(<String, dynamic>{
      'id': '1',
      'question': 'q',
      'slug': 's',
      'clobTokenIds': '["t1","t2"]',
      'active': true,
      'closed': false,
      'archived': false,
      'enableOrderBook': true,
    });

    final enriched = await discovery.enrichMarket(market);
    expect(enriched.tickSize?.tickSize, '0.01');
    expect(enriched.midpoint, '0.5');
    expect(enriched.spread, '0.02');
    expect(enriched.lastPrice, '0.5');
    expect(enriched.orderBook?.assetId, 't1');
    expect(
      hit,
      containsAll(<String>[
        '/tick-size',
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
    expect(enriched.market.id, '1');
  });

  test('searchAndEnrich walks events × markets', () async {
    var clobHits = 0;
    final gamma = _gamma((req) async {
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
          ],
          'tags': <Object>[],
          'profiles': <Object>[],
          'pagination': <String, dynamic>{'hasMore': false, 'totalResults': 1},
        }),
        200,
      );
    });

    final clob = _clob((req) async {
      clobHits++;
      // Always 200 with empty payloads — enough to hit the success path.
      switch (req.url.path) {
        case '/tick-size':
          return http.Response(jsonEncode(<String, dynamic>{}), 200);
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
    expect(out.first.midpoint, '0.5');
    expect(clobHits, greaterThanOrEqualTo(5));
  });
}
