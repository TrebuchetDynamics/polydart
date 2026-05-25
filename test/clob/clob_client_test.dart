// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/clob/clob_client.dart';
import 'package:polydart/src/clob/clob_params.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:polydart/src/types/enums.dart';
import 'package:test/test.dart';

ClobClient _client(Future<http.Response> Function(http.BaseRequest) handler) {
  return ClobClient(
    transport: HttpTransport(
      config: const TransportConfig(
        baseUrl: ClobClient.defaultBaseUrl,
        retryMax: 0,
      ),
      inner: MockClient(handler),
    ),
  );
}

void main() {
  group('marketByToken', () {
    test('GETs /markets-by-token/{tokenId}', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'condition_id': 'condition-1',
            'primary_token_id': 'token-yes',
            'secondary_token_id': 'token-no',
          }),
          200,
        );
      });

      final market = await client.marketByToken('token-1');

      expect(captured!.path, '/markets-by-token/token-1');
      expect(market.conditionId, 'condition-1');
      expect(market.primaryTokenId, 'token-yes');
      expect(market.secondaryTokenId, 'token-no');
    });
  });

  group('orderBook', () {
    test('GETs /book?token_id=...', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'market': '0xabc',
            'asset_id': '12345',
            'timestamp': '1714000000',
            'hash': '0xdead',
            'bids': <Map<String, dynamic>>[
              <String, dynamic>{'price': '0.49', 'size': '100'},
            ],
            'asks': <Map<String, dynamic>>[
              <String, dynamic>{'price': '0.51', 'size': '50'},
            ],
          }),
          200,
        );
      });
      final book = await client.orderBook('12345');
      expect(captured!.path, '/book');
      expect(captured!.queryParameters['token_id'], '12345');
      expect(book.bids.first.price, '0.49');
      expect(book.asks.first.size, '50');
    });
  });

  group('price/midpoint/spread/lastTradePrice', () {
    test('price returns string and forwards side', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{'price': '0.42'}),
          200,
        );
      });
      final p = await client.price('12345', Side.buy.label);
      expect(p, '0.42');
      expect(captured!.queryParameters['side'], 'BUY');
    });

    test('midpoint returns mid', () async {
      final client = _client((req) async {
        return http.Response(jsonEncode(<String, dynamic>{'mid': '0.5'}), 200);
      });
      expect(await client.midpoint('t'), '0.5');
    });

    test('spread returns spread', () async {
      final client = _client((req) async {
        return http.Response(
          jsonEncode(<String, dynamic>{'spread': '0.02'}),
          200,
        );
      });
      expect(await client.spread('t'), '0.02');
    });

    test('lastTradePrice returns price', () async {
      final client = _client((req) async {
        return http.Response(
          jsonEncode(<String, dynamic>{'price': '0.43'}),
          200,
        );
      });
      expect(await client.lastTradePrice('t'), '0.43');
    });
  });

  group('serverTime', () {
    test('decodes timestamp + iso', () async {
      final client = _client((req) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'timestamp': '1714000000',
            'iso': '2026-05-07T00:00:00Z',
          }),
          200,
        );
      });
      final t = await client.serverTime();
      expect(t.timestamp, '1714000000');
      expect(t.iso, '2026-05-07T00:00:00Z');
    });
  });

  group('markets cursor', () {
    test('omits next_cursor when null', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'limit': 100,
            'count': 0,
            'next_cursor': '',
            'data': <Object>[],
          }),
          200,
        );
      });
      await client.markets();
      expect(captured!.queryParameters.containsKey('next_cursor'), isFalse);
    });

    test('includes next_cursor when provided', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'limit': 100,
            'count': 0,
            'next_cursor': 'NEXT',
            'data': <Object>[],
          }),
          200,
        );
      });
      await client.markets(nextCursor: 'CUR');
      expect(captured!.queryParameters['next_cursor'], 'CUR');
    });
  });

  group('negRiskInfo', () {
    test(
      'decodes full Polygolem neg-risk metadata while preserving bool helper',
      () async {
        Uri? captured;
        final client = _client((req) async {
          captured = req.url;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'neg_risk': true,
              'neg_risk_market_id': 'neg-market-1',
              'neg_risk_fee_bips': '25',
            }),
            200,
          );
        });

        final info = await client.negRiskInfo('12345');
        final flag = await client.negRisk('12345');

        expect(captured!.path, '/neg-risk');
        expect(captured!.queryParameters['token_id'], '12345');
        expect(info.negRisk, isTrue);
        expect(info.negRiskMarketId, 'neg-market-1');
        expect(info.negRiskFeeBips, 25);
        expect(flag, isTrue);
      },
    );
  });

  group('tickSize', () {
    test('decodes string fields', () async {
      final client = _client((req) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'minimum_tick_size': '0.01',
            'minimum_order_size': '5',
            'tick_size': '0.01',
          }),
          200,
        );
      });
      final t = await client.tickSize('12345');
      expect(t.minimumTickSize, '0.01');
      expect(t.minimumOrderSize, '5');
      expect(t.tickSize, '0.01');
    });
  });

  group('orderBooks', () {
    test('POSTs and decodes a list', () async {
      String? capturedBody;
      final client = _client((req) async {
        capturedBody = (req as http.Request).body;
        return http.Response(
          jsonEncode([
            <String, dynamic>{
              'market': '0xabc',
              'asset_id': '12345',
              'timestamp': '1714000000',
              'hash': '0xdead',
              'bids': <Object>[],
              'asks': <Object>[],
            },
          ]),
          200,
        );
      });
      final books = await client.orderBooks([
        const BookParams(tokenId: '12345'),
      ]);
      expect(books, hasLength(1));
      expect(books.first.assetId, '12345');
      expect(jsonDecode(capturedBody!), [
        {'token_id': '12345'},
      ]);
    });
  });

  group('pricesHistory', () {
    test('encodes interval, market, fidelity, timestamps', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{'history': <Object>[]}),
          200,
        );
      });
      await client.pricesHistory(
        const PriceHistoryParams(
          market: 'm',
          interval: '1h',
          fidelity: 100,
          startTimestamp: 1000,
          endTimestamp: 2000,
        ),
      );
      expect(captured!.queryParameters['market'], 'm');
      expect(captured!.queryParameters['interval'], '1h');
      expect(captured!.queryParameters['fidelity'], '100');
      expect(captured!.queryParameters['startTs'], '1000');
      expect(captured!.queryParameters['endTs'], '2000');
    });
  });

  group('builderTrades', () {
    test(
      'GETs /builder-trades with limit and decodes wrapped trades',
      () async {
        Uri? captured;
        final client = _client((req) async {
          captured = req.url;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'trades': <Map<String, dynamic>>[
                <String, dynamic>{
                  'trade_id': 'trade-1',
                  'order_id': 'order-1',
                  'market': '0xcondition',
                  'asset_id': '12345',
                  'side': 'BUY',
                  'size': 10,
                  'price': '0.52',
                  'timestamp': '1714000000',
                },
              ],
            }),
            200,
          );
        });

        final trades = await client.builderTrades(limit: 25);

        expect(captured!.path, '/builder-trades');
        expect(captured!.queryParameters['limit'], '25');
        expect(trades, hasLength(1));
        expect(trades.single.tradeId, 'trade-1');
        expect(trades.single.orderId, 'order-1');
        expect(trades.single.size, '10');
        expect(trades.single.price, '0.52');
      },
    );

    test('decodes camel aliases and numeric fields', () async {
      final client = _client((req) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'trades': <Map<String, dynamic>>[
              <String, dynamic>{
                'tradeId': 'trade-1',
                'orderId': 'order-1',
                'market': '0xcondition',
                'assetId': 12345,
                'side': 'BUY',
                'size': 10,
                'price': 0.52,
                'timestamp': 1714000000,
              },
            ],
          }),
          200,
        );
      });

      final trades = await client.builderTrades(limit: 25);

      expect(trades.single.tradeId, 'trade-1');
      expect(trades.single.orderId, 'order-1');
      expect(trades.single.assetId, '12345');
      expect(trades.single.size, '10');
      expect(trades.single.price, '0.52');
      expect(trades.single.timestamp, '1714000000');
    });
  });

  group('publicTrades', () {
    test('GETs unauthenticated trade history by market token', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'trades': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'trade-1',
                'status': 'matched',
                'market': '0xcondition',
                'asset_id': '12345',
                'side': 'BUY',
                'price': '0.52',
                'size': '10',
                'fee_rate_bps': '0',
                'outcome': 'Yes',
                'owner': '0xowner',
                'builder': '',
                'matched_amount': '5.2',
                'transaction_hash': '0xtx',
                'created_at': '2026-05-13T00:00:00Z',
                'last_updated': '2026-05-13T00:00:00Z',
              },
            ],
          }),
          200,
        );
      });

      final trades = await client.publicTrades(market: '12345');

      expect(captured!.path, '/trades');
      expect(captured!.queryParameters['market'], '12345');
      expect(trades, hasLength(1));
      expect(trades.first.transactionHash, '0xtx');
      expect(trades.first.price, '0.52');
    });
  });
}
