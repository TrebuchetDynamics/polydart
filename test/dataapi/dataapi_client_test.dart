// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/dataapi/dataapi_client.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:test/test.dart';

DataApiClient _client(
  Future<http.Response> Function(http.BaseRequest) handler,
) {
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

    test('decodes Polygolem V2 camelCase position fields', () async {
      final client = _client((req) async {
        return http.Response(
          jsonEncode([
            <String, dynamic>{
              'asset': 'asset-1',
              'conditionId': 'condition-1',
              'eventId': 'event-1',
              'proxyWallet': '0xproxy',
              'size': '12.5',
              'avgPrice': '0.42',
              'initialValue': '5.25',
              'currentValue': '7.50',
              'curPrice': '0.60',
              'cashPnl': '2.25',
              'percentPnl': '0.428571',
              'totalBought': '10.0',
              'realizedPnl': '1.50',
              'percentRealizedPnl': '0.12',
              'redeemable': true,
              'mergeable': false,
              'negativeRisk': true,
              'outcome': 'Yes',
              'outcomeIndex': 1,
              'oppositeOutcome': 'No',
              'oppositeAsset': 'asset-2',
              'endDate': '2026-06-01T00:00:00Z',
              'title': 'Will this decode?',
              'slug': 'will-this-decode',
              'eventSlug': 'decode-event',
              'icon': 'https://example.com/icon.png',
            },
          ]),
          200,
        );
      });

      final position = (await client.currentPositions('0xuser')).single;
      expect(position.tokenId, 'asset-1');
      expect(position.conditionId, 'condition-1');
      expect(position.eventId, 'event-1');
      expect(position.proxyWallet, '0xproxy');
      expect(position.avgPrice, 0.42);
      expect(position.currentPrice, 0.60);
      expect(position.cashPnl, 2.25);
      expect(position.percentPnl, 0.428571);
      expect(position.realizedPnl, 1.50);
      expect(position.percentRealized, 0.12);
      expect(position.redeemable, isTrue);
      expect(position.mergeable, isFalse);
      expect(position.negativeRisk, isTrue);
      expect(position.outcome, 'Yes');
      expect(position.outcomeIndex, 1);
      expect(position.oppositeOutcome, 'No');
      expect(position.oppositeAsset, 'asset-2');
      expect(position.endDate, '2026-06-01T00:00:00Z');
      expect(position.title, 'Will this decode?');
      expect(position.slug, 'will-this-decode');
      expect(position.eventSlug, 'decode-event');
      expect(position.icon, 'https://example.com/icon.png');
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

    test('decodes Polygolem V2 camelCase closed position fields', () async {
      final client = _client((req) async {
        return http.Response(
          jsonEncode([
            <String, dynamic>{
              'asset': 'asset-closed',
              'conditionId': 'condition-closed',
              'proxyWallet': '0xproxy',
              'avgPrice': '0.45',
              'size': '20',
              'totalBought': '20',
              'realizedPnl': '3.50',
              'curPrice': '0.62',
              'timestamp': 1714000000,
              'title': 'Closed market',
              'slug': 'closed-market',
              'icon': 'https://example.com/closed.png',
              'eventSlug': 'closed-event',
              'outcome': 'No',
              'outcomeIndex': 0,
              'oppositeOutcome': 'Yes',
              'oppositeAsset': 'asset-open',
              'endDate': '2026-07-01T00:00:00Z',
            },
          ]),
          200,
        );
      });

      final closed = (await client.closedPositions('0xuser')).single;
      expect(closed.tokenId, 'asset-closed');
      expect(closed.conditionId, 'condition-closed');
      expect(closed.proxyWallet, '0xproxy');
      expect(closed.avgPrice, 0.45);
      expect(closed.size, 20);
      expect(closed.realizedPnl, 3.50);
      expect(closed.currentPrice, 0.62);
      expect(closed.timestamp, '1714000000');
      expect(closed.title, 'Closed market');
      expect(closed.slug, 'closed-market');
      expect(closed.eventSlug, 'closed-event');
      expect(closed.outcome, 'No');
      expect(closed.outcomeIndex, 0);
      expect(closed.oppositeOutcome, 'Yes');
      expect(closed.oppositeAsset, 'asset-open');
      expect(closed.endDate, '2026-07-01T00:00:00Z');
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

    test('decodes Polygolem V2 camelCase trade fields', () async {
      final client = _client((req) async {
        return http.Response(
          jsonEncode([
            <String, dynamic>{
              'id': 'trade-v2',
              'conditionId': 'condition-trade',
              'asset': 'asset-trade',
              'proxyWallet': '0xproxy',
              'side': 'BUY',
              'price': '0.55',
              'size': '12.5',
              'feeRateBps': '25',
              'outcome': 'Yes',
              'outcomeIndex': 1,
              'title': 'Trade market',
              'slug': 'trade-market',
              'eventSlug': 'trade-event',
              'icon': 'https://example.com/trade.png',
              'status': 'MATCHED',
              'transactionHash': '0xhash',
              'takerOrderId': 'taker-1',
              'traderSide': 'TAKER',
              'timestamp': 1714001234,
            },
          ]),
          200,
        );
      });

      final trade = (await client.trades('0xuser')).single;
      expect(trade.id, 'trade-v2');
      expect(trade.market, 'condition-trade');
      expect(trade.assetId, 'asset-trade');
      expect(trade.proxyWallet, '0xproxy');
      expect(trade.feeRateBps, 25);
      expect(trade.outcome, 'Yes');
      expect(trade.outcomeIndex, 1);
      expect(trade.title, 'Trade market');
      expect(trade.slug, 'trade-market');
      expect(trade.eventSlug, 'trade-event');
      expect(trade.icon, 'https://example.com/trade.png');
      expect(trade.status, 'MATCHED');
      expect(trade.transactionHash, '0xhash');
      expect(trade.takerOrderId, 'taker-1');
      expect(trade.traderSide, 'TAKER');
      expect(trade.createdAt, '1714001234');
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
          jsonEncode(<String, dynamic>{'user': '0xuser', 'markets_traded': 42}),
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
