// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/auth/create2.dart';
import 'package:polydart/src/auth/l2.dart';
import 'package:polydart/src/auth/wallet_signer.dart';
import 'package:polydart/src/clob/clob_client.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/modes/modes.dart';
import 'package:polydart/src/orders/deposit_wallet_order_signing.dart';
import 'package:polydart/src/orders/order_builder.dart';
import 'package:polydart/src/orders/order_placement.dart';
import 'package:polydart/src/orders/order_signing.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:polydart/src/types/enums.dart';
import 'package:test/test.dart';

class _CannedSigner implements WalletSigner {
  _CannedSigner({this.chainId = 137});
  @override
  String get address => '0x0000000000000000000000000000000000001234';
  @override
  final int chainId;

  Map<String, dynamic>? lastTyped;
  int signTypedDataCalls = 0;

  @override
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData) async {
    signTypedDataCalls++;
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

    test('rejects non-Polygon signer before wallet signing', () async {
      final intent =
          (OrderBuilder(tokenId: '12345', side: Side.buy)
                ..price('0.50')
                ..size('10')
                ..tickSize('0.01'))
              .build();

      final signer = _CannedSigner(chainId: 1);

      await expectLater(
        signOrderV2(intent: intent, signer: signer),
        throwsA(
          isA<ValidationException>()
              .having(
                (error) => error.message,
                'message',
                contains('order signing requires Polygon chainId=137'),
              )
              .having((error) => error.field, 'field', 'chainId'),
        ),
      );
      expect(signer.signTypedDataCalls, 0);
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

    test(
      'wraps deposit-wallet orders with ERC-7739 approval envelope',
      () async {
        final signer = _CannedSigner();
        final depositWallet = deriveDepositWallet(signer.address);
        final intent =
            (OrderBuilder(tokenId: '12345', side: Side.buy)
                  ..price('0.50')
                  ..size('10')
                  ..tickSize('0.01')
                  ..signatureType(SignatureType.poly1271)
                  ..funder(depositWallet))
                .build();

        final signed = await signDepositWalletOrderV2(
          intent: intent,
          signer: signer,
          depositWallet: depositWallet,
        );

        expect(signed.maker, depositWallet);
        expect(signed.signer, depositWallet);
        expect(signed.signatureType, SignatureType.poly1271);
        expect(signed.signature.length, 636);
        expect(signer.lastTyped!['primaryType'], 'TypedDataSign');
        final message = signer.lastTyped!['message'] as Map<String, dynamic>;
        expect(message['verifyingContract'], depositWallet);
        final contents = message['contents'] as Map<String, dynamic>;
        expect(contents['maker'], depositWallet);
        expect(contents['signer'], depositWallet);
        expect(contents['signatureType'], 3);
      },
    );
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

    test(
      'deposit-wallet helper derives maker, wraps signature, and uses EOA auth',
      () async {
        http.BaseRequest? orderRequest;
        String? orderBody;
        final signer = _CannedSigner();
        final depositWallet = deriveDepositWallet(signer.address);
        final client = _client((req) async {
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
              orderRequest = req;
              orderBody = (req as http.Request).body;
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'success': true,
                  'order_id': 'ord-dw-1',
                  'status': 'live',
                }),
                200,
              );
            default:
              return http.Response('not found', 404);
          }
        });

        final resp = await createDepositWalletLimitOrder(
          client: client,
          signer: signer,
          apiKey: _testApiKey,
          params: const CreateDepositWalletLimitOrderParams(
            tokenId: '12345',
            side: Side.buy,
            price: '0.50',
            size: '10',
          ),
        );

        expect(resp.orderId, 'ord-dw-1');
        expect(orderRequest!.headers['POLY_ADDRESS'], signer.address);
        expect(signer.lastTyped!['primaryType'], 'TypedDataSign');
        final body = jsonDecode(orderBody!) as Map<String, dynamic>;
        expect(body['owner'], _testApiKey.key);
        final order = body['order'] as Map<String, dynamic>;
        expect(order['maker'], depositWallet);
        expect(order['signer'], depositWallet);
        expect(order['signatureType'], 3);
        expect((order['signature'] as String).length, 636);
      },
    );
  });

  group('createDepositWalletLimitOrders', () {
    test(
      'signs each order as deposit wallet and POSTs /orders with EOA auth',
      () async {
        http.BaseRequest? orderRequest;
        String? orderBody;
        final signer = _CannedSigner();
        final depositWallet = deriveDepositWallet(signer.address);
        final client = _client((req) async {
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
            case '/orders':
              orderRequest = req;
              orderBody = (req as http.Request).body;
              return http.Response(
                jsonEncode(<Map<String, dynamic>>[
                  <String, dynamic>{
                    'success': true,
                    'orderID': 'ord-batch-1',
                    'status': 'live',
                  },
                  <String, dynamic>{
                    'success': true,
                    'orderID': 'ord-batch-2',
                    'status': 'live',
                  },
                ]),
                200,
              );
            default:
              return http.Response('not found', 404);
          }
        });

        final resp = await createDepositWalletLimitOrders(
          client: client,
          signer: signer,
          apiKey: _testApiKey,
          orders: const <CreateDepositWalletLimitOrderParams>[
            CreateDepositWalletLimitOrderParams(
              tokenId: '12345',
              side: Side.buy,
              price: '0.50',
              size: '10',
            ),
            CreateDepositWalletLimitOrderParams(
              tokenId: '12346',
              side: Side.sell,
              price: '0.60',
              size: '3',
              postOnly: true,
            ),
          ],
        );

        expect(resp.orders.map((o) => o.orderId), [
          'ord-batch-1',
          'ord-batch-2',
        ]);
        expect(orderRequest!.method, 'POST');
        expect(orderRequest!.url.path, '/orders');
        expect(orderRequest!.headers['POLY_ADDRESS'], signer.address);
        final body = jsonDecode(orderBody!) as List<dynamic>;
        expect(body, hasLength(2));
        expect((body.last as Map<String, dynamic>)['postOnly'], isTrue);
        for (final row in body.cast<Map<String, dynamic>>()) {
          expect(row['owner'], _testApiKey.key);
          final order = row['order'] as Map<String, dynamic>;
          expect(order['maker'], depositWallet);
          expect(order['signer'], depositWallet);
          expect(order['signatureType'], 3);
          expect((order['signature'] as String).length, 636);
        }
      },
    );
  });

  group('createMarketOrder', () {
    test(
      'uses explicit price for polygolem-compatible market amounts',
      () async {
        String? lastPath;
        String? orderBody;
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
              orderBody = (req as http.Request).body;
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
            amount: '1.011700',
            price: '0.120000',
          ),
        );

        expect(lastPath, '/order');
        expect(resp.orderId, 'ord-mkt-1');
        final body = jsonDecode(orderBody!) as Map<String, dynamic>;
        final order = body['order'] as Map<String, dynamic>;
        expect(order['makerAmount'], '1010000');
        expect(order['takerAmount'], '8416600');
      },
    );

    test(
      'deposit-wallet helper derives maker, wraps signature, and uses EOA auth',
      () async {
        http.BaseRequest? orderRequest;
        String? orderBody;
        final signer = _CannedSigner();
        final depositWallet = deriveDepositWallet(signer.address);
        final client = _client((req) async {
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
              orderRequest = req;
              orderBody = (req as http.Request).body;
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'success': true,
                  'order_id': 'ord-dw-mkt-1',
                  'status': 'matched',
                }),
                200,
              );
            default:
              return http.Response('not found', 404);
          }
        });

        final resp = await createDepositWalletMarketOrder(
          client: client,
          signer: signer,
          apiKey: _testApiKey,
          params: const CreateDepositWalletMarketOrderParams(
            tokenId: '12345',
            side: Side.buy,
            amount: '1.011700',
            price: '0.120000',
          ),
        );

        expect(resp.orderId, 'ord-dw-mkt-1');
        expect(orderRequest!.headers['POLY_ADDRESS'], signer.address);
        expect(signer.lastTyped!['primaryType'], 'TypedDataSign');
        final body = jsonDecode(orderBody!) as Map<String, dynamic>;
        expect(body['owner'], _testApiKey.key);
        expect(body['orderType'], 'FOK');
        final order = body['order'] as Map<String, dynamic>;
        expect(order['maker'], depositWallet);
        expect(order['signer'], depositWallet);
        expect(order['signatureType'], 3);
        expect(order['makerAmount'], '1010000');
        expect(order['takerAmount'], '8416600');
        expect((order['signature'] as String).length, 636);
      },
    );
  });

  group('market order price discovery', () {
    test('uses best opposing price when price is omitted', () async {
      String? orderBody;
      final client = _client((req) async {
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
          case '/book':
            return http.Response(
              jsonEncode(<String, dynamic>{
                'asset_id': '12345',
                'bids': <Map<String, String>>[],
                'asks': <Map<String, String>>[
                  <String, String>{'price': '0.120000', 'size': '10'},
                ],
              }),
              200,
            );
          case '/order':
            orderBody = (req as http.Request).body;
            return http.Response(
              jsonEncode(<String, dynamic>{
                'success': true,
                'order_id': 'ord-mkt-book-1',
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
          amount: '1.011700',
        ),
      );

      expect(resp.orderId, 'ord-mkt-book-1');
      final body = jsonDecode(orderBody!) as Map<String, dynamic>;
      final order = body['order'] as Map<String, dynamic>;
      expect(order['makerAmount'], '1010000');
      expect(order['takerAmount'], '8416600');
    });
  });
}
