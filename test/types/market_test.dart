// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';

import 'package:polydart/src/types/market.dart';
import 'package:test/test.dart';

void main() {
  group('Market.fromJson', () {
    test('handles outcomes encoded as a string-of-array', () {
      const raw = '''
      {
        "id": "100",
        "question": "Will BTC > 100k by EOY?",
        "conditionId": "0xcond",
        "slug": "btc-100k-eoy",
        "questionID": "0xq",
        "image": "https://x/i.png",
        "icon": "https://x/ic.png",
        "description": "...",
        "category": "Crypto",
        "startDate": "2026-01-01T00:00:00Z",
        "endDate": "2026-12-31T23:59:59Z",
        "outcomes": "[\\"Yes\\",\\"No\\"]",
        "outcomePrices": "[\\"0.42\\",\\"0.58\\"]",
        "active": true,
        "closed": false,
        "archived": false,
        "acceptingOrders": true,
        "enableOrderBook": true,
        "liquidityNum": 12345.6,
        "volumeNum": 99999,
        "lastTradePrice": 0.43,
        "bestBid": 0.42,
        "bestAsk": 0.44,
        "clobTokenIds": "[\\"t1\\",\\"t2\\"]",
        "tags": [{"id": "1", "label": "Bitcoin", "slug": "bitcoin"}]
      }
      ''';
      final m = Market.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      expect(m.id, '100');
      expect(m.outcomes, ['Yes', 'No']);
      expect(m.outcomePrices, ['0.42', '0.58']);
      expect(m.startDate, isNotNull);
      expect(m.tags, hasLength(1));
      expect(m.tags.first.label, 'Bitcoin');
      expect(m.bestAsk, 0.44);
    });

    test('decodes Polygolem Gamma market metadata fields', () {
      final m = Market.fromJson(<String, dynamic>{
        'id': '7',
        'marketType': 'normal',
        'umaResolutionStatus': 'proposed',
        'rewardsMinSize': '25.5',
        'rewardsMaxSpread': 0.03,
        'readyTimestamp': '2026-05-21T12:34:56Z',
        'negRiskFeeBips': 15,
      });

      expect(m.marketType, 'normal');
      expect(m.umaResolutionStatus, 'proposed');
      expect(m.rewardsMinSize, 25.5);
      expect(m.rewardsMaxSpread, 0.03);
      expect(m.readyTimestamp, DateTime.utc(2026, 5, 21, 12, 34, 56));
      expect(m.negRiskFeeBips, 15);
    });

    test('preserves uncommon fields on raw', () {
      final m = Market.fromJson(<String, dynamic>{
        'id': '7',
        'question': 'q',
        'someExoticField': 'preserved',
      });
      expect(m.raw['someExoticField'], 'preserved');
      expect(m.raw['id'], '7');
    });

    test('null dates yield null fields', () {
      final m = Market.fromJson(<String, dynamic>{
        'id': '1',
        'startDate': null,
        'endDate': null,
      });
      expect(m.startDate, isNull);
      expect(m.endDate, isNull);
    });
  });

  group('SearchResponse.fromJson', () {
    test('decodes events + tags + pagination', () {
      final r = SearchResponse.fromJson(<String, dynamic>{
        'events': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'e1',
            'ticker': 'BTC',
            'slug': 'btc',
            'title': 'BTC',
            'description': '',
            'image': '',
            'icon': '',
            'active': true,
            'closed': false,
            'archived': false,
            'featured': true,
            'liquidity': 1000,
            'volume': 5000,
            'markets': <Map<String, dynamic>>[],
            'tags': <Map<String, dynamic>>[],
          },
        ],
        'tags': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 't1',
            'label': 'Crypto',
            'slug': 'crypto',
            'event_count': 42,
          },
        ],
        'profiles': <Object>[],
        'pagination': <String, dynamic>{'hasMore': true, 'totalResults': 99},
      });
      expect(r.events.first.ticker, 'BTC');
      expect(r.tags.first.eventCount, 42);
      expect(r.pagination.hasMore, isTrue);
      expect(r.pagination.totalResults, 99);
    });

    test('missing pagination block yields zero defaults', () {
      final r = SearchResponse.fromJson(<String, dynamic>{
        'events': <Object>[],
        'tags': <Object>[],
        'profiles': <Object>[],
      });
      expect(r.pagination.hasMore, isFalse);
      expect(r.pagination.totalResults, 0);
    });
  });

  test('HealthResponse decodes', () {
    final h = HealthResponse.fromJson(<String, dynamic>{'data': 'ok'});
    expect(h.data, 'ok');
  });
}
