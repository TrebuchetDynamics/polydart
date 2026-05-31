// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:polydart/src/auth/create2.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/orders/deposit_wallet_order_signing.dart';
import 'package:polydart/src/orders/market_order_pricing.dart';
import 'package:polydart/src/orders/order_builder.dart';
import 'package:polydart/src/orders/order_placement.dart';
import 'package:polydart/src/orders/order_signing.dart';
import 'package:polydart/src/types/clob.dart';
import 'package:polydart/src/types/enums.dart';
import 'package:test/test.dart';

import '../support/order_test_support.dart';

void main() {
  group('signOrderV2', () {
    test('produces a SignedOrder for an EOA limit-buy intent', () async {
      final intent = limitBuyIntent();

      final signer = cannedOrderSigner();
      final signed = await signOrderV2(intent: intent, signer: signer);

      expect(signed.maker, signer.address);
      expect(signed.signer, signer.address);
      expect(signed.tokenId, '12345');
      expect(signed.side, Side.buy);
      expect(signed.signature.startsWith('0x'), isTrue);
      // Signed timestamp should be a recent millis epoch.
      expect(signed.timestamp, isNotNull);
      // typed-data presented to the wallet should have primaryType=Order
      expect(signer.lastTypedData!['primaryType'], 'Order');
    });

    test('rejects non-Polygon signer before wallet signing', () async {
      final intent = limitBuyIntent();

      final signer = cannedOrderSigner(chainId: 1);

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

      final signer = cannedOrderSigner();
      final signed = await signOrderV2(intent: intent, signer: signer);

      expect(signed.maker, '0xDeposit');
      expect(signed.signer, signer.address);
      expect(signed.signatureType, SignatureType.poly1271);
    });

    test(
      'wraps deposit-wallet orders with ERC-7739 approval envelope',
      () async {
        final signer = cannedOrderSigner();
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
        expect(signer.lastTypedData!['primaryType'], 'TypedDataSign');
        final message =
            signer.lastTypedData!['message'] as Map<String, dynamic>;
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
      final client = orderTestClient((req) async {
        lastPath = req.url.path;
        switch (req.url.path) {
          case '/tick-size':
            return tickSizeResponse();
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
        signer: cannedOrderSigner(),
        apiKey: testOrderApiKey,
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
        final signer = cannedOrderSigner();
        final depositWallet = deriveDepositWallet(signer.address);
        final client = orderTestClient((req) async {
          switch (req.url.path) {
            case '/tick-size':
              return tickSizeResponse();
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
          apiKey: testOrderApiKey,
          params: const CreateDepositWalletLimitOrderParams(
            tokenId: '12345',
            side: Side.buy,
            price: '0.50',
            size: '10',
          ),
        );

        expect(resp.orderId, 'ord-dw-1');
        expect(orderRequest!.headers['POLY_ADDRESS'], signer.address);
        expect(signer.lastTypedData!['primaryType'], 'TypedDataSign');
        final body = jsonDecode(orderBody!) as Map<String, dynamic>;
        expect(body['owner'], testOrderApiKey.key);
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
        final signer = cannedOrderSigner();
        final depositWallet = deriveDepositWallet(signer.address);
        final client = orderTestClient((req) async {
          switch (req.url.path) {
            case '/tick-size':
              return tickSizeResponse();
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
          apiKey: testOrderApiKey,
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
          expect(row['owner'], testOrderApiKey.key);
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
        final client = orderTestClient((req) async {
          lastPath = req.url.path;
          switch (req.url.path) {
            case '/tick-size':
              return tickSizeResponse();
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
          signer: cannedOrderSigner(),
          apiKey: testOrderApiKey,
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

    test('supports explicit-price sell market orders', () async {
      String? orderBody;
      final client = orderTestClient((req) async {
        switch (req.url.path) {
          case '/tick-size':
            return tickSizeResponse();
          case '/order':
            orderBody = (req as http.Request).body;
            return http.Response(
              jsonEncode(<String, dynamic>{
                'success': true,
                'order_id': 'ord-mkt-sell-1',
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
        signer: cannedOrderSigner(),
        apiKey: testOrderApiKey,
        params: const CreateMarketOrderParams(
          tokenId: '12345',
          side: Side.sell,
          amount: '3.000000',
          price: '0.500000',
        ),
      );

      expect(resp.orderId, 'ord-mkt-sell-1');
      final body = jsonDecode(orderBody!) as Map<String, dynamic>;
      final order = body['order'] as Map<String, dynamic>;
      expect(order['side'], 'SELL');
      expect(order['makerAmount'], '3000000');
      expect(order['takerAmount'], '1500000');
    });

    test(
      'deposit-wallet helper derives maker, wraps signature, and uses EOA auth',
      () async {
        http.BaseRequest? orderRequest;
        String? orderBody;
        final signer = cannedOrderSigner();
        final depositWallet = deriveDepositWallet(signer.address);
        final client = orderTestClient((req) async {
          switch (req.url.path) {
            case '/tick-size':
              return tickSizeResponse();
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
          apiKey: testOrderApiKey,
          params: const CreateDepositWalletMarketOrderParams(
            tokenId: '12345',
            side: Side.buy,
            amount: '1.011700',
            price: '0.120000',
          ),
        );

        expect(resp.orderId, 'ord-dw-mkt-1');
        expect(orderRequest!.headers['POLY_ADDRESS'], signer.address);
        expect(signer.lastTypedData!['primaryType'], 'TypedDataSign');
        final body = jsonDecode(orderBody!) as Map<String, dynamic>;
        expect(body['owner'], testOrderApiKey.key);
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

  group('market order price discovery plan', () {
    test('selects the level that can fill a buy amount', () {
      final plan = selectMarketOrderPrice(
        levels: const <OrderBookLevel>[
          OrderBookLevel(price: '0.10', size: '5'),
          OrderBookLevel(price: '0.20', size: '10'),
        ],
        side: Side.buy,
        amount: 2.0,
        orderType: OrderType.fok,
      );

      expect(plan.price, '0.20');
      expect(plan.levelsConsumed, 2);
      expect(plan.fillsCompletely, isTrue);
    });

    test('non-FOK partial fills keep the worst consumed visible price', () {
      final plan = selectMarketOrderPrice(
        levels: const <OrderBookLevel>[
          OrderBookLevel(price: '0.10', size: '5'),
          OrderBookLevel(price: '0.20', size: '10'),
        ],
        side: Side.buy,
        amount: 10.0,
        orderType: OrderType.gtc,
      );

      expect(plan.price, '0.20');
      expect(plan.filledAmount, 2.5);
      expect(plan.levelsConsumed, 2);
      expect(plan.fillsCompletely, isFalse);
    });

    test('rejects malformed book levels as validation failures', () {
      expect(
        () => selectMarketOrderPrice(
          levels: const <OrderBookLevel>[
            OrderBookLevel(price: 'not-a-price', size: '5'),
          ],
          side: Side.buy,
          amount: 1.0,
          orderType: OrderType.fok,
        ),
        throwsA(
          isA<ValidationException>()
              .having((error) => error.field, 'field', 'book price')
              .having(
                (error) => error.message,
                'message',
                'book price must be a finite positive decimal',
              ),
        ),
      );
    });
  });

  group('market order price discovery', () {
    test(
      'wraps malformed omitted-price amount as ValidationException',
      () async {
        final client = orderTestClient((req) async {
          switch (req.url.path) {
            case '/tick-size':
              return tickSizeResponse();
            default:
              return http.Response('unexpected ${req.url.path}', 500);
          }
        });

        await expectLater(
          createMarketOrder(
            client: client,
            signer: cannedOrderSigner(),
            apiKey: testOrderApiKey,
            params: const CreateMarketOrderParams(
              tokenId: '12345',
              side: Side.buy,
              amount: 'not-a-number',
            ),
          ),
          throwsA(
            isA<ValidationException>()
                .having((error) => error.field, 'field', 'amount')
                .having(
                  (error) => error.message,
                  'message',
                  'amount must be a decimal',
                ),
          ),
        );
      },
    );

    test('wraps malformed book prices as ValidationException', () async {
      final client = orderTestClient((req) async {
        switch (req.url.path) {
          case '/tick-size':
            return tickSizeResponse();
          case '/book':
            return http.Response(
              jsonEncode(<String, dynamic>{
                'asset_id': '12345',
                'bids': <Map<String, String>>[],
                'asks': <Map<String, String>>[
                  <String, String>{'price': 'not-a-price', 'size': '10'},
                ],
              }),
              200,
            );
          default:
            return http.Response('unexpected ${req.url.path}', 500);
        }
      });

      await expectLater(
        createMarketOrder(
          client: client,
          signer: cannedOrderSigner(),
          apiKey: testOrderApiKey,
          params: const CreateMarketOrderParams(
            tokenId: '12345',
            side: Side.buy,
            amount: '1.011700',
          ),
        ),
        throwsA(
          isA<ValidationException>()
              .having((error) => error.field, 'field', 'book price')
              .having(
                (error) => error.message,
                'message',
                'book price must be a finite positive decimal',
              ),
        ),
      );
    });

    test('uses best opposing price when price is omitted', () async {
      String? orderBody;
      final client = orderTestClient((req) async {
        switch (req.url.path) {
          case '/tick-size':
            return tickSizeResponse();
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
        signer: cannedOrderSigner(),
        apiKey: testOrderApiKey,
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

    test('uses bids for sell price discovery', () async {
      String? orderBody;
      final client = orderTestClient((req) async {
        switch (req.url.path) {
          case '/tick-size':
            return tickSizeResponse();
          case '/book':
            return http.Response(
              jsonEncode(<String, dynamic>{
                'asset_id': '12345',
                'bids': <Map<String, String>>[
                  <String, String>{'price': '0.600000', 'size': '5'},
                  <String, String>{'price': '0.550000', 'size': '3'},
                ],
                'asks': <Map<String, String>>[],
              }),
              200,
            );
          case '/order':
            orderBody = (req as http.Request).body;
            return http.Response(
              jsonEncode(<String, dynamic>{
                'success': true,
                'order_id': 'ord-mkt-sell-book-1',
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
        signer: cannedOrderSigner(),
        apiKey: testOrderApiKey,
        params: const CreateMarketOrderParams(
          tokenId: '12345',
          side: Side.sell,
          amount: '7.000000',
        ),
      );

      expect(resp.orderId, 'ord-mkt-sell-book-1');
      final body = jsonDecode(orderBody!) as Map<String, dynamic>;
      final order = body['order'] as Map<String, dynamic>;
      expect(order['makerAmount'], '7000000');
      expect(order['takerAmount'], '3850000');
    });
  });
}
