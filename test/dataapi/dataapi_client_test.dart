// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/dataapi/dataapi_client.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:test/test.dart';

DataApiClient _client(Future<http.Response> Function(http.BaseRequest) handler) {
  return DataApiClient(
    transport: HttpTransport(
      config: const TransportConfig(
        baseUrl: DataApiClient.defaultBaseUrl,
        retryMax: 0,
      ),
      inner: MockClient(handler),
    ),
  );
}

void main() {
  group('health', () {
    test('GETs /', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(jsonEncode(<String, dynamic>{}), 200);
      });
      await client.health();
      expect(captured!.path, '/');
    });
  });

  group('currentPositions', () {
    test('GETs /positions and omits limit when 0', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode([
            <String, dynamic>{
              'token_id': 'tok',
              'condition_id': 'cond',
              'market_id': 'mkt',
              'side': 'YES',
              'avg_price': 0.42,
              'size': 100.0,
              'current_price': 0.51,
              'unrealized_pnl': 9.0,
            },
          ]),
          200,
        );
      });
      final positions = await client.currentPositions('0xuser');
      expect(captured!.path, '/positions');
      expect(captured!.queryParameters['user'], '0xuser');
      expect(captured!.queryParameters.containsKey('limit'), isFalse);
      expect(positions, hasLength(1));
      expect(positions.first.tokenId, 'tok');
      expect(positions.first.avgPrice, 0.42);
      expect(positions.first.unrealizedPnl, 9.0);
    });

    test('forwards limit when > 0', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(jsonEncode(<Object>[]), 200);
      });
      await client.currentPositions('0xuser', limit: 25);
      expect(captured!.queryParameters['limit'], '25');
    });
  });

  group('closedPositions', () {
    test('GETs /closed-positions and parses fields', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode([
            <String, dynamic>{
              'token_id': 'tok',
              'condition_id': 'cond',
              'market_id': 'mkt',
              'side': 'NO',
              'avg_price_buy': 0.3,
              'avg_price_sell': 0.7,
              'size': 50.0,
              'realized_pnl': 20.0,
            },
          ]),
          200,
        );
      });
      final closed = await client.closedPositions('0xuser', limit: 10);
      expect(captured!.path, '/closed-positions');
      expect(captured!.queryParameters['user'], '0xuser');
      expect(captured!.queryParameters['limit'], '10');
      expect(closed.first.avgPriceBuy, 0.3);
      expect(closed.first.realizedPnl, 20.0);
    });
  });

  group('trades', () {
    test('GETs /trades with user + limit', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode([
            <String, dynamic>{
              'id': 'trade-1',
              'market': '0xabc',
              'asset_id': 'tok',
              'side': 'BUY',
              'price': 0.55,
              'size': 12.5,
              'fee_rate_bps': 30,
              'created_at': '2026-05-07T00:00:00Z',
            },
          ]),
          200,
        );
      });
      final trades = await client.trades('0xuser', limit: 5);
      expect(captured!.path, '/trades');
      expect(captured!.queryParameters['user'], '0xuser');
      expect(captured!.queryParameters['limit'], '5');
      expect(trades.first.id, 'trade-1');
      expect(trades.first.feeRateBps, 30);
      expect(trades.first.price, 0.55);
    });
  });

  group('activity', () {
    test('GETs /activity and preserves string price/size', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode([
            <String, dynamic>{
              'type': 'TRADE',
              'market': '0xabc',
              'asset_id': 'tok',
              'side': 'SELL',
              'price': '0.42',
              'size': '100',
              'timestamp': '1714000000',
            },
          ]),
          200,
        );
      });
      final acts = await client.activity('0xuser', limit: 3);
      expect(captured!.path, '/activity');
      expect(captured!.queryParameters['user'], '0xuser');
      expect(captured!.queryParameters['limit'], '3');
      expect(acts.first.type, 'TRADE');
      expect(acts.first.price, '0.42');
      expect(acts.first.size, '100');
    });
  });

  group('topHolders', () {
    test('GETs /top-holders with token_id + limit', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode([
            <String, dynamic>{
              'address': '0xholder',
              'shares': 500.0,
              'pnl': 25.5,
              'volume': 2000.0,
            },
          ]),
          200,
        );
      });
      final holders = await client.topHolders('tok123', limit: 20);
      expect(captured!.path, '/top-holders');
      expect(captured!.queryParameters['token_id'], 'tok123');
      expect(captured!.queryParameters['limit'], '20');
      expect(holders.first.address, '0xholder');
      expect(holders.first.shares, 500.0);
    });
  });

  group('totalValue', () {
    test('GETs /total-value and decodes object', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'user': '0xuser',
            'value': 1234.56,
            'timestamp': '1714000000',
          }),
          200,
        );
      });
      final tv = await client.totalValue('0xuser');
      expect(captured!.path, '/total-value');
      expect(captured!.queryParameters['user'], '0xuser');
      expect(tv.user, '0xuser');
      expect(tv.value, 1234.56);
      expect(tv.timestamp, '1714000000');
    });
  });

  group('marketsTraded', () {
    test('GETs /total-markets-traded', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'user': '0xuser',
            'markets_traded': 42,
          }),
          200,
        );
      });
      final m = await client.marketsTraded('0xuser');
      expect(captured!.path, '/total-markets-traded');
      expect(captured!.queryParameters['user'], '0xuser');
      expect(m.user, '0xuser');
      expect(m.marketsTraded, 42);
    });
  });

  group('openInterest', () {
    test('GETs /open-interest with token_id', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'market': '0xabc',
            'asset_id': 'tok',
            'open_value': 9999.99,
          }),
          200,
        );
      });
      final oi = await client.openInterest('tok');
      expect(captured!.path, '/open-interest');
      expect(captured!.queryParameters['token_id'], 'tok');
      expect(oi.market, '0xabc');
      expect(oi.assetId, 'tok');
      expect(oi.openValue, 9999.99);
    });
  });

  group('traderLeaderboard', () {
    test('GETs /trader-leaderboard with limit', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode([
            <String, dynamic>{
              'rank': 1,
              'user': '0xking',
              'volume': 1000000.0,
              'pnl': 50000.0,
              'roi': 0.05,
            },
          ]),
          200,
        );
      });
      final lb = await client.traderLeaderboard(limit: 100);
      expect(captured!.path, '/trader-leaderboard');
      expect(captured!.queryParameters['limit'], '100');
      expect(lb.first.rank, 1);
      expect(lb.first.user, '0xking');
      expect(lb.first.roi, 0.05);
    });
  });

  group('liveVolume', () {
    test('GETs /live-volume and decodes total + events', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'total': 2,
            'events': [
              <String, dynamic>{
                'event_id': 'evt1',
                'event_slug': 'slug-1',
                'title': 'Event One',
                'volume': 1000.0,
              },
              <String, dynamic>{
                'event_id': 'evt2',
                'event_slug': 'slug-2',
                'title': 'Event Two',
                'volume': 2000.0,
              },
            ],
          }),
          200,
        );
      });
      final lv = await client.liveVolume(limit: 50);
      expect(captured!.path, '/live-volume');
      expect(captured!.queryParameters['limit'], '50');
      expect(lv.total, 2);
      expect(lv.events, hasLength(2));
      expect(lv.events.first.eventSlug, 'slug-1');
      expect(lv.events.last.volume, 2000.0);
    });
  });
}
