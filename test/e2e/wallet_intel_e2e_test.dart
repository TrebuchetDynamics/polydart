import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  test(
    'wallet intelligence E2E composes Polydart Data API reads safely',
    () async {
      final hits = <String, int>{};
      final client = Polydart.readOnly(
        dataTransport: HttpTransport(
          config: const TransportConfig(
            baseUrl: DataApiClient.defaultBaseUrl,
            retryMax: 0,
          ),
          inner: MockClient((req) async {
            hits.update(req.url.path, (count) => count + 1, ifAbsent: () => 1);
            return _routeDataApi(req);
          }),
        ),
      );
      addTearDown(client.close);

      final asOf = DateTime.utc(2026, 6, 3);
      final dossier = await client.intel.walletDossier(
        '0xwallet',
        options: DossierOptions(limit: 50, asOf: asOf),
      );

      expect(dossier.wallet, '0xwallet');
      expect(dossier.status, dossierStatusPartial);
      expect(dossier.summary.bets, 2);
      expect(dossier.summary.wins, 2);
      expect(dossier.summary.volume, 10);
      expect(dossier.summary.realizedPnL, 20);
      expect(dossier.score.value, 45);
      expect(dossier.score.language, contains('not a finding'));
      expect(
        dossier.sources.map((s) => s.kind),
        contains('data_api.closed_positions'),
      );
      expect(
        dossier.warnings.join('\n'),
        contains('current positions are present'),
      );

      final alerts = await client.intel.alerts(
        AlertOptions(user: '0xwallet', limit: 50, minScore: 40, asOf: asOf),
      );
      expect(alerts, hasLength(1));
      expect(alerts.single.wallet, '0xwallet');
      expect(alerts.single.score, 45);
      expect(alerts.single.language, contains('not a finding'));

      final leaderboard = await client.intel.leaderboard(
        options: LeaderboardOptions(limit: 5, asOf: asOf),
      );
      expect(leaderboard.single.rank, 7);
      expect(leaderboard.single.wallet, '0xwallet');
      expect(leaderboard.single.score.rawMetrics.bets, 0);

      final flow = await client.intel.marketFlow(
        '0xmarket',
        options: MarketFlowOptions(limit: 3, asOf: asOf),
      );
      expect(flow.market, '0xmarket');
      expect(flow.holderCount, 2);
      expect(flow.holderShares, 13);
      expect(flow.holderVolume, 125);
      expect(flow.tradeCount, 2);
      expect(flow.tradeNotional, 6);
      expect(flow.openInterest, 200);
      expect(flow.candidateSignal, isTrue);

      expect(hits['/closed-positions'], greaterThanOrEqualTo(2));
      expect(hits['/positions'], greaterThanOrEqualTo(2));
      expect(hits['/trades'], greaterThanOrEqualTo(3));
      expect(hits['/holders'], 1);
      expect(hits['/oi'], 1);
      expect(hits['/v1/leaderboard'], 1);
    },
  );
}

Future<http.Response> _routeDataApi(http.BaseRequest req) async {
  switch (req.url.path) {
    case '/closed-positions':
      expect(req.url.queryParameters['user'], '0xwallet');
      expect(req.url.queryParameters['limit'], '50');
      return _json(<Map<String, dynamic>>[
        <String, dynamic>{
          'asset': 'won-1',
          'conditionId': 'condition-1',
          'proxyWallet': '0xwallet',
          'avgPrice': '0.50',
          'size': '10',
          'totalBought': '5',
          'realizedPnl': '10',
          'timestamp': '2026-06-02T10:00:00Z',
        },
        <String, dynamic>{
          'asset': 'won-2',
          'conditionId': 'condition-2',
          'proxyWallet': '0xwallet',
          'avgPrice': '0.50',
          'size': '10',
          'totalBought': '5',
          'realizedPnl': '10',
          'timestamp': '2026-06-02T11:00:00Z',
        },
      ]);
    case '/positions':
      expect(req.url.queryParameters['user'], '0xwallet');
      expect(req.url.queryParameters['limit'], '50');
      return _json(<Map<String, dynamic>>[
        <String, dynamic>{
          'asset': 'open-1',
          'conditionId': 'condition-open',
          'proxyWallet': '0xwallet',
          'size': '4',
          'avgPrice': '0.25',
          'curPrice': '0.40',
          'currentValue': '1.60',
        },
      ]);
    case '/trades':
      if (req.url.queryParameters.containsKey('user')) {
        expect(req.url.queryParameters['user'], '0xwallet');
        expect(req.url.queryParameters['limit'], '50');
        return _json(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'user-trade-1',
            'conditionId': 'condition-1',
            'asset': 'won-1',
            'proxyWallet': '0xwallet',
            'side': 'BUY',
            'price': '0.50',
            'size': '10',
          },
        ]);
      }
      expect(req.url.queryParameters['market'], '0xmarket');
      expect(req.url.queryParameters['limit'], '3');
      return _json(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'market-trade-1',
          'conditionId': '0xmarket',
          'asset': 'yes-token',
          'price': '0.50',
          'size': '10',
        },
        <String, dynamic>{
          'id': 'market-trade-2',
          'conditionId': '0xmarket',
          'asset': 'no-token',
          'price': '0.25',
          'size': '4',
        },
      ]);
    case '/v1/leaderboard':
      expect(req.url.queryParameters['limit'], '5');
      return _json(<Map<String, dynamic>>[
        <String, dynamic>{
          'rank': 7,
          'user': '0xwallet',
          'volume': '1000',
          'pnl': '125',
          'roi': '0.125',
        },
      ]);
    case '/holders':
      expect(req.url.queryParameters['market'], '0xmarket');
      expect(req.url.queryParameters['limit'], '3');
      return _json(<Map<String, dynamic>>[
        <String, dynamic>{
          'proxyWallet': '0xa',
          'shares': '10',
          'volume': '100',
        },
        <String, dynamic>{'proxyWallet': '0xb', 'shares': '3', 'volume': '25'},
      ]);
    case '/oi':
      expect(req.url.queryParameters['market'], '0xmarket');
      return _json(<Map<String, dynamic>>[
        <String, dynamic>{'market': '0xmarket', 'open_value': '200'},
      ]);
  }
  return http.Response('unexpected ${req.url}', 404);
}

http.Response _json(Object body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}
