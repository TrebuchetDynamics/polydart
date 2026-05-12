// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/auth/l2.dart';
import 'package:polydart/src/auth/wallet_signer.dart';
import 'package:polydart/src/clob/clob_client.dart';
import 'package:polydart/src/modes/modes.dart';
import 'package:polydart/src/orders/order_builder.dart';
import 'package:polydart/src/orders/order_placement.dart';
import 'package:polydart/src/orders/order_signing.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:polydart/src/types/enums.dart';
import 'package:test/test.dart';

class _CannedSigner implements WalletSigner {
  _CannedSigner();
  @override
  String get address => '0x0000000000000000000000000000000000001234';
  @override
  int get chainId => 137;

  Map<String, dynamic>? lastTyped;

  @override
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData) async {
    lastTyped = typedData;
    final bytes = Uint8List(65);
    for (var i = 0; i < 65; i++) {
      bytes[i] = i;
    }
    return bytes;
  }

  @override
  Future<Uint8List> personalSign(Uint8List message) async => Uint8List(65);
}

const _testApiKey = ApiKey(
  key: 'aaaaaaaa-bbbb-cccc-dddd-eeeeffff0001',
  secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  passphrase: 'pp1',
);

ClobClient _client(Future<http.Response> Function(http.BaseRequest) handler) {
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

void main() {
  group('signOrderV2', () {
    test('produces a SignedOrder for an EOA limit-buy intent', () async {
      final intent =
          (OrderBuilder(tokenId: '12345', side: Side.buy)
                ..price('0.50')
                ..size('10')
                ..tickSize('0.01'))
              .build();

      final signer = _CannedSigner();
      final signed = await signOrderV2(intent: intent, signer: signer);

      expect(signed.maker, signer.address);
      expect(signed.signer, signer.address);
      expect(signed.tokenId, '12345');
      expect(signed.side, Side.buy);
      expect(signed.signature.startsWith('0x'), isTrue);
      // Signed timestamp should be a recent millis epoch.
      expect(signed.timestamp, isNotNull);
      // typed-data presented to the wallet should have primaryType=Order
      expect(signer.lastTyped!['primaryType'], 'Order');
    });

    test('uses funder as maker for non-EOA signature types', () async {
      final intent =
          (OrderBuilder(tokenId: '12345', side: Side.buy)
                ..price('0.50')
                ..size('10')
                ..tickSize('0.01')
                ..signatureType(SignatureType.poly1271)
                ..funder('0xDeposit'))
              .build();

      final signer = _CannedSigner();
      final signed = await signOrderV2(intent: intent, signer: signer);

      expect(signed.maker, '0xDeposit');
      expect(signed.signer, signer.address);
      expect(signed.signatureType, SignatureType.poly1271);
    });
  });

  group('createLimitOrder', () {
    test('looks up tickSize, signs, and POSTs /order', () async {
      String? lastPath;
      final client = _client((req) async {
        lastPath = req.url.path;
        switch (req.url.path) {
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
            return http.Response(
              jsonEncode(<String, dynamic>{
                'success': true,
                'order_id': 'ord-9',
                'status': 'matched',
              }),
              200,
            );
          default:
            return http.Response('not found', 404);
        }
      });

      final resp = await createLimitOrder(
        client: client,
        signer: _CannedSigner(),
        apiKey: _testApiKey,
        params: const CreateLimitOrderParams(
          tokenId: '12345',
          side: Side.buy,
          price: '0.50',
          size: '10',
        ),
      );

      expect(lastPath, '/order');
      expect(resp.orderId, 'ord-9');
    });
  });

  group('createMarketOrder', () {
    test('uses amountUsdc and POSTs /order', () async {
      String? lastPath;
      final client = _client((req) async {
        lastPath = req.url.path;
        switch (req.url.path) {
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
            return http.Response(
              jsonEncode(<String, dynamic>{
                'success': true,
                'order_id': 'ord-mkt-1',
                'status': 'matched',
              }),
              200,
            );
          default:
            return http.Response('not found', 404);
        }
      });

      final resp = await createMarketOrder(
        client: client,
        signer: _CannedSigner(),
        apiKey: _testApiKey,
        params: const CreateMarketOrderParams(
          tokenId: '12345',
          side: Side.buy,
          amount: '5',
        ),
      );

      expect(lastPath, '/order');
      expect(resp.orderId, 'ord-mkt-1');
    });
  });
}
