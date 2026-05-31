import 'dart:convert';
import 'dart:io';

import 'package:polydart/src/types/clob.dart';
import 'package:polydart/src/types/market.dart';
import 'package:test/test.dart';

import '../shared/json_contracts.dart';

const _fixtureRoot = 'test/fixtures/polymarket/events/fed-decision-in-june-825';

void main() {
  group('Fed decision fixture', () {
    test('preserves Gamma event, market, time, and token truth', () {
      final event = Event.fromJson(_fixtureMap('gamma-event.json'));

      expect(event.id, '101772');
      expect(event.slug, 'fed-decision-in-june-825');
      expect(event.title, 'Fed Decision in June?');
      expect(event.active, isTrue);
      expect(event.closed, isFalse);
      expect(event.archived, isFalse);
      expect(event.endDate, DateTime.utc(2026, 6, 17));
      expect(event.volume, greaterThan(0));
      expect(event.liquidity, greaterThan(0));
      expect(event.openInterest, greaterThan(0));
      expect(event.enableOrderBook, isTrue);
      expect(event.liquidityClob, greaterThan(0));
      expect(event.volume24hr, greaterThan(0));
      expect(event.negRisk, isTrue);
      expect(event.negRiskMarketId, startsWith('0x'));
      expect(event.commentCount, greaterThanOrEqualTo(0));
      expect(event.createdAt, isNotNull);
      expect(event.updatedAt, isNotNull);
      expect(event.series.single.slug, 'fomc');
      expect(event.tags.map((tag) => tag.slug), contains('economic-policy'));
      expect(event.tags.map((tag) => tag.slug), contains('politics'));
      expect(event.markets, hasLength(5));

      final expectedSlugs = <String>{
        'will-the-fed-decrease-interest-rates-by-25-bps-after-the-june-2026-meeting',
        'will-the-fed-increase-interest-rates-by-25-bps-after-the-june-2026-meeting',
        'will-the-fed-decrease-interest-rates-by-50-bps-after-the-june-2026-meeting',
        'will-there-be-no-change-in-fed-interest-rates-after-the-june-2026-meeting',
        'will-the-fed-increase-interest-rates-by-50-bps-after-the-june-2026-meeting',
      };
      expect(event.markets.map((market) => market.slug).toSet(), expectedSlugs);

      for (final market in event.markets) {
        _expectGammaMarketTruth(market);
      }

      expect(
        {
          for (final market in event.markets)
            market.groupItemTitle: market.groupItemThreshold,
        },
        const {
          '50+ bps decrease': '0',
          '25 bps decrease': '1',
          'No change': '2',
          '25 bps increase': '3',
          '50+ bps increase': '4',
        },
      );
    });

    test('finds the event from Gamma public search before detail lookup', () {
      final search = SearchResponse.fromJson(_fixtureMap('gamma-search.json'));

      expect(search.pagination.totalResults, greaterThanOrEqualTo(1));
      final event = search.events.firstWhere(
        (event) => event.slug == 'fed-decision-in-june-825',
      );
      expect(event.id, '101772');
      expect(event.title, 'Fed Decision in June?');
      expect(event.markets, hasLength(5));
      for (final market in event.markets) {
        _expectGammaMarketTruth(market);
      }
    });

    test('parses current abbreviated CLOB market and book fields', () {
      final markets = _fixtureList(
        'clob-markets.json',
      ).whereType<Map<String, dynamic>>().map(ClobMarket.fromJson).toList();

      expect(markets, hasLength(5));
      for (final market in markets) {
        expect(market.conditionId, startsWith('0x'));
        expect(market.tokens, hasLength(2));
        expect(market.tokens.first.tokenId, isNotEmpty);
        expect(market.tokens.first.outcome, isNotEmpty);
        expect(market.acceptingOrders, isTrue);
        expect(market.enableOrderBook, isTrue);
        expect(market.negRisk, isTrue);
        expect(market.orderMinSize, greaterThan(0));
        expect(market.orderPriceMinTickSize, greaterThan(0));
        expect(market.makerBaseFee, greaterThan(0));
        expect(market.takerBaseFee, greaterThan(0));
        expect(market.feeDetails.rate, greaterThan(0));
        expect(market.feeDetails.exponent, greaterThan(0));
        expect(market.feeDetails.takerOnly, isTrue);
        expect(market.rewardsMinSize, greaterThan(0));
        expect(market.rewardsMaxSpread, greaterThan(0));
        expect(market.minimumOrderAge, greaterThan(0));
      }

      final books = _fixtureList(
        'clob-books.json',
      ).whereType<Map<String, dynamic>>().map(OrderBook.fromJson).toList();

      expect(books, hasLength(10));
      for (final book in books) {
        expect(book.market, startsWith('0x'));
        expect(book.assetId, isNotEmpty);
        expect(book.timestamp, isNotEmpty);
        expect(book.hash, isNotEmpty);
        expect(book.bids, isNotEmpty);
        expect(book.asks, isNotEmpty);
        expect(book.minOrderSize, isNotEmpty);
        expect(book.tickSize, isNotEmpty);
        expect(book.negRisk, isTrue);
        expect(book.lastTradePrice, isNotEmpty);
      }
    });
  });
}

void _expectGammaMarketTruth(Market market) {
  expect(market.id, isNotEmpty);
  expect(market.question, isNotEmpty);
  expect(market.slug, isNotEmpty);
  expect(market.conditionId, startsWith('0x'));
  expect(market.endDate, DateTime.utc(2026, 6, 17));
  expect(market.endDateIso, isNotEmpty);
  expect(market.createdAt, isNotNull);
  expect(market.updatedAt, isNotNull);
  expect(market.active, isTrue);
  expect(market.closed, isFalse);
  expect(market.archived, isFalse);
  expect(market.acceptingOrders, isTrue);
  expect(market.enableOrderBook, isTrue);
  expect(market.negRisk, isTrue);
  expect(market.negRiskMarketId, startsWith('0x'));
  expect(market.orderMinSize, greaterThan(0));
  expect(market.orderPriceMinTickSize, greaterThan(0));
  expect(market.makerBaseFee, greaterThan(0));
  expect(market.takerBaseFee, greaterThan(0));
  expect(market.volumeNum, greaterThan(0));
  expect(market.liquidityNum, greaterThan(0));
  expect(market.volumeClob, greaterThan(0));
  expect(market.liquidityClob, greaterThan(0));
  expect(market.spread, greaterThanOrEqualTo(0));
  expect(market.bestBid, inInclusiveRange(0, 1));
  expect(market.bestAsk, inInclusiveRange(0, 1));
  expect(market.outcomes, const ['Yes', 'No']);
  expect(market.outcomePrices, hasLength(2));
  for (final rawPrice in market.outcomePrices) {
    expect(double.parse(rawPrice), inInclusiveRange(0, 1));
  }
  final tokenIds = jsonDecode(market.clobTokenIds) as List<dynamic>;
  expect(tokenIds, hasLength(2));
  expect(tokenIds.every((tokenId) => tokenId.toString().isNotEmpty), isTrue);
}

Map<String, dynamic> _fixtureMap(String name) {
  return decodeJsonObject(File('$_fixtureRoot/$name').readAsStringSync());
}

List<dynamic> _fixtureList(String name) {
  return jsonDecode(File('$_fixtureRoot/$name').readAsStringSync())
      as List<dynamic>;
}
