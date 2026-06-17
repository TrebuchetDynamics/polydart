import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

const _eoa = '0x2c7536E3605D9C16a7a3D7b1898e529396a65c23';
const _depositWallet = '0xfd5041047be8c192c725a66228f141196fa3cf9c';

void main() {
  test(
    'mock live journey creates credentials, checks readiness, and posts signatureType 3 order',
    () async {
      final signer = _CannedWalletSigner();
      final clobRequests = <String>[];
      final authRequests = <String>[];
      final relayerRequests = <String>[];
      final rpcMethods = <String>[];
      Map<String, dynamic>? postedOrderBody;
      Map<String, String>? postedOrderHeaders;

      final clob = ClobClient(
        transport: HttpTransport(
          config: const TransportConfig(
            baseUrl: ClobClient.defaultBaseUrl,
            retryMax: 0,
          ),
          inner: MockClient((req) async {
            clobRequests.add('${req.method} ${req.url.path}');
            switch (req.url.path) {
              case '/auth/api-key':
                return _apiKeyResponse(
                  key: 'created-clob-key',
                  secret: 'created-clob-secret',
                  passphrase: 'created-clob-pass',
                );
              case '/auth/builder-api-key':
                expect(req.headers['POLY_API_KEY'], 'created-clob-key');
                return _apiKeyResponse(
                  key: 'created-builder-key',
                  secret: 'created-builder-secret',
                  passphrase: 'created-builder-pass',
                );
              case '/balance-allowance':
                expect(req.url.queryParameters['signature_type'], '3');
                return _json(<String, dynamic>{
                  'balance': '2500000',
                  'allowances': <String, String>{
                    '0xCtfExchangeV2': '999999999',
                  },
                });
              case '/tick-size':
                expect(req.url.queryParameters['token_id'], '12345');
                return _json(<String, dynamic>{
                  'minimum_tick_size': '0.01',
                  'minimum_order_size': '5',
                  'tick_size': '0.01',
                });
              case '/order':
                postedOrderBody = jsonDecode(req.body) as Map<String, dynamic>;
                postedOrderHeaders = Map<String, String>.of(req.headers);
                return _json(<String, dynamic>{
                  'success': true,
                  'order_id': 'mock-live-order-1',
                  'status': 'live',
                });
            }
            return http.Response('unexpected CLOB request ${req.url}', 404);
          }),
        ),
        mode: PolydartMode.live,
        liveTradingEnabled: true,
      );
      addTearDown(clob.close);

      final authHttpClient = MockClient((req) async {
        authRequests.add('${req.method} ${req.url.path}');
        switch (req.url.path) {
          case '/nonce':
            return http.Response(
              jsonEncode(<String, dynamic>{'nonce': 'siwe-nonce'}),
              200,
              headers: const <String, String>{
                'set-cookie': 'polymarketnonce=NONCE; Path=/',
              },
            );
          case '/login':
            return http.Response(
              '{}',
              200,
              headers: const <String, String>{
                'set-cookie': 'polymarketsession=SESSION; Path=/',
              },
            );
          case '/relayer/api/auth':
            expect(
              req.headers['Cookie'] ?? req.headers['cookie'],
              contains('polymarketsession=SESSION'),
            );
            return _json(<String, dynamic>{
              'apiKey': 'created-relayer-key',
              'address': _eoa,
              'createdAt': '2026-05-08T00:00:00Z',
            });
        }
        return http.Response('unexpected auth request ${req.url}', 404);
      });

      final store = MemoryCredentialStore();
      final credentials = await LiveCredentialService(
        clob: clob,
        credentialStore: store,
        authHttpClient: authHttpClient,
        gammaBaseUrl: 'https://gamma.example.test',
        relayerBaseUrl: 'https://relayer.example.test',
        nowSeconds: () => 1700000001,
      ).ensure(signer: signer);

      expect(credentials.ready, isTrue);
      expect(credentials.clobApiKey.value!.key, 'created-clob-key');
      expect(credentials.builderFeeKey.value!.key, 'created-builder-key');
      expect(credentials.relayerApiKey.value!.key, 'created-relayer-key');
      expect(signer.signTypedDataCalls, 1);
      expect(signer.personalSignCalls, 1);
      expect(signer.lastTypedData!['primaryType'], 'ClobAuth');
      expect(credentials.toString(), isNot(contains('created-clob-secret')));

      final readiness =
          await DepositWalletReadinessService.checkWithCredentials(
            eoaAddress: signer.address,
            credentials: credentials,
            relayerTransport: HttpTransport(
              config: const TransportConfig(
                baseUrl: defaultRelayerV2BaseUrl,
                retryMax: 0,
              ),
              inner: MockClient((req) async {
                relayerRequests.add('${req.method} ${req.url.path}');
                expect(req.headers['RELAYER_API_KEY'], 'created-relayer-key');
                return _json(<String, dynamic>{'deployed': true});
              }),
            ),
            clob: clob,
            rpcClient: MockClient((req) async {
              final body = jsonDecode(req.body) as Map<String, dynamic>;
              rpcMethods.add(body['method'].toString());
              expect(body['method'], 'eth_call');
              return _rpcResult(_word(1));
            }),
            rpcUrl: 'https://rpc.example.test',
          );

      expect(readiness.status, DepositWalletReadinessStatus.ready);
      expect(readiness.depositWallet, _depositWallet);
      expect(readiness.approvalsChecked, isTrue);
      expect(readiness.fundingChecked, isTrue);
      expect(readiness.clobBalance, '2500000');
      expect(readiness.missingApprovals, isEmpty);

      final response = await createDepositWalletLimitOrder(
        client: clob,
        signer: signer,
        apiKey: credentials.clobApiKey.value!,
        params: const CreateDepositWalletLimitOrderParams(
          tokenId: '12345',
          side: Side.buy,
          price: '0.50',
          size: '10',
        ),
      );

      expect(response.orderId, 'mock-live-order-1');
      expect(postedOrderHeaders!['POLY_ADDRESS'], signer.address);
      final order = postedOrderBody!['order'] as Map<String, dynamic>;
      expect(order['maker'], _depositWallet);
      expect(order['signer'], _depositWallet);
      expect(order['signatureType'], 3);
      expect(order['tokenId'], '12345');
      expect(signer.signTypedDataCalls, 2);
      expect(signer.lastTypedData!['primaryType'], 'TypedDataSign');

      expect(clobRequests, <String>[
        'POST /auth/api-key',
        'POST /auth/builder-api-key',
        'GET /balance-allowance',
        'GET /tick-size',
        'POST /order',
      ]);
      expect(authRequests, <String>[
        'GET /nonce',
        'GET /login',
        'POST /relayer/api/auth',
      ]);
      expect(relayerRequests, <String>['GET /deployed']);
      expect(rpcMethods, List<String>.filled(7, 'eth_call'));
    },
  );
}

class _CannedWalletSigner implements WalletSigner {
  @override
  String get address => _eoa;

  @override
  int get chainId => polymarketChainId;

  var signTypedDataCalls = 0;
  var personalSignCalls = 0;
  Map<String, dynamic>? lastTypedData;

  @override
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData) async {
    signTypedDataCalls++;
    lastTypedData = typedData;
    return _signature(0xab);
  }

  @override
  Future<Uint8List> personalSign(Uint8List message) async {
    personalSignCalls++;
    return _signature(0xcd);
  }
}

Uint8List _signature(int fill) {
  final bytes = Uint8List(65);
  for (var i = 0; i < 64; i++) {
    bytes[i] = fill;
  }
  bytes[64] = 27;
  return bytes;
}

http.Response _apiKeyResponse({
  required String key,
  required String secret,
  required String passphrase,
}) {
  return _json(<String, dynamic>{
    'apiKey': key,
    'secret': secret,
    'passphrase': passphrase,
  });
}

http.Response _rpcResult(String result) {
  return _json(<String, Object?>{'jsonrpc': '2.0', 'id': 1, 'result': result});
}

String _word(int value) {
  return '0x${value.toRadixString(16).padLeft(64, '0')}';
}

http.Response _json(Object body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}
