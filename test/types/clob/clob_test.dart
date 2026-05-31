// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:polydart/src/types/clob.dart';
import 'package:test/test.dart';

import '../shared/json_contracts.dart';

void main() {
  group('OrderBook.fromJson', () {
    test('decodes a realistic book payload', () {
      const raw = '''
      {
        "market": "0xabc",
        "asset_id": "12345",
        "timestamp": "1714000000",
        "hash": "0xdeadbeef",
        "bids": [
          {"price": "0.49", "size": "100"},
          {"price": "0.48", "size": "250"}
        ],
        "asks": [
          {"price": "0.51", "size": "75"}
        ]
      }
      ''';
      final book = OrderBook.fromJson(decodeJsonObject(raw));
      expect(book.market, '0xabc');
      expect(book.assetId, '12345');
      expect(book.bids, hasLength(2));
      expect(book.asks, hasLength(1));
      expect(book.bids[0].price, '0.49');
      expect(book.asks[0].size, '75');
    });

    test('decodes numeric fields and camel aliases', () {
      final book = OrderBook.fromJson(<String, dynamic>{
        'market': '0xmarket',
        'assetId': 12345,
        'timestamp': 1710000000,
        'hash': '0xhash',
        'bids': [
          <String, dynamic>{'price': 0.42, 'size': 100},
        ],
        'asks': [
          <String, dynamic>{'price': '0.43', 'size': 200},
        ],
        'minOrderSize': 5,
        'tickSize': 0.01,
        'negRisk': 'true',
        'lastTradePrice': 0.42,
      });
      expect(book.assetId, '12345');
      expect(book.timestamp, '1710000000');
      expect(book.bids.single.price, '0.42');
      expect(book.asks.single.size, '200');
      expect(book.minOrderSize, '5');
      expect(book.tickSize, '0.01');
      expect(book.negRisk, isTrue);
      expect(book.lastTradePrice, '0.42');
    });

    test('missing arrays default to empty', () {
      final book = OrderBook.fromJson(<String, dynamic>{
        'market': 'm',
        'asset_id': 'a',
      });
      expect(book.bids, isEmpty);
      expect(book.asks, isEmpty);
    });
  });

  group('Token.fromJson', () {
    test('numeric price gets stringified', () {
      final t = Token.fromJson(<String, dynamic>{
        'token_id': '12345',
        'outcome': 'Yes',
        'price': 0.5,
        'winner': false,
      });
      expect(t.price, '0.5');
      expect(t.outcome, 'Yes');
      expect(t.winner, isFalse);
    });
  });

  group('NegRiskInfo.fromJson', () {
    test('decodes string fields and camel aliases', () {
      final info = NegRiskInfo.fromJson(<String, dynamic>{
        'negRisk': 'true',
        'negRiskMarketID': 'neg-market-1',
        'negRiskFeeBips': '25',
      });
      expect(info.negRisk, isTrue);
      expect(info.negRiskMarketId, 'neg-market-1');
      expect(info.negRiskFeeBips, 25);
    });
  });

  group('TickSize.fromJson', () {
    test('decodes numeric fields and camel aliases', () {
      final tick = TickSize.fromJson(<String, dynamic>{
        'minimumTickSize': 0.001,
        'minimumOrderSize': 5,
        'tickSize': 0.01,
      });
      expect(tick.minimumTickSize, '0.001');
      expect(tick.minimumOrderSize, '5');
      expect(tick.tickSize, '0.01');
    });
  });

  group('PriceResponse', () {
    test('handles missing spread', () {
      final p = PriceResponse.fromJson(<String, dynamic>{'price': '0.5'});
      expect(p.price, '0.5');
      expect(p.spread, '');
    });
  });

  group('ClobPaginatedMarkets', () {
    test('decodes empty data', () {
      final m = ClobPaginatedMarkets.fromJson(<String, dynamic>{
        'limit': 50,
        'count': 0,
        'next_cursor': '',
        'data': <Object>[],
      });
      expect(m.limit, 50);
      expect(m.data, isEmpty);
    });

    test('decodes Polygolem CLOB market metadata fields', () {
      final market = ClobMarket.fromJson(<String, dynamic>{
        'condition_id': '0x1',
        'question_id': '0x2',
        'tokens': <Map<String, dynamic>>[],
        'game_start_time': '2026-06-17T00:00:00Z',
        'spread': 0.02,
        'enable_order_book': true,
        'accepting_orders': true,
        'closed': false,
        'archived': false,
        'neg_risk': true,
        'neg_risk_market_id': 'neg-risk-market',
        'neg_risk_request_id': 'neg-risk-request',
        'notifications_enabled': true,
        'order_min_size': 5,
        'order_price_min_tick_size': 0.01,
      });

      expect(market.gameStartTime, '2026-06-17T00:00:00Z');
      expect(market.negRisk, isTrue);
      expect(market.negRiskMarketId, 'neg-risk-market');
      expect(market.negRiskRequestId, 'neg-risk-request');
      expect(market.notificationsEnabled, isTrue);
    });

    test('decodes camel fee details with string fields', () {
      final market = ClobMarket.fromJson(<String, dynamic>{
        'condition_id': '0x1',
        'tokens': <Map<String, dynamic>>[],
        'feeDetails': <String, dynamic>{
          'rate': '0.01',
          'exponent': '2',
          'takerOnly': 'true',
        },
      });
      expect(market.feeDetails.rate, 0.01);
      expect(market.feeDetails.exponent, 2);
      expect(market.feeDetails.takerOnly, isTrue);
    });

    test('decodes abbreviated Polygolem provider shape', () {
      final market = ClobMarket.fromJson(<String, dynamic>{
        'c': '0xshort',
        'gst': '2026-06-18T00:00:00Z',
        't': <Map<String, dynamic>>[
          <String, dynamic>{'t': 'T', 'o': 'Yes', 'p': '0.5', 'w': false},
        ],
        'ao': true,
        'cbos': true,
        'nr': true,
        'mos': 5,
        'mts': 0.01,
      });

      expect(market.conditionId, '0xshort');
      expect(market.gameStartTime, '2026-06-18T00:00:00Z');
      expect(market.tokens.first.tokenId, 'T');
      expect(market.acceptingOrders, isTrue);
      expect(market.enableOrderBook, isTrue);
      expect(market.negRisk, isTrue);
    });

    test('decodes one market', () {
      final m = ClobPaginatedMarkets.fromJson(<String, dynamic>{
        'limit': 1,
        'count': 1,
        'next_cursor': 'CURSOR',
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'condition_id': '0x1',
            'question_id': '0x2',
            'tokens': <Map<String, dynamic>>[
              <String, dynamic>{
                'token_id': 'T',
                'outcome': 'Yes',
                'price': '0.5',
                'winner': false,
              },
            ],
            'spread': 0.01,
            'enable_order_book': true,
            'accepting_orders': true,
            'closed': false,
            'archived': false,
            'neg_risk': false,
            'order_min_size': 5,
            'order_price_min_tick_size': 0.01,
          },
        ],
      });
      expect(m.data, hasLength(1));
      final market = m.data.first;
      expect(market.conditionId, '0x1');
      expect(market.tokens.first.tokenId, 'T');
      expect(market.spread, closeTo(0.01, 1e-9));
    });
  });

  group('PriceHistory', () {
    test('decodes points', () {
      final h = PriceHistory.fromJson(<String, dynamic>{
        'history': <Map<String, dynamic>>[
          <String, dynamic>{'t': '1714000000', 'p': '0.5'},
          <String, dynamic>{'t': '1714000300', 'p': 0.51},
        ],
      });
      expect(h.history, hasLength(2));
      expect(h.history[1].price, '0.51');
    });

    test('decodes long aliases and numeric fields', () {
      final h = PriceHistory.fromJson(<String, dynamic>{
        'history': <Map<String, dynamic>>[
          <String, dynamic>{
            'timestamp': 1714000000,
            'price': 0.51,
            'volume': 12,
            'interval': '1m',
          },
        ],
      });
      expect(h.history.single.timestamp, '1714000000');
      expect(h.history.single.price, '0.51');
      expect(h.history.single.volume, '12');
      expect(h.history.single.interval, '1m');
    });
  });
}
