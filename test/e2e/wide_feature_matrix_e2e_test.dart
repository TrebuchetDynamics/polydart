import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

const _owner = '0x21999a074344610057c9b2B362332388a44502D4';
const _condition =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  test(
    'wide feature matrix e2e covers read, funding, safety, reporting, and tool surfaces',
    () async {
      final bridgeHits = <String>[];
      final bridge = BridgeClient(
        transport: HttpTransport(
          config: const TransportConfig(
            baseUrl: defaultBridgeBaseUrl,
            retryMax: 0,
          ),
          inner: MockClient((req) async {
            bridgeHits.add('${req.method} ${req.url.path}');
            return _routeBridge(req);
          }),
        ),
      );
      addTearDown(bridge.close);

      final assets = await bridge.supportedAssets();
      final quote = await bridge.quote(
        const QuoteRequest(
          fromAmountBaseUnit: '1000000',
          fromChainId: '1',
          fromTokenAddress: '0xa0b8',
          recipientAddress: _owner,
          toChainId: '137',
          toTokenAddress: '0x2791',
        ),
      );
      final depositAddress = await bridge.createDepositAddress(_owner);
      final depositStatus = await bridge.depositStatus('0xdeposit');

      expect(assets.supportedAssets.single.token.symbol, 'USDC');
      expect(quote.quoteId, 'quote-1');
      expect(depositAddress.address.evm, '0xdeposit');
      expect(depositStatus.transactions.single.status, 'confirmed');
      expect(bridgeHits, <String>[
        'GET /supported-assets',
        'POST /quote',
        'POST /deposit',
        'GET /status/0xdeposit',
      ]);

      final relayerHits = <String>[];
      final relayer = RelayerClient.v2(
        apiKey: const V2APIKey(key: 'relayer-key', address: _owner),
        transport: HttpTransport(
          config: const TransportConfig(
            baseUrl: defaultRelayerBaseUrl,
            retryMax: 0,
          ),
          inner: MockClient((req) async {
            relayerHits.add('${req.method} ${req.url.path}?${req.url.query}');
            expect(req.headers['RELAYER_API_KEY'], 'relayer-key');
            return _routeRelayer(req);
          }),
        ),
      );
      addTearDown(relayer.close);

      final nonce = await relayer.getNonce(ownerAddress: _owner);
      final deployed = await relayer.isDeployed(ownerAddress: _owner);
      final tx = await relayer.getTransaction(txId: 'tx-1&unsafe=true');

      expect(nonce, '7');
      expect(deployed.deployed, isTrue);
      expect(tx.transactionId, 'tx-1&unsafe=true');
      expect(relayerHits[2], contains('id=tx-1%26unsafe%3Dtrue'));

      final features = _FeatureDataReader();
      final redeemable = await findRedeemable(features, _owner);
      final redeemCall = buildRedeemCall(redeemable.single);
      final report = await buildReport(
        features,
        user: _owner,
        options: const OrderResultsOptions(limit: 25),
      );

      expect(redeemable.single.conditionId, _condition);
      expect(redeemCall.target, CtfCollateralAdapter);
      expect(redeemCall.value, '0');
      expect(report.summary.won, 1);
      expect(report.summary.dataTrades, 1);
      expect(report.rowByToken('token-yes')!.status, orderResultStatusWon);

      final opportunities =
          await OpportunityRunner(
            OpportunityConfig(gamma: _OpportunitySource()),
          ).run(
            const OpportunityRequest(type: opportunityTypeWideSpread, limit: 1),
          );
      expect(opportunities.opportunities.single.marketId, 'wide-market');

      final preflight = await runPreflight([
        PreflightCheck(
          name: 'bridge',
          probe: () async => bridge.supportedAssets(),
        ),
        PreflightCheck(
          name: 'relayer',
          probe: () async => relayer.isDeployed(ownerAddress: _owner),
        ),
        PreflightCheck(
          name: 'reports',
          probe: () async => buildReport(features, user: _owner),
        ),
      ]);
      expect(preflight.ok, isTrue);
      expect(preflight.checks.map((c) => c.name), <String>[
        'bridge',
        'relayer',
        'reports',
      ]);

      final mcp = McpServer(
        handlers: newReadOnlyMcpHandlers(
          McpHandlerConfig(
            adapters: McpReadOnlyAdapters(
              discoverSearch: (args) => 'searched:${args['query']}',
              dataPositions: (_) => <String, Object?>{
                'user': report.user,
                'won': report.summary.won,
              },
            ),
          ),
        ),
      );
      final mcpResponse = await mcp.handle(
        const McpRequest(
          jsonrpc: '2.0',
          id: 'wide-e2e',
          method: 'tools/call',
          params: <String, Object?>{
            'name': 'polydart.discover_search',
            'arguments': <String, Object?>{'query': 'btc'},
          },
        ),
      );
      expect(mcpResponse.error, isNull);
      expect(jsonEncode(mcpResponse.result), contains('searched:btc'));

      expect(
        () => const RfqClient().submit(
          const RfqRequest(
            marketId: 'wide-market',
            side: rfqSideBuy,
            amount: '1',
          ),
          now: DateTime.utc(2026),
        ),
        throwsA(isA<SafetyException>()),
      );
      expect(openApiSpec()['openapi'], '3.1.0');
    },
  );
}

Future<http.Response> _routeBridge(http.BaseRequest req) async {
  switch (req.url.path) {
    case '/supported-assets':
      return _json(<String, dynamic>{
        'supportedAssets': [
          <String, dynamic>{
            'chainId': '137',
            'chainName': 'Polygon',
            'token': <String, dynamic>{
              'name': 'USD Coin',
              'symbol': 'USDC',
              'address': '0x2791',
              'decimals': 6,
            },
            'minCheckoutUsd': '5',
          },
        ],
      });
    case '/quote':
      final body =
          jsonDecode((req as http.Request).body) as Map<String, dynamic>;
      expect(body['recipientAddress'], _owner);
      return _json(<String, dynamic>{
        'estCheckoutTimeMs': 120000,
        'estFeeBreakdown': <String, dynamic>{
          'appFeeLabel': 'app',
          'appFeePercent': 0,
          'appFeeUsd': 0,
          'fillCostPercent': 0,
          'fillCostUsd': 0,
          'gasUsd': 0.1,
          'maxSlippage': 0.01,
          'minReceived': 0.99,
          'swapImpact': 0,
          'swapImpactUsd': 0,
          'totalImpact': 0.01,
          'totalImpactUsd': 0.1,
        },
        'estInputUsd': '1.00',
        'estOutputUsd': 0.99,
        'estToTokenBaseUnit': '990000',
        'quoteId': 'quote-1',
      });
    case '/deposit':
      final body =
          jsonDecode((req as http.Request).body) as Map<String, dynamic>;
      expect(body['address'], _owner);
      return _json(<String, dynamic>{
        'address': <String, dynamic>{'evm': '0xdeposit', 'svm': '', 'btc': ''},
        'note': 'mock deposit address',
      });
    case '/status/0xdeposit':
      return _json(<String, dynamic>{
        'transactions': [
          <String, dynamic>{
            'fromChainId': '1',
            'fromTokenAddress': '0xa0b8',
            'fromAmountBaseUnit': '1000000',
            'toChainId': '137',
            'toTokenAddress': '0x2791',
            'txHash': '0xtx',
            'createdTimeMs': 1714000000123,
            'status': 'confirmed',
          },
        ],
      });
  }
  return http.Response('unexpected bridge request ${req.url}', 404);
}

Future<http.Response> _routeRelayer(http.BaseRequest req) async {
  switch (req.url.path) {
    case '/nonce':
      expect(req.url.queryParameters['address'], _owner);
      return _json(<String, dynamic>{'nonce': '7'});
    case '/deployed':
      expect(req.url.queryParameters['address'], _owner);
      return _json(<String, dynamic>{'deployed': true, 'address': '0xdeposit'});
    case '/transaction':
      expect(req.url.queryParameters['id'], 'tx-1&unsafe=true');
      expect(req.url.queryParameters.containsKey('unsafe'), isFalse);
      return _json(<String, dynamic>{
        'transactionID': 'tx-1&unsafe=true',
        'state': 'STATE_MINED',
        'from': _owner,
        'to': depositWalletFactoryAddr,
      });
  }
  return http.Response('unexpected relayer request ${req.url}', 404);
}

final class _FeatureDataReader
    implements OrderResultsDataReader, SettlementDataReader {
  @override
  Future<List<Position>> currentPositions(String user, {int limit = 0}) async {
    expect(user, _owner);
    return const <Position>[
      Position(
        tokenId: 'token-yes',
        conditionId: _condition,
        marketId: 'wide-market',
        side: 'YES',
        avgPrice: 0.4,
        size: 10,
        currentPrice: 1,
        unrealizedPnl: 6,
        initialValue: 4,
        currentValue: 10,
        cashPnl: 6,
        redeemable: true,
        outcome: 'Yes',
        title: 'Wide market',
        slug: 'wide-market',
      ),
    ];
  }

  @override
  Future<List<ClosedPosition>> closedPositionsForUser(
    String user, {
    required int limit,
  }) async => const <ClosedPosition>[];

  @override
  Future<List<Trade>> tradesForUser(String user, {required int limit}) async {
    expect(user, _owner);
    return const <Trade>[
      Trade(
        id: 'trade-1',
        market: _condition,
        assetId: 'token-yes',
        side: 'BUY',
        price: 0.4,
        size: 10,
        feeRateBps: 0,
        outcome: 'Yes',
        transactionHash: '0xtx',
        createdAt: '2026-06-16T00:00:00Z',
      ),
    ];
  }
}

final class _OpportunitySource implements OpportunityMarketLister {
  @override
  Future<List<Market>> markets([
    GetMarketsParams params = const GetMarketsParams(),
  ]) async {
    expect(params.active, isTrue);
    expect(params.closed, isFalse);
    final market = Market.fromJson(const <String, dynamic>{
      'id': 'wide-market',
      'condition_id': _condition,
      'question': 'Wide market?',
      'slug': 'wide-market',
      'active': true,
      'closed': false,
      'archived': false,
      'spread': 0.25,
      'volume24hr': 250,
      'liquidityClob': 25,
      'clobTokenIds': '["token-yes","token-no"]',
    });
    return <Market>[market];
  }
}

http.Response _json(Object body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}
