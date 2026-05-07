// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';

import 'package:polydart/src/types/clob.dart';
import 'package:test/test.dart';

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
      final book = OrderBook.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      expect(book.market, '0xabc');
      expect(book.assetId, '12345');
      expect(book.bids, hasLength(2));
      expect(book.asks, hasLength(1));
      expect(book.bids[0].price, '0.49');
      expect(book.asks[0].size, '75');
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
  });
}
