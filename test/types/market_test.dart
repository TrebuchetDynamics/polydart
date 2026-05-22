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

  group('Event.fromJson', () {
    test('decodes Polygolem Gamma subtitle', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'title': 'Championship winner',
        'subtitle': '2026 season',
      });

      expect(event.title, 'Championship winner');
      expect(event.subtitle, '2026 season');
    });

    test('decodes Polygolem Gamma subcategory', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'category': 'Sports',
        'subcategory': 'NBA',
      });

      expect(event.category, 'Sports');
      expect(event.subcategory, 'NBA');
    });

    test('decodes Polygolem Gamma sort order hint', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'sortBy': 'volume',
      });

      expect(event.sortBy, 'volume');
    });

    test('decodes Polygolem Gamma template flag', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'isTemplate': true,
      });

      expect(event.isTemplate, isTrue);
    });

    test('decodes Polygolem Gamma template variables', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'templateVariables': '{"team":"Lakers"}',
      });

      expect(event.templateVariables, '{"team":"Lakers"}');
    });

    test('decodes Polygolem Gamma creator address', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'createdBy': '0x1111111111111111111111111111111111111111',
      });

      expect(event.createdBy, '0x1111111111111111111111111111111111111111');
    });

    test('decodes Polygolem Gamma updater address', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'updatedBy': '0x2222222222222222222222222222222222222222',
      });

      expect(event.updatedBy, '0x2222222222222222222222222222222222222222');
    });

    test('decodes Polygolem Gamma competitive score', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'competitive': 0.75,
      });

      expect(event.competitive, 0.75);
    });

    test('decodes Polygolem Gamma featured image', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'featuredImage': 'https://example.com/featured.png',
      });

      expect(event.featuredImage, 'https://example.com/featured.png');
    });

    test('decodes Polygolem Gamma optimized event image', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'imageOptimized': <String, dynamic>{
          'id': 'image-1',
          'imageUrlSource': 'https://example.com/source.png',
          'imageUrlOptimized': 'https://example.com/optimized.webp',
          'imageSizeKbSource': 128,
          'imageSizeKbOptimized': '42',
          'imageOptimizedComplete': true,
          'imageOptimizedLastUpdated': '2026-05-21T12:34:56Z',
          'relID': 77,
          'field': 'image',
          'relname': 'events',
        },
      });

      final image = event.imageOptimized;
      expect(image, isNotNull);
      expect(image!.id, 'image-1');
      expect(image.imageUrlSource, 'https://example.com/source.png');
      expect(image.imageUrlOptimized, 'https://example.com/optimized.webp');
      expect(image.imageSizeKbSource, 128);
      expect(image.imageSizeKbOptimized, 42);
      expect(image.imageOptimizedComplete, isTrue);
      expect(
        image.imageOptimizedLastUpdated,
        DateTime.utc(2026, 5, 21, 12, 34, 56),
      );
      expect(image.relId, 77);
      expect(image.field, 'image');
      expect(image.relName, 'events');
      expect(
        Event.fromJson(<String, dynamic>{
          'imageOptimized': 'invalid',
        }).imageOptimized,
        isNull,
      );
    });

    test('decodes Polygolem Gamma optimized event icon', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'iconOptimized': <String, dynamic>{
          'id': 'icon-1',
          'imageUrlSource': 'https://example.com/icon.png',
          'imageUrlOptimized': 'https://example.com/icon.webp',
          'imageSizeKbSource': '64',
          'imageSizeKbOptimized': 18,
          'imageOptimizedComplete': true,
          'imageOptimizedLastUpdated': '2026-05-21T13:00:00Z',
          'relID': '88',
          'field': 'icon',
          'relname': 'events',
        },
      });

      final icon = event.iconOptimized;
      expect(icon, isNotNull);
      expect(icon!.id, 'icon-1');
      expect(icon.imageUrlSource, 'https://example.com/icon.png');
      expect(icon.imageUrlOptimized, 'https://example.com/icon.webp');
      expect(icon.imageSizeKbSource, 64);
      expect(icon.imageSizeKbOptimized, 18);
      expect(icon.imageOptimizedComplete, isTrue);
      expect(icon.imageOptimizedLastUpdated, DateTime.utc(2026, 5, 21, 13));
      expect(icon.relId, 88);
      expect(icon.field, 'icon');
      expect(icon.relName, 'events');
      expect(
        Event.fromJson(<String, dynamic>{
          'iconOptimized': 'invalid',
        }).iconOptimized,
        isNull,
      );
    });

    test('decodes Polygolem Gamma optimized featured event image', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'featuredImageOptimized': <String, dynamic>{
          'id': 'featured-image-1',
          'imageUrlSource': 'https://example.com/featured.png',
          'imageUrlOptimized': 'https://example.com/featured.webp',
          'imageSizeKbSource': 256,
          'imageSizeKbOptimized': '72',
          'imageOptimizedComplete': true,
          'imageOptimizedLastUpdated': '2026-05-21T14:15:00Z',
          'relID': 99,
          'field': 'featuredImage',
          'relname': 'events',
        },
      });

      final featuredImage = event.featuredImageOptimized;
      expect(featuredImage, isNotNull);
      expect(featuredImage!.id, 'featured-image-1');
      expect(featuredImage.imageUrlSource, 'https://example.com/featured.png');
      expect(
        featuredImage.imageUrlOptimized,
        'https://example.com/featured.webp',
      );
      expect(featuredImage.imageSizeKbSource, 256);
      expect(featuredImage.imageSizeKbOptimized, 72);
      expect(featuredImage.imageOptimizedComplete, isTrue);
      expect(
        featuredImage.imageOptimizedLastUpdated,
        DateTime.utc(2026, 5, 21, 14, 15),
      );
      expect(featuredImage.relId, 99);
      expect(featuredImage.field, 'featuredImage');
      expect(featuredImage.relName, 'events');
      expect(
        Event.fromJson(<String, dynamic>{
          'featuredImageOptimized': 'invalid',
        }).featuredImageOptimized,
        isNull,
      );
    });

    test('decodes Polygolem Gamma Disqus thread', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'disqusThread': 'event-thread-1',
      });

      expect(event.disqusThread, 'event-thread-1');
    });

    test('decodes Polygolem Gamma parent event', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'parentEvent': 'parent-event-1',
      });

      expect(event.parentEvent, 'parent-event-1');
    });

    test('decodes Polygolem Gamma new-event flag', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'new': true,
      });

      expect(event.isNew, isTrue);
    });

    test('decodes Polygolem Gamma custom-market flag', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'cyom': true,
      });

      expect(event.cyom, isTrue);
      expect(Event.fromJson(<String, dynamic>{'id': 'event-2'}).cyom, isFalse);
    });

    test('decodes Polygolem Gamma show-all-outcomes flag', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'showAllOutcomes': true,
      });

      expect(event.showAllOutcomes, isTrue);
      expect(
        Event.fromJson(<String, dynamic>{'id': 'event-2'}).showAllOutcomes,
        isFalse,
      );
    });

    test('decodes Polygolem Gamma show-market-images flag', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'showMarketImages': true,
      });

      expect(event.showMarketImages, isTrue);
      expect(
        Event.fromJson(<String, dynamic>{'id': 'event-2'}).showMarketImages,
        isFalse,
      );
    });

    test('decodes Polygolem Gamma automatically-resolved flag', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'automaticallyResolved': true,
      });

      expect(event.automaticallyResolved, isTrue);
      expect(
        Event.fromJson(<String, dynamic>{
          'id': 'event-2',
        }).automaticallyResolved,
        isFalse,
      );
    });

    test('decodes Polygolem Gamma enable-negative-risk flag', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'enableNegRisk': true,
      });

      expect(event.enableNegRisk, isTrue);
      expect(
        Event.fromJson(<String, dynamic>{'id': 'event-2'}).enableNegRisk,
        isFalse,
      );
    });

    test('decodes Polygolem Gamma automatically-active flag', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'automaticallyActive': true,
      });

      expect(event.automaticallyActive, isTrue);
      expect(
        Event.fromJson(<String, dynamic>{'id': 'event-2'}).automaticallyActive,
        isFalse,
      );
    });

    test('decodes Polygolem Gamma series slug', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'seriesSlug': 'fomc',
      });

      expect(event.seriesSlug, 'fomc');
      expect(Event.fromJson(<String, dynamic>{'id': 'event-2'}).seriesSlug, '');
    });

    test('decodes Polygolem Gamma event week', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'eventWeek': 23,
      });

      expect(event.eventWeek, 23);
      expect(Event.fromJson(<String, dynamic>{'id': 'event-2'}).eventWeek, 0);
    });

    test('decodes Polygolem Gamma score', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'score': '2-1',
      });

      expect(event.score, '2-1');
      expect(Event.fromJson(<String, dynamic>{'id': 'event-2'}).score, '');
    });

    test('decodes Polygolem Gamma negative-risk fee bips', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'negRisk': true,
        'negRiskMarketID': 'neg-risk-market-1',
        'negRiskFeeBips': 25,
      });

      expect(event.negRisk, isTrue);
      expect(event.negRiskMarketId, 'neg-risk-market-1');
      expect(event.negRiskFeeBips, 25);
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
