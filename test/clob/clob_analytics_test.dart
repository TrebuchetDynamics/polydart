// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/clob/clob_analytics_types.dart';
import 'package:polydart/src/clob/clob_client.dart';
import 'package:polydart/src/clob/clob_params.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
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
  group('negRisk', () {
    test('GETs /neg-risk and unwraps the boolean', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{'neg_risk': true}),
          200,
        );
      });
      final result = await client.negRisk('tok-1');
      expect(captured!.path, '/neg-risk');
      expect(captured!.queryParameters['token_id'], 'tok-1');
      expect(result, isTrue);
    });
  });

  group('feeRateBps', () {
    test('GETs /fee-rate and parses an integer', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{'fee_rate_bps': 25}),
          200,
        );
      });
      final result = await client.feeRateBps('tok-1');
      expect(captured!.path, '/fee-rate');
      expect(captured!.queryParameters['token_id'], 'tok-1');
      expect(result, 25);
    });
  });

  group('simplifiedMarkets', () {
    test('GETs /simplified-markets without next_cursor when null', () async {
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
      await client.simplifiedMarkets();
      expect(captured!.path, '/simplified-markets');
      expect(captured!.queryParameters.containsKey('next_cursor'), isFalse);
    });

    test('forwards next_cursor when supplied', () async {
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
      await client.simplifiedMarkets(nextCursor: 'CUR');
      expect(captured!.queryParameters['next_cursor'], 'CUR');
    });
  });

  group('samplingMarkets', () {
    test('GETs /sampling-markets', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'limit': 50,
            'count': 0,
            'next_cursor': '',
            'data': <Object>[],
          }),
          200,
        );
      });
      await client.samplingMarkets(nextCursor: 'A');
      expect(captured!.path, '/sampling-markets');
      expect(captured!.queryParameters['next_cursor'], 'A');
    });
  });

  group('samplingSimplifiedMarkets', () {
    test('GETs /sampling-simplified-markets', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'limit': 50,
            'count': 0,
            'next_cursor': '',
            'data': <Object>[],
          }),
          200,
        );
      });
      await client.samplingSimplifiedMarkets();
      expect(captured!.path, '/sampling-simplified-markets');
    });
  });

  group('prices', () {
    test('POSTs /prices-post and flattens wrapped values', () async {
      String? capturedPath;
      String? capturedBody;
      final client = _client((req) async {
        capturedPath = req.url.path;
        capturedBody = (req as http.Request).body;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'tok-1': <String, dynamic>{'price': '0.50'},
            'tok-2': <String, dynamic>{'price': '0.75'},
          }),
          200,
        );
      });
      final result = await client.prices([
        const BookParams(tokenId: 'tok-1'),
        const BookParams(tokenId: 'tok-2'),
      ]);
      expect(capturedPath, '/prices-post');
      expect(jsonDecode(capturedBody!), [
        <String, dynamic>{'token_id': 'tok-1'},
        <String, dynamic>{'token_id': 'tok-2'},
      ]);
      expect(result['tok-1'], '0.50');
      expect(result['tok-2'], '0.75');
    });

    test('falls back to /prices when /prices-post returns 4xx', () async {
      final hits = <String>[];
      final client = _client((req) async {
        hits.add(req.url.path);
        if (req.url.path == '/prices-post') {
          return http.Response('not found', 404);
        }
        return http.Response(
          jsonEncode(<String, dynamic>{
            'tok-1': <String, dynamic>{'price': '0.40'},
          }),
          200,
        );
      });
      final result = await client.prices([const BookParams(tokenId: 'tok-1')]);
      expect(hits, <String>['/prices-post', '/prices']);
      expect(result['tok-1'], '0.40');
    });
  });

  group('midpoints', () {
    test('POSTs /midpoints and flattens {mid: …}', () async {
      String? capturedPath;
      final client = _client((req) async {
        capturedPath = req.url.path;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'tok-1': <String, dynamic>{'mid': '0.51'},
          }),
          200,
        );
      });
      final result = await client.midpoints([
        const BookParams(tokenId: 'tok-1'),
      ]);
      expect(capturedPath, '/midpoints');
      expect(result['tok-1'], '0.51');
    });
  });

  group('lastTradesPrices', () {
    test('POSTs /last-trades-prices and flattens {price: …}', () async {
      String? capturedPath;
      final client = _client((req) async {
        capturedPath = req.url.path;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'tok-1': <String, dynamic>{'price': '0.42'},
          }),
          200,
        );
      });
      final result = await client.lastTradesPrices([
        const BookParams(tokenId: 'tok-1'),
      ]);
      expect(capturedPath, '/last-trades-prices');
      expect(result['tok-1'], '0.42');
    });
  });

  group('orderScoring', () {
    test('GETs /orders/scoring and unwraps boolean', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{'scoring': true}),
          200,
        );
      });
      final scoring = await client.orderScoring('ord-9');
      expect(captured!.path, '/orders/scoring');
      expect(captured!.queryParameters['order_id'], 'ord-9');
      expect(scoring, isTrue);
    });
  });

  group('ordersScoring', () {
    test('POSTs /orders/scoring with order_ids and decodes a list', () async {
      String? capturedPath;
      String? capturedBody;
      final client = _client((req) async {
        capturedPath = req.url.path;
        capturedBody = (req as http.Request).body;
        return http.Response(jsonEncode(<bool>[true, false, true]), 200);
      });
      final result = await client.ordersScoring(<String>['a', 'b', 'c']);
      expect(capturedPath, '/orders/scoring');
      expect(jsonDecode(capturedBody!), <String, dynamic>{
        'order_ids': <String>['a', 'b', 'c'],
      });
      expect(result, <bool>[true, false, true]);
    });
  });

  group('rewardsConfig', () {
    test('GETs /rewards/config and parses entries', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'market': 'm1',
              'asset_address': '0xasset',
              'rewards_min_size': 100.0,
              'rewards_max_spread': 0.02,
              'active': true,
            },
          ]),
          200,
        );
      });
      final result = await client.rewardsConfig();
      expect(captured!.path, '/rewards/config');
      expect(result, hasLength(1));
      expect(result.first.assetAddress, '0xasset');
      expect(result.first.rewardsMinSize, 100.0);
      expect(result.first.active, isTrue);
    });
  });

  group('rawRewards', () {
    test('GETs /rewards/raw with market query', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'market': 'm1',
              'date': '2026-05-07',
              'rewards_paid': 1.5,
              'volume': 1000.0,
            },
          ]),
          200,
        );
      });
      final result = await client.rawRewards('m1');
      expect(captured!.path, '/rewards/raw');
      expect(captured!.queryParameters['market'], 'm1');
      expect(result.first.rewardsPaid, 1.5);
      expect(result.first.volume, 1000.0);
    });
  });

  group('userEarnings', () {
    test('GETs /rewards/earnings with date query', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'date': '2026-05-07',
              'earnings': 3.21,
              'market': 'm1',
            },
            <String, dynamic>{'date': '2026-05-07', 'earnings': 0.5},
          ]),
          200,
        );
      });
      final result = await client.userEarnings('2026-05-07');
      expect(captured!.path, '/rewards/earnings');
      expect(captured!.queryParameters['date'], '2026-05-07');
      expect(result, hasLength(2));
      expect(result.first.market, 'm1');
      expect(result.last.market, isNull);
    });
  });

  group('totalEarnings', () {
    test('GETs /rewards/total-earnings with date query', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'date': '2026-05-07',
            'earnings': 12.34,
          }),
          200,
        );
      });
      final result = await client.totalEarnings('2026-05-07');
      expect(captured!.path, '/rewards/total-earnings');
      expect(captured!.queryParameters['date'], '2026-05-07');
      expect(result.earnings, 12.34);
    });
  });

  group('rewardPercentages', () {
    test('GETs /rewards/percentages and parses entries', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{'market': 'm1', 'reward_percentage': 0.15},
          ]),
          200,
        );
      });
      final result = await client.rewardPercentages();
      expect(captured!.path, '/rewards/percentages');
      expect(result.first.rewardPercentage, 0.15);
    });
  });

  group('userRewardsByMarket', () {
    test('GETs /rewards/markets and forwards optional params', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'market': 'm1',
              'total_rewards': 5.5,
              'reward_percentage': 0.25,
            },
          ]),
          200,
        );
      });
      final result = await client.userRewardsByMarket(
        const UserRewardsByMarketRequest(
          date: '2026-05-07',
          orderBy: 'total_rewards',
          noCompetition: true,
        ),
      );
      expect(captured!.path, '/rewards/markets');
      expect(captured!.queryParameters['date'], '2026-05-07');
      expect(captured!.queryParameters['order_by'], 'total_rewards');
      expect(captured!.queryParameters['no_competition'], 'true');
      expect(result.first.totalRewards, 5.5);
      expect(result.first.rewardPercentage, 0.25);
    });

    test('omits all query params when none are set', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(jsonEncode(<Object>[]), 200);
      });
      await client.userRewardsByMarket();
      expect(captured!.path, '/rewards/markets');
      expect(captured!.queryParameters, isEmpty);
    });
  });

  group('rebatedFees', () {
    test('GETs /rebates and parses entries with optional market', () async {
      Uri? captured;
      final client = _client((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'maker_address': '0xmaker',
              'market': 'm1',
              'total_rebated': 2.5,
              'date': '2026-05-07',
            },
            <String, dynamic>{
              'maker_address': '0xmaker',
              'total_rebated': 1.0,
              'date': '2026-05-06',
            },
          ]),
          200,
        );
      });
      final result = await client.rebatedFees();
      expect(captured!.path, '/rebates');
      expect(result, hasLength(2));
      expect(result.first.market, 'm1');
      expect(result.last.market, isNull);
      expect(result.first.totalRebated, 2.5);
    });
  });
}
