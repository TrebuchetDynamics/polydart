import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  test(
    'random explicit private-key EOA plans a Polymarket smart-wallet journey without broadcasting',
    () async {
      final privateKey = _randomPrivateKeyHex();
      final signer = LocalEoaSigner(privateKeyHex: privateKey, chainId: 137);
      final owner = signer.address;
      final depositWallet = deriveDepositWallet(owner);

      expect(owner, matches(RegExp(r'^0x[0-9a-fA-F]{40}$')));
      expect(depositWallet, matches(RegExp(r'^0x[0-9a-f]{40}$')));
      expect(depositWallet, isNot(owner.toLowerCase()));
      expect(privateKey, isNot(contains(owner.substring(2).toLowerCase())));

      final relayerSubmits = <Map<String, dynamic>>[];
      final relayer = RelayerClient.v2(
        apiKey: V2APIKey(key: 'mock-relayer-key', address: owner),
        transport: HttpTransport(
          config: const TransportConfig(
            baseUrl: defaultRelayerBaseUrl,
            retryMax: 0,
          ),
          inner: MockClient((req) async {
            expect(req.headers['RELAYER_API_KEY'], 'mock-relayer-key');
            expect(req.headers['RELAYER_API_KEY_ADDRESS'], owner);
            switch (req.url.path) {
              case '/submit':
                final body = jsonDecode(req.body) as Map<String, dynamic>;
                relayerSubmits.add(body);
                return _json(<String, dynamic>{
                  'transactionID': 'relayer-tx-${relayerSubmits.length}',
                  'state': relayerSubmits.length == 1
                      ? 'STATE_NEW'
                      : 'STATE_EXECUTED',
                  'type': body['type'],
                  'proxyAddress': depositWallet,
                });
              default:
                return http.Response(
                  'unexpected relayer request ${req.url}',
                  404,
                );
            }
          }),
        ),
      );
      addTearDown(relayer.close);

      final deployTx = await relayer.submitWalletCreate(ownerAddress: owner);

      expect(deployTx.transactionId, 'relayer-tx-1');
      expect(deployTx.type, 'WALLET-CREATE');
      expect(deployTx.proxyAddress, depositWallet);
      expect(relayerSubmits.single, <String, dynamic>{
        'type': 'WALLET-CREATE',
        'from': owner,
        'to': depositWalletFactoryAddr,
      });

      final fundingPlan = buildEoaPusdTransferPlan(
        ownerEoa: owner,
        depositWallet: depositWallet,
        amountBaseUnits: BigInt.from(2500000),
      );

      final fundingTx = fundingPlan.toJson();
      expect(fundingTx['from'], owner.toLowerCase());
      expect(fundingTx['to'], PUSD);
      expect(fundingTx['value'], '0x0');
      expect(
        fundingTx['data'],
        '0x$pusdTransferSelector'
        '${depositWallet.substring(2).padLeft(64, '0')}'
        '${_uint256Hex(BigInt.from(2500000))}',
      );
      expect(fundingTx['chainId'], '0x89');

      final approvalCalls = buildEnableTradingApprovalCalls();
      expect(approvalCalls.map((call) => call.target), <String>[PUSD, USDCE]);
      expect(
        approvalCalls.first.data,
        contains(CTF.substring(2).toLowerCase()),
      );
      expect(
        approvalCalls.last.data,
        contains(CollateralOnramp.substring(2).toLowerCase()),
      );
      final approvalSignature = await signEnableTradingApprovalBatchTypedData(
        signer: signer,
        depositWallet: depositWallet,
        nonce: '6',
        deadline: '1778373936',
        calls: approvalCalls,
      );
      final approvalTx = await relayer.submitWalletBatch(
        ownerAddress: owner,
        walletAddress: depositWallet,
        nonce: '6',
        signature: approvalSignature,
        deadline: '1778373936',
        calls: approvalCalls,
      );

      expect(approvalSignature, matches(RegExp(r'^0x[0-9a-f]{130}$')));
      expect(approvalTx.transactionId, 'relayer-tx-2');
      expect(relayerSubmits.last['type'], 'WALLET');
      expect(relayerSubmits.last['from'], owner);
      expect(relayerSubmits.last['to'], depositWalletFactoryAddr);
      expect(relayerSubmits.last['signature'], approvalSignature);
      final params =
          relayerSubmits.last['depositWalletParams'] as Map<String, dynamic>;
      expect(params['depositWallet'], depositWallet);
      expect(params['deadline'], '1778373936');
      expect(params['calls'], hasLength(2));

      Map<String, dynamic>? postedOrder;
      Map<String, String>? postedOrderHeaders;
      final clob = ClobClient(
        mode: PolydartMode.live,
        liveTradingEnabled: true,
        transport: HttpTransport(
          config: const TransportConfig(
            baseUrl: ClobClient.defaultBaseUrl,
            retryMax: 0,
          ),
          inner: MockClient((req) async {
            switch (req.url.path) {
              case '/tick-size':
                return _json(<String, dynamic>{
                  'minimum_tick_size': '0.01',
                  'minimum_order_size': '5',
                  'tick_size': '0.01',
                });
              case '/order':
                postedOrderHeaders = Map<String, String>.of(req.headers);
                postedOrder = jsonDecode(req.body) as Map<String, dynamic>;
                return _json(<String, dynamic>{
                  'success': true,
                  'orderID': 'mock-order-1',
                  'status': 'live',
                });
              default:
                return http.Response('unexpected CLOB request ${req.url}', 404);
            }
          }),
        ),
      );
      addTearDown(clob.close);

      final orderResponse = await createDepositWalletLimitOrder(
        client: clob,
        signer: signer,
        apiKey: const ApiKey(
          key: 'mock-clob-key',
          secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
          passphrase: 'mock-passphrase',
        ),
        params: const CreateDepositWalletLimitOrderParams(
          tokenId: '12345',
          side: Side.buy,
          price: '0.50',
          size: '10',
        ),
      );

      expect(orderResponse.orderId, 'mock-order-1');
      expect(postedOrderHeaders!['POLY_ADDRESS'], owner);
      expect(postedOrder!['owner'], 'mock-clob-key');
      final order = postedOrder!['order'] as Map<String, dynamic>;
      expect(order['maker'], depositWallet);
      expect(order['signer'], depositWallet);
      expect(order['signatureType'], 3);
      expect(order['tokenId'], '12345');
      expect(postedOrder!['orderType'], 'GTC');
      expect(postedOrder!['postOnly'], isFalse);
      expect(order['signature'], matches(RegExp(r'^0x[0-9a-f]+$')));
      expect((order['signature'] as String).length, 636);
    },
  );
}

String _uint256Hex(BigInt value) => value.toRadixString(16).padLeft(64, '0');

String _randomPrivateKeyHex() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  // Keep the scalar definitely below the secp256k1 order while still random.
  bytes[0] = 1 + random.nextInt(0x7f);
  return '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
}

http.Response _json(Object body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}
