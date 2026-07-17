// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:polydart/src/types/market.dart';
import 'package:test/test.dart';

import '../shared/json_contracts.dart';

void main() {
  test('Tag.fromJson preserves active event counts', () {
    final tag = Tag.fromJson(<String, dynamic>{
      'id': 'crypto-id',
      'label': 'Crypto',
      'slug': 'crypto',
      'activeEventsCount': 17,
    });

    expect(tag.activeEventsCount, 17);
  });

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
      final m = Market.fromJson(decodeJsonObject(raw));
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
        'umaEndDateIso': '2026-05-22T00:00:00Z',
        'lowerBoundDate': '2026-05-20T00:00:00Z',
        'upperBoundDate': '2026-05-23T00:00:00Z',
        'wideFormat': true,
        'formatType': 'range',
        'lowerBound': '10',
        'upperBound': '20',
        'groupItemThreshold': 'threshold-1',
        'ammType': 'fpmm',
        'fee': '2',
        'denominationToken': 'USDC',
        'sponsorName': 'A Sponsor',
        'sponsorImage': 'https://example.com/sponsor.png',
        'xAxisValue': 'time',
        'yAxisValue': 'price',
        'marketMakerAddress': '0xmaker',
        'mailchimpTag': 'tag-1',
        'resolvedBy': '0xresolver',
        'disqusThread': 'thread-1',
        'creator': 'creator-1',
        'pastSlugs': 'old-slug',
        'createdBy': '3',
        'updatedBy': 4,
        'umaResolutionStatuses': 'proposed,settled',
        'umaBond': '500',
        'umaReward': '25',
        'marketGroup': '8',
        'rewardsMinSize': '25.5',
        'rewardsMaxSpread': 0.03,
        'readyTimestamp': '2026-05-21T12:34:56Z',
        'negRiskFeeBips': 15,
        'twitterCardImage': 'https://example.com/card.png',
        'shortOutcomes': '["Y","N"]',
        'imageOptimized': <String, dynamic>{
          'id': 'image-1',
          'imageUrlSource': 'https://example.com/image.png',
          'imageUrlOptimized': 'https://example.com/image.webp',
          'imageSizeKbSource': 128,
          'imageSizeKbOptimized': 32,
          'imageOptimizedComplete': true,
          'relID': 77,
          'field': 'image',
          'relname': 'markets',
        },
        'iconOptimized': <String, dynamic>{
          'id': 'icon-1',
          'imageUrlSource': 'https://example.com/icon.png',
          'imageUrlOptimized': 'https://example.com/icon.webp',
          'field': 'icon',
        },
        'events': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'event-1', 'title': 'Parent event'},
        ],
        'teamAID': 'team-a',
        'teamBID': 'team-b',
        'gameId': 'game-1',
        'sportsMarketType': 'spread',
        'line': '-2.5',
        'secondsDelay': '15',
        'fpmmLive': true,
        'customLiveness': '120',
        'notificationsEnabled': true,
        'hasReviewedDates': true,
        'readyForCron': true,
        'commentsEnabled': true,
        'curationOrder': '9',
        'score': '0.42',
        'volume24hrAmm': '1.1',
        'volume1wkAmm': '2.2',
        'volume1moAmm': '3.3',
        'volume1yrAmm': '4.4',
        'volume24hrClob': '5.5',
        'volume1wkClob': '6.6',
        'volume1moClob': '7.7',
        'volume1yrClob': '8.8',
        'volumeAmm': '9.9',
        'liquidityAmm': '10.1',
      });

      expect(m.marketType, 'normal');
      expect(m.umaResolutionStatus, 'proposed');
      expect(m.umaEndDateIso, '2026-05-22T00:00:00Z');
      expect(m.lowerBoundDate, DateTime.utc(2026, 5, 20));
      expect(m.upperBoundDate, DateTime.utc(2026, 5, 23));
      expect(m.wideFormat, isTrue);
      expect(m.formatType, 'range');
      expect(m.lowerBound, '10');
      expect(m.upperBound, '20');
      expect(m.groupItemThreshold, 'threshold-1');
      expect(m.ammType, 'fpmm');
      expect(m.fee, '2');
      expect(m.denominationToken, 'USDC');
      expect(m.sponsorName, 'A Sponsor');
      expect(m.sponsorImage, 'https://example.com/sponsor.png');
      expect(m.xAxisValue, 'time');
      expect(m.yAxisValue, 'price');
      expect(m.marketMakerAddress, '0xmaker');
      expect(m.mailchimpTag, 'tag-1');
      expect(m.resolvedBy, '0xresolver');
      expect(m.disqusThread, 'thread-1');
      expect(m.creator, 'creator-1');
      expect(m.pastSlugs, 'old-slug');
      expect(m.createdBy, 3);
      expect(m.updatedBy, 4);
      expect(m.umaResolutionStatuses, 'proposed,settled');
      expect(m.umaBond, '500');
      expect(m.umaReward, '25');
      expect(m.marketGroup, 8);
      expect(m.rewardsMinSize, 25.5);
      expect(m.rewardsMaxSpread, 0.03);
      expect(m.readyTimestamp, DateTime.utc(2026, 5, 21, 12, 34, 56));
      expect(m.negRiskFeeBips, 15);
      expect(m.twitterCardImage, 'https://example.com/card.png');
      expect(m.shortOutcomes, <String>['Y', 'N']);
      expect(m.imageOptimized, isNotNull);
      expect(
        m.imageOptimized!.imageUrlOptimized,
        'https://example.com/image.webp',
      );
      expect(m.iconOptimized, isNotNull);
      expect(m.iconOptimized!.field, 'icon');
      expect(m.events.single.id, 'event-1');
      expect(m.teamAId, 'team-a');
      expect(m.teamBId, 'team-b');
      expect(m.gameId, 'game-1');
      expect(m.sportsMarketType, 'spread');
      expect(m.line, -2.5);
      expect(m.secondsDelay, 15);
      expect(m.fpmmLive, isTrue);
      expect(m.customLiveness, 120);
      expect(m.notificationsEnabled, isTrue);
      expect(m.hasReviewedDates, isTrue);
      expect(m.readyForCron, isTrue);
      expect(m.commentsEnabled, isTrue);
      expect(m.curationOrder, 9);
      expect(m.score, 0.42);
      expect(m.volume24hrAmm, 1.1);
      expect(m.volume1wkAmm, 2.2);
      expect(m.volume1moAmm, 3.3);
      expect(m.volume1yrAmm, 4.4);
      expect(m.volume24hrClob, 5.5);
      expect(m.volume1wkClob, 6.6);
      expect(m.volume1moClob, 7.7);
      expect(m.volume1yrClob, 8.8);
      expect(m.volumeAmm, 9.9);
      expect(m.liquidityAmm, 10.1);
    });

    test('decodes Polygolem Gamma market price/deployment metadata', () {
      final m = Market.fromJson(<String, dynamic>{
        'id': '7',
        'fundedTimestamp': '2026-05-21T12:35:00Z',
        'competitive': '0.9',
        'oneDayPriceChange': '0.01',
        'oneHourPriceChange': 0.02,
        'oneWeekPriceChange': '0.03',
        'oneMonthPriceChange': 0.04,
        'oneYearPriceChange': '0.05',
        'automaticallyResolved': true,
        'automaticallyActive': true,
        'clearBookOnStart': true,
        'manualActivation': true,
        'chartColor': '#123456',
        'seriesColor': '#abcdef',
        'showGmpSeries': true,
        'showGmpOutcome': true,
        'negRiskOther': true,
        'pendingDeployment': true,
        'deploying': true,
        'deployingTimestamp': '2026-05-21T12:36:00Z',
        'scheduledDeploymentTimestamp': '2026-05-21T12:37:00Z',
      });

      expect(m.fundedTimestamp, DateTime.utc(2026, 5, 21, 12, 35));
      expect(m.competitive, 0.9);
      expect(m.oneDayPriceChange, 0.01);
      expect(m.oneHourPriceChange, 0.02);
      expect(m.oneWeekPriceChange, 0.03);
      expect(m.oneMonthPriceChange, 0.04);
      expect(m.oneYearPriceChange, 0.05);
      expect(m.automaticallyResolved, isTrue);
      expect(m.automaticallyActive, isTrue);
      expect(m.clearBookOnStart, isTrue);
      expect(m.manualActivation, isTrue);
      expect(m.chartColor, '#123456');
      expect(m.seriesColor, '#abcdef');
      expect(m.showGmpSeries, isTrue);
      expect(m.showGmpOutcome, isTrue);
      expect(m.negRiskOther, isTrue);
      expect(m.pendingDeployment, isTrue);
      expect(m.deploying, isTrue);
      expect(m.deployingTimestamp, DateTime.utc(2026, 5, 21, 12, 36));
      expect(m.scheduledDeploymentTimestamp, DateTime.utc(2026, 5, 21, 12, 37));
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

    test('decodes Polygolem Gamma elapsed', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'elapsed': '68:42',
      });

      expect(event.elapsed, '68:42');
      expect(Event.fromJson(<String, dynamic>{'id': 'event-2'}).elapsed, '');
    });

    test('decodes Polygolem Gamma period', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'period': '2H',
      });

      expect(event.period, '2H');
      expect(Event.fromJson(<String, dynamic>{'id': 'event-2'}).period, '');
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

    test('decodes Polygolem Gamma live/deployment event metadata', () {
      final event = Event.fromJson(<String, dynamic>{
        'id': 'event-1',
        'live': true,
        'ended': true,
        'finishedTimestamp': '2026-05-21T15:00:00Z',
        'gmpChartMode': 'scoreboard',
        'tweetCount': '7',
        'featuredOrder': 3,
        'estimateValue': true,
        'cantEstimate': true,
        'estimatedValue': '123.45',
        'spreadsMainLine': '1.5',
        'totalsMainLine': 47.5,
        'carouselMap': 'main',
        'pendingDeployment': true,
        'deploying': true,
        'deployingTimestamp': '2026-05-21T16:00:00Z',
        'scheduledDeploymentTimestamp': '2026-05-21T17:00:00Z',
        'gameStatus': 'final',
      });

      expect(event.live, isTrue);
      expect(event.ended, isTrue);
      expect(event.finishedTimestamp, DateTime.utc(2026, 5, 21, 15));
      expect(event.gmpChartMode, 'scoreboard');
      expect(event.tweetCount, 7);
      expect(event.featuredOrder, 3);
      expect(event.estimateValue, isTrue);
      expect(event.cantEstimate, isTrue);
      expect(event.estimatedValue, '123.45');
      expect(event.spreadsMainLine, 1.5);
      expect(event.totalsMainLine, 47.5);
      expect(event.carouselMap, 'main');
      expect(event.pendingDeployment, isTrue);
      expect(event.deploying, isTrue);
      expect(event.deployingTimestamp, DateTime.utc(2026, 5, 21, 16));
      expect(event.scheduledDeploymentTimestamp, DateTime.utc(2026, 5, 21, 17));
      expect(event.gameStatus, 'final');
    });
  });

  group('Category/Collection/EventCreator.fromJson', () {
    test('decodes Polygolem Gamma category metadata', () {
      final category = Category.fromJson(<String, dynamic>{
        'id': 'category-1',
        'label': 'Politics',
        'parentCategory': 'News',
        'slug': 'politics',
        'publishedAt': '2026-05-21T06:00:00Z',
        'createdBy': 'alice',
        'updatedBy': 'bob',
        'createdAt': '2026-05-21T07:00:00Z',
        'updatedAt': '2026-05-21T08:00:00Z',
      });

      expect(category.parentCategory, 'News');
      expect(category.publishedAt, DateTime.utc(2026, 5, 21, 6));
      expect(category.createdBy, 'alice');
      expect(category.updatedBy, 'bob');
      expect(category.createdAt, DateTime.utc(2026, 5, 21, 7));
      expect(category.updatedAt, DateTime.utc(2026, 5, 21, 8));
    });

    test('decodes Polygolem Gamma collection metadata', () {
      final collection = Collection.fromJson(<String, dynamic>{
        'id': 'collection-1',
        'ticker': 'ELECTION',
        'slug': 'election',
        'title': 'Election',
        'subtitle': '2026',
        'collectionType': 'topic',
        'description': 'Election markets',
        'tags': 'politics,election',
        'image': 'https://example.com/image.png',
        'icon': 'https://example.com/icon.png',
        'headerImage': 'https://example.com/header.png',
        'layout': 'grid',
        'active': true,
        'closed': true,
        'archived': true,
        'new': true,
        'featured': true,
        'restricted': true,
        'isTemplate': true,
        'templateVariables': '{"year":2026}',
        'publishedAt': '2026-05-21T06:00:00Z',
        'createdBy': 'alice',
        'updatedBy': 'bob',
        'createdAt': '2026-05-21T07:00:00Z',
        'updatedAt': '2026-05-21T08:00:00Z',
        'commentsEnabled': true,
        'headerImageOptimized': <String, dynamic>{
          'id': 'header-image-1',
          'imageUrlSource': 'https://example.com/header.png',
          'imageUrlOptimized': 'https://example.com/header.webp',
          'imageSizeKbSource': 200,
          'imageSizeKbOptimized': 50,
          'imageOptimizedComplete': true,
          'relID': 6,
          'field': 'headerImage',
          'relname': 'collections',
        },
      });

      expect(collection.collectionType, 'topic');
      expect(collection.headerImage, 'https://example.com/header.png');
      expect(collection.layout, 'grid');
      expect(collection.active, isTrue);
      expect(collection.closed, isTrue);
      expect(collection.archived, isTrue);
      expect(collection.isNew, isTrue);
      expect(collection.featured, isTrue);
      expect(collection.restricted, isTrue);
      expect(collection.isTemplate, isTrue);
      expect(collection.templateVariables, '{"year":2026}');
      expect(collection.publishedAt, DateTime.utc(2026, 5, 21, 6));
      expect(collection.createdBy, 'alice');
      expect(collection.updatedBy, 'bob');
      expect(collection.createdAt, DateTime.utc(2026, 5, 21, 7));
      expect(collection.updatedAt, DateTime.utc(2026, 5, 21, 8));
      expect(collection.commentsEnabled, isTrue);
      expect(collection.headerImageOptimized, isNotNull);
      expect(collection.headerImageOptimized!.field, 'headerImage');
    });

    test(
      'decodes Event nested categories, collections, creators, and subEvents',
      () {
        final event = Event.fromJson(<String, dynamic>{
          'id': 'event-1',
          'categories': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'category-1', 'label': 'Politics'},
          ],
          'collections': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'collection-1', 'title': 'Election'},
          ],
          'eventCreators': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'creator-1',
              'creatorName': 'A Creator',
              'creatorHandle': '@creator',
              'creatorUrl': 'https://example.com/creator',
              'creatorImage': 'https://example.com/creator.png',
              'createdAt': '2026-05-21T09:00:00Z',
              'updatedAt': '2026-05-21T10:00:00Z',
            },
          ],
          'subEvents': <Object>['sub-event-1', 2],
        });

        expect(event.categories.single.id, 'category-1');
        expect(event.collections.single.id, 'collection-1');
        expect(event.eventCreators.single.creatorHandle, '@creator');
        expect(event.subEvents, <String>['sub-event-1', '2']);
        expect(
          event.eventCreators.single.createdAt,
          DateTime.utc(2026, 5, 21, 9),
        );
        expect(
          event.eventCreators.single.updatedAt,
          DateTime.utc(2026, 5, 21, 10),
        );
      },
    );
  });

  group('Tag.fromJson', () {
    test('decodes Polygolem Gamma tag audit metadata', () {
      final tag = Tag.fromJson(<String, dynamic>{
        'id': 'tag-1',
        'label': 'Crypto',
        'slug': 'crypto',
        'forceShow': true,
        'forceHide': true,
        'isCarousel': true,
        'publishedAt': '2026-05-21T07:00:00Z',
        'createdBy': '3',
        'updatedBy': 4,
        'createdAt': '2026-05-21T08:00:00Z',
        'updatedAt': '2026-05-21T09:00:00Z',
      });

      expect(tag.forceShow, isTrue);
      expect(tag.forceHide, isTrue);
      expect(tag.isCarousel, isTrue);
      expect(tag.publishedAt, DateTime.utc(2026, 5, 21, 7));
      expect(tag.createdBy, 3);
      expect(tag.updatedBy, 4);
      expect(tag.createdAt, DateTime.utc(2026, 5, 21, 8));
      expect(tag.updatedAt, DateTime.utc(2026, 5, 21, 9));
    });
  });

  group('Profile.fromJson', () {
    test('decodes Polygolem Gamma search profile metadata', () {
      final profile = Profile.fromJson(<String, dynamic>{
        'id': 'profile-1',
        'name': 'Trader',
        'user': '42',
        'referral': 'friend',
        'createdBy': 1,
        'updatedBy': '2',
        'createdAt': '2026-05-21T10:00:00Z',
        'updatedAt': '2026-05-21T11:00:00Z',
        'utmSource': 'newsletter',
        'utmMedium': 'email',
        'utmCampaign': 'launch',
        'utmContent': 'hero',
        'utmTerm': 'markets',
        'walletActivated': true,
        'pseudonym': 'anon-trader',
        'displayUsernamePublic': true,
        'profileImage': 'https://example.com/profile.png',
        'bio': 'prediction-market user',
        'proxyWallet': '0x1111111111111111111111111111111111111111',
        'profileImageOptimized': <String, dynamic>{
          'id': 'profile-image-1',
          'imageUrlSource': 'https://example.com/profile.png',
          'imageUrlOptimized': 'https://example.com/profile.webp',
          'imageSizeKbSource': 100,
          'imageSizeKbOptimized': 20,
          'imageOptimizedComplete': true,
          'relID': 5,
          'field': 'profileImage',
          'relname': 'profiles',
        },
        'isCloseOnly': true,
        'isCertReq': true,
        'certReqDate': '2026-05-21T12:00:00Z',
      });

      expect(profile.id, 'profile-1');
      expect(profile.user, 42);
      expect(profile.referral, 'friend');
      expect(profile.createdBy, 1);
      expect(profile.updatedBy, 2);
      expect(profile.createdAt, DateTime.utc(2026, 5, 21, 10));
      expect(profile.updatedAt, DateTime.utc(2026, 5, 21, 11));
      expect(profile.utmSource, 'newsletter');
      expect(profile.utmMedium, 'email');
      expect(profile.utmCampaign, 'launch');
      expect(profile.utmContent, 'hero');
      expect(profile.utmTerm, 'markets');
      expect(profile.walletActivated, isTrue);
      expect(profile.pseudonym, 'anon-trader');
      expect(profile.displayUsernamePublic, isTrue);
      expect(profile.bio, 'prediction-market user');
      expect(profile.profileImageOptimized, isNotNull);
      expect(profile.profileImageOptimized!.field, 'profileImage');
      expect(profile.isCloseOnly, isTrue);
      expect(profile.isCertReq, isTrue);
      expect(profile.certReqDate, DateTime.utc(2026, 5, 21, 12));
    });
  });

  group('Team.fromJson', () {
    test('decodes Polygolem Gamma team audit metadata', () {
      final team = Team.fromJson(<String, dynamic>{
        'id': '9',
        'name': 'Lions',
        'league': 'NFL',
        'record': '10-6',
        'logo': 'https://example.com/logo.png',
        'abbreviation': 'LIO',
        'alias': 'lions',
        'createdAt': '2026-05-21T10:00:00Z',
        'updatedAt': '2026-05-21T11:00:00Z',
      });

      expect(team.id, 9);
      expect(team.createdAt, DateTime.utc(2026, 5, 21, 10));
      expect(team.updatedAt, DateTime.utc(2026, 5, 21, 11));
    });
  });

  group('Series.fromJson', () {
    test('decodes Polygolem Gamma series scalar metadata', () {
      final series = Series.fromJson(<String, dynamic>{
        'id': 'series-1',
        'ticker': 'FOMC',
        'slug': 'fomc',
        'title': 'Fed rates',
        'subtitle': 'Monthly',
        'seriesType': 'recurring',
        'recurrence': 'monthly',
        'description': 'Rate decisions',
        'image': 'https://example.com/image.png',
        'icon': 'https://example.com/icon.png',
        'layout': 'grid',
        'active': true,
        'closed': false,
        'archived': false,
        'new': true,
        'featured': true,
        'restricted': true,
        'isTemplate': true,
        'templateVariables': true,
        'publishedAt': '2026-05-21T08:00:00Z',
        'createdBy': '0x1111111111111111111111111111111111111111',
        'updatedBy': '0x2222222222222222222222222222222222222222',
        'createdAt': '2026-05-21T09:00:00Z',
        'updatedAt': '2026-05-21T10:00:00Z',
        'commentsEnabled': true,
        'competitive': '0.8',
        'startDate': '2026-06-01T00:00:00Z',
        'pythTokenID': 'pyth-btc',
        'cgAssetName': 'bitcoin',
        'score': '2.5',
        'volume': 100,
        'volume24hr': 10,
        'liquidity': 20,
        'commentCount': 4,
      });

      expect(series.layout, 'grid');
      expect(series.isNew, isTrue);
      expect(series.featured, isTrue);
      expect(series.restricted, isTrue);
      expect(series.isTemplate, isTrue);
      expect(series.templateVariables, isTrue);
      expect(series.publishedAt, DateTime.utc(2026, 5, 21, 8));
      expect(series.createdBy, '0x1111111111111111111111111111111111111111');
      expect(series.updatedBy, '0x2222222222222222222222222222222222222222');
      expect(series.createdAt, DateTime.utc(2026, 5, 21, 9));
      expect(series.updatedAt, DateTime.utc(2026, 5, 21, 10));
      expect(series.commentsEnabled, isTrue);
      expect(series.competitive, '0.8');
      expect(series.pythTokenId, 'pyth-btc');
      expect(series.cgAssetName, 'bitcoin');
      expect(series.score, 2.5);
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
