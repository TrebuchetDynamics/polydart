/// Mock-only Flutter Web deposit-wallet order smoke path.
///
/// This is plain Dart so Polydart remains a Dart package. A Flutter app can own
/// this object from Provider, bloc, Riverpod, or State and replace
/// [FakeFlutterWalletSigner] with its wallet SDK adapter.
///
/// Analyze: `dart analyze example/flutter_deposit_wallet_order.dart`
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/polydart.dart';

final class FakeFlutterWalletSigner implements WalletSigner {
  FakeFlutterWalletSigner({
    required this.address,
    this.chainId = polymarketChainId,
    this.rejectTypedData = false,
  });

  @override
  final String address;

  @override
  final int chainId;

  final bool rejectTypedData;

  Map<String, dynamic>? lastTypedData;

  @override
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData) async {
    lastTypedData = typedData;
    if (rejectTypedData) {
      throw const WalletSignatureRejectedException(
        'user rejected typed-data approval',
      );
    }
    return _cannedSignature();
  }

  @override
  Future<Uint8List> personalSign(Uint8List message) async {
    return _cannedSignature();
  }
}

sealed class FlutterDepositWalletOrderSmokeOutcome {
  const FlutterDepositWalletOrderSmokeOutcome();
}

final class FlutterDepositWalletOrderSmokeSuccess
    extends FlutterDepositWalletOrderSmokeOutcome {
  const FlutterDepositWalletOrderSmokeSuccess({
    required this.response,
    required this.depositWallet,
    required this.readiness,
    required this.readinessStatus,
    required this.orderRequestBody,
    required this.orderRequestHeaders,
  });

  final OrderResponse response;
  final String depositWallet;
  final DepositWalletReadiness readiness;
  final String readinessStatus;
  final Map<String, dynamic> orderRequestBody;
  final Map<String, String> orderRequestHeaders;
}

final class FlutterDepositWalletOrderSmokeNeedsAction
    extends FlutterDepositWalletOrderSmokeOutcome {
  const FlutterDepositWalletOrderSmokeNeedsAction({
    required this.readiness,
    required this.orderWasPosted,
  });

  final DepositWalletReadiness readiness;
  final bool orderWasPosted;
}

final class FlutterDepositWalletOrderSmokeRejected
    extends FlutterDepositWalletOrderSmokeOutcome {
  const FlutterDepositWalletOrderSmokeRejected({
    required this.reason,
    required this.orderWasPosted,
  });

  final String reason;
  final bool orderWasPosted;
}

final class FlutterDepositWalletOrderSmoke {
  FlutterDepositWalletOrderSmoke({
    required WalletSigner signer,
    ApiKey apiKey = _mockApiKey,
    CreateDepositWalletLimitOrderParams params = _mockOrderParams,
  }) : _signer = signer,
       _apiKey = apiKey,
       _params = params;

  final WalletSigner _signer;
  final ApiKey _apiKey;
  final CreateDepositWalletLimitOrderParams _params;

  Future<FlutterDepositWalletOrderSmokeOutcome> run() async {
    Map<String, dynamic>? capturedBody;
    Map<String, String>? capturedHeaders;
    var orderWasPosted = false;
    final client = _mockLiveClobClient((req) async {
      switch (req.url.path) {
        case '/balance-allowance':
          return http.Response(
            jsonEncode(<String, dynamic>{
              'balance': '2500000',
              'allowances': <String, String>{'0xCtfExchangeV2': '999999999'},
            }),
            200,
          );
        case '/tick-size':
          return http.Response(
            jsonEncode(<String, dynamic>{
              'minimum_tick_size': '0.01',
              'minimum_order_size': '5',
              'tick_size': '0.01',
            }),
            200,
          );
        case '/order':
          orderWasPosted = true;
          final body = jsonDecode((req as http.Request).body);
          capturedBody = body as Map<String, dynamic>;
          capturedHeaders = Map<String, String>.of(req.headers);
          return http.Response(
            jsonEncode(<String, dynamic>{
              'success': true,
              'order_id': 'mock-order-1',
              'status': 'live',
            }),
            200,
          );
        default:
          return http.Response('not found', 404);
      }
    });

    try {
      final readiness =
          await DepositWalletReadinessService.checkWithCredentials(
            eoaAddress: _signer.address,
            credentials: _mockCredentialReadiness,
            relayerTransport: _mockRelayerTransport(),
            clob: client,
            rpcClient: _mockRpcClient(),
            rpcUrl: 'https://rpc.example.test',
          );
      if (readiness.status != DepositWalletReadinessStatus.ready) {
        return FlutterDepositWalletOrderSmokeNeedsAction(
          readiness: readiness,
          orderWasPosted: orderWasPosted,
        );
      }

      final response = await createDepositWalletLimitOrder(
        client: client,
        signer: _signer,
        apiKey: _apiKey,
        params: _params,
      );
      return FlutterDepositWalletOrderSmokeSuccess(
        response: response,
        depositWallet: readiness.depositWallet,
        readiness: readiness,
        readinessStatus: readiness.status.name,
        orderRequestBody: capturedBody ?? const <String, dynamic>{},
        orderRequestHeaders: capturedHeaders ?? const <String, String>{},
      );
    } on WalletSignatureRejectedException catch (e) {
      return FlutterDepositWalletOrderSmokeRejected(
        reason: e.message,
        orderWasPosted: orderWasPosted,
      );
    } finally {
      client.close();
    }
  }
}

const ApiKey _mockApiKey = ApiKey(
  key: 'mock-clob-key',
  secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  passphrase: 'mock-passphrase',
);

const V2APIKey _mockRelayerApiKey = V2APIKey(
  key: 'mock-relayer-key',
  address: '0x0000000000000000000000000000000000001234',
);

const LiveCredentialReadiness _mockCredentialReadiness =
    LiveCredentialReadiness(
      clobApiKey: CredentialReadiness<ApiKey>(
        status: LiveCredentialStatus.cached,
        value: _mockApiKey,
      ),
      builderFeeKey: CredentialReadiness<ApiKey>(
        status: LiveCredentialStatus.cached,
        value: _mockApiKey,
      ),
      relayerApiKey: CredentialReadiness<V2APIKey>(
        status: LiveCredentialStatus.cached,
        value: _mockRelayerApiKey,
      ),
    );

const CreateDepositWalletLimitOrderParams _mockOrderParams =
    CreateDepositWalletLimitOrderParams(
      tokenId: '12345',
      side: Side.buy,
      price: '0.50',
      size: '10',
    );

HttpTransport _mockRelayerTransport() {
  return HttpTransport(
    config: const TransportConfig(baseUrl: defaultRelayerBaseUrl, retryMax: 0),
    inner: MockClient((req) async {
      if (req.url.path == '/deployed') {
        return http.Response(
          jsonEncode(<String, dynamic>{'deployed': true}),
          200,
        );
      }
      return http.Response('not found', 404);
    }),
  );
}

http.Client _mockRpcClient() {
  return MockClient((req) async {
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    if (body['method'] == 'eth_call') {
      return http.Response(
        jsonEncode(<String, Object>{
          'jsonrpc': '2.0',
          'id': 1,
          'result': _word(1),
        }),
        200,
      );
    }
    return http.Response('not found', 404);
  });
}

String _word(int value) => '0x${value.toRadixString(16).padLeft(64, '0')}';

ClobClient _mockLiveClobClient(
  Future<http.Response> Function(http.BaseRequest) handler,
) {
  return ClobClient(
    transport: HttpTransport(
      config: const TransportConfig(
        baseUrl: ClobClient.defaultBaseUrl,
        retryMax: 0,
      ),
      inner: MockClient(handler),
    ),
    mode: PolydartMode.live,
    liveTradingEnabled: true,
  );
}

Uint8List _cannedSignature() {
  final bytes = Uint8List(65);
  for (var i = 0; i < 64; i++) {
    bytes[i] = i + 1;
  }
  bytes[64] = 27;
  return bytes;
}

Future<void> main() async {
  final signer = FakeFlutterWalletSigner(
    address: '0x0000000000000000000000000000000000001234',
  );
  final outcome = await FlutterDepositWalletOrderSmoke(signer: signer).run();
  if (outcome is FlutterDepositWalletOrderSmokeSuccess) {
    // ignore: avoid_print
    print(jsonEncode(outcome.orderRequestBody));
  }
}
