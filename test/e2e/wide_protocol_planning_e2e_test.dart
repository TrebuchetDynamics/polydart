import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

const _owner = '0x2c7536E3605D9C16a7a3D7b1898e529396a65c23';
const _wallet = '0xfd5041047be8c192c725a66228f141196fa3cf9c';
const _condition =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  test(
    'wide protocol planning e2e covers builder, CTF, funding, approvals, RPC, fills, and universal reads',
    () async {
      final builder = LocalBuilderSigner(
        const LocalBuilderSignerConfig(
          key: 'builder-key',
          secret: 'YnVpbGRlci1zZWNyZXQ=',
          passphrase: 'builder-pass',
        ),
      );
      final builderHeaders = await builder.createHeaders(
        method: 'POST',
        path: '/submit',
        body: '{"ok":true}',
        timestamp: 1700000000,
      );
      expect(builderHeaders[polyBuilderApiKeyHeader], 'builder-key');
      expect(builderHeaders[polyBuilderSignatureHeader], isNotEmpty);

      final profileBody = newCreateProfileRequest(
        eoaAddress: _owner,
        proxyWallet: _wallet,
        provider: 'walletconnect',
        nowMillis: 1700000000000,
      );
      final profile = await createProfile(
        client: MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(req.url.path, '/profiles');
          expect(body['proxyWallet'], _wallet);
          return _json(<String, dynamic>{
            'id': 'profile-1',
            'name': body['name'],
            'proxyWallet': body['proxyWallet'],
            'pseudonym': body['pseudonym'],
          });
        }),
        gammaBaseUrl: 'https://gamma.example.test',
        body: profileBody,
      );
      expect(profile.proxyWallet, _wallet);

      final collection = collectionId(bytes32Zero, _condition, BigInt.one);
      final pos = positionId(usdcAddress, collection);
      final split = splitPositionData(
        collateralToken: usdcAddress,
        parentCollectionId: bytes32Zero,
        conditionId: _condition,
        partition: <BigInt>[BigInt.one, BigInt.two],
        amount: BigInt.from(10),
      );
      final redeem = redeemPositionsData(
        collateralToken: usdcAddress,
        parentCollectionId: bytes32Zero,
        conditionId: _condition,
        indexSets: <BigInt>[BigInt.one],
      );
      expect(collection, startsWith('0x'));
      expect(pos, startsWith('0x'));
      expect(split, startsWith('0x'));
      expect(redeem, startsWith('0x'));

      final approvalCalls = buildEnableTradingApprovalCalls();
      validateEnableTradingApprovalCalls(approvalCalls);
      final adapterCalls = buildAdapterApprovalCalls();
      expect(adapterCalls, isNotEmpty);

      final transferPlan = buildEoaPusdTransferPlan(
        ownerEoa: _owner,
        depositWallet: _wallet,
        amountBaseUnits: BigInt.from(2500000),
      );
      final walletTransfer = buildPusdTransferCall(
        toAddress: _wallet,
        amountBaseUnits: BigInt.from(1000000),
      );
      expect(transferPlan.toJson()['chainId'], '0x89');
      expect(walletTransfer.target, PUSD);

      final rpcMethods = <String>[];
      final rpcClient = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        rpcMethods.add(body['method'].toString());
        switch (body['method']) {
          case 'eth_getCode':
            return _rpc('0x60016000');
          case 'eth_call':
            return _rpc(_word(1));
        }
        return http.Response('unexpected rpc ${body['method']}', 500);
      });
      expect(
        await hasCode(_wallet, rpcUrl: 'http://rpc.test', client: rpcClient),
        isTrue,
      );
      expect(
        await erc20Allowance(
          PUSD,
          _owner,
          _wallet,
          rpcUrl: 'http://rpc.test',
          client: rpcClient,
        ),
        BigInt.one,
      );
      expect(
        await isApprovedForAll(
          conditionalTokensAddress,
          _owner,
          _wallet,
          rpcUrl: 'http://rpc.test',
          client: rpcClient,
        ),
        isTrue,
      );
      expect(rpcMethods, <String>['eth_getCode', 'eth_call', 'eth_call']);

      final route = await planEoaPusdFundingRoute(
        ownerEoa: _owner,
        depositWallet: _wallet,
        requestedAmountBaseUnits: BigInt.from(1000000),
        rpcUrl: 'http://rpc.test',
        rpcClient: MockClient((req) async => _rpc(_word(2500000))),
      );
      expect(route.status, PusdFundingRouteStatus.ready);
      expect(route.transfer!.depositWallet, _wallet.toLowerCase());

      final fill = normalizeOrderFill(
        OrderFill(
          txHash: '0xtx',
          logIndex: 1,
          exchange: CTFExchangeV2,
          marketId: 'market-1',
          conditionId: _condition,
          tokenId: 'token-yes',
          side: ' buy ',
          price: '0.50',
          size: '10',
          blockNumber: 123,
          filledAt: DateTime.utc(2026),
          source: '',
        ),
      );
      validateOrderFill(fill);
      validateOrderFillsQuery(const OrderFillsQuery(fromBlock: 1, toBlock: 2));
      expect(fill.side, orderFillSideBuy);
      expect(fill.source, orderFillSourceOnchainOrderFilled);

      final universal = UniversalClient(
        config: UniversalConfig(
          gammaTransport: _transport(GammaClient.defaultBaseUrl, (req) async {
            return _json(<Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'm1',
                'slug': 'btc',
                'active': true,
                'closed': false,
              },
            ]);
          }),
          clobTransport: _transport(ClobClient.defaultBaseUrl, (req) async {
            return _json(<String, dynamic>{'price': '0.42'});
          }),
          dataTransport: _transport(DataApiClient.defaultBaseUrl, (req) async {
            return _json(<Map<String, dynamic>>[
              <String, dynamic>{
                'token_id': 'token-yes',
                'condition_id': _condition,
                'market_id': 'market-1',
                'side': 'YES',
                'avg_price': '0.40',
                'size': '10',
                'current_price': '0.42',
                'unrealized_pnl': '0.2',
              },
            ]);
          }),
        ),
      );
      addTearDown(universal.close);
      expect((await universal.activeMarkets()).single.slug, 'btc');
      expect(await universal.price('token-yes', 'BUY'), '0.42');
      expect(
        (await universal.currentPositions(_owner)).single.tokenId,
        'token-yes',
      );
    },
  );
}

HttpTransport _transport(
  String baseUrl,
  Future<http.Response> Function(http.Request req) handler,
) {
  return HttpTransport(
    config: TransportConfig(baseUrl: baseUrl, retryMax: 0),
    inner: MockClient((req) async => handler(req)),
  );
}

http.Response _json(Object body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

http.Response _rpc(String result) =>
    _json(<String, Object?>{'jsonrpc': '2.0', 'id': 1, 'result': result});

String _word(int value) => '0x${value.toRadixString(16).padLeft(64, '0')}';
