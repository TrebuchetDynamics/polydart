// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/auth/l2.dart';
import 'package:polydart/src/clob/clob_client.dart';
import 'package:polydart/src/clob/clob_writes.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/modes/modes.dart';
import 'package:polydart/src/orders/order_intent.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:polydart/src/types/enums.dart';
import 'package:test/test.dart';

const _apiKey = ApiKey(
  key: 'test-key',
  secret: 'c2VjcmV0', // base64("secret")
  passphrase: 'pass',
);

ClobClient _liveClient(
  Future<http.Response> Function(http.BaseRequest) handler, {
  DateTime Function()? clock,
}) {
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
    clock: clock ?? () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
  );
}

ClobClient _gatedClient({
  PolydartMode mode = PolydartMode.readOnly,
  bool liveFlag = false,
}) {
  return ClobClient(
    transport: HttpTransport(
      config: const TransportConfig(
        baseUrl: ClobClient.defaultBaseUrl,
        retryMax: 0,
      ),
      inner: MockClient((req) async {
        // Should never be called in a gated test.
        return http.Response('{}', 200);
      }),
    ),
    mode: mode,
    liveTradingEnabled: liveFlag,
  );
}

SignedOrder _sampleSignedOrder() => const SignedOrder(
  salt: '12345',
  maker: '0xabc',
  signer: '0xdef',
  taker: '0x000',
  tokenId: '999',
  makerAmount: '1000000',
  takerAmount: '5000000',
  side: Side.buy,
  signatureType: SignatureType.eoa,
  expiration: 0,
  nonce: 0,
  feeRateBps: 0,
  signature: '0xsig',
);

void main() {
  group('mode gating', () {
    test('readOnly client throws SafetyException on createOrder', () async {
      final c = _gatedClient();
      expect(
        () => c.writes.createOrder(
          order: _sampleSignedOrder(),
          owner: 'owner-1',
          apiKey: _apiKey,
        ),
        throwsA(isA<SafetyException>()),
      );
    });

    test('paper client throws SafetyException on cancelOrder', () async {
      final c = _gatedClient(mode: PolydartMode.paper);
      expect(
        () => c.writes.cancelOrder(orderId: 'O-1', apiKey: _apiKey),
        throwsA(isA<SafetyException>()),
      );
    });

    test('live mode without liveTradingEnabled still throws', () async {
      final c = _gatedClient(mode: PolydartMode.live);
      expect(
        () => c.writes.cancelAllOrders(apiKey: _apiKey),
        throwsA(isA<SafetyException>()),
      );
    });
  });

  group('createOrder', () {
    test(
      'POSTs /order with signed payload, L2 headers, and Polygolem response casing',
      () async {
        http.BaseRequest? captured;
        String? capturedBody;
        final c = _liveClient((req) async {
          captured = req;
          if (req is http.Request) capturedBody = req.body;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'success': true,
              'orderID': 'O-9',
              'status': 'matched',
              'makingAmount': '1000000',
              'takingAmount': '5000000',
              'errorMsg': '',
              'transactionsHashes': <String>['0xtx'],
              'tradeIDs': <String>['trade-1'],
            }),
            200,
          );
        });

        final resp = await c.writes.createOrder(
          order: _sampleSignedOrder(),
          owner: 'owner-1',
          apiKey: _apiKey,
          orderType: OrderType.gtc,
        );

        expect(captured!.method, 'POST');
        expect(captured!.url.path, '/order');
        expect(captured!.headers['POLY_API_KEY'], 'test-key');
        expect(captured!.headers['POLY_PASSPHRASE'], 'pass');
        expect(captured!.headers['POLY_TIMESTAMP'], isNotNull);
        expect(captured!.headers['POLY_SIGNATURE'], isNotNull);

        final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
        expect(body['owner'], 'owner-1');
        expect(body['orderType'], 'GTC');
        expect((body['order'] as Map)['tokenId'], '999');

        expect(resp.success, isTrue);
        expect(resp.orderId, 'O-9');
        expect(resp.makingAmount, '1000000');
        expect(resp.takingAmount, '5000000');
        expect(resp.transactionHashes, ['0xtx']);
        expect(resp.tradeIds, ['trade-1']);
      },
    );
  });

  group('createOrders', () {
    test('POSTs /orders with signed order payload array', () async {
      http.BaseRequest? captured;
      String? capturedBody;
      final c = _liveClient((req) async {
        captured = req;
        if (req is http.Request) capturedBody = req.body;
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'success': true,
              'orderID': 'O-1',
              'status': 'live',
            },
            <String, dynamic>{
              'success': true,
              'orderID': 'O-2',
              'status': 'live',
            },
          ]),
          200,
        );
      });

      final response = await c.writes.createOrders(
        requests: <CreateOrderRequest>[
          CreateOrderRequest(
            order: _sampleSignedOrder(),
            owner: 'owner-1',
            orderType: OrderType.gtc,
          ),
          CreateOrderRequest(
            order: _sampleSignedOrder(),
            owner: 'owner-1',
            orderType: OrderType.gtc,
            postOnly: true,
          ),
        ],
        apiKey: _apiKey,
        polyAddress: '0xEoa',
      );

      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/orders');
      expect(captured!.headers['POLY_API_KEY'], 'test-key');
      expect(captured!.headers['POLY_ADDRESS'], '0xEoa');
      final body = jsonDecode(capturedBody!) as List<dynamic>;
      expect(body, hasLength(2));
      expect((body.last as Map<String, dynamic>)['postOnly'], isTrue);
      expect(response.orders.map((o) => o.orderId), ['O-1', 'O-2']);
    });

    test('rejects empty and oversized batches before network', () async {
      var hit = false;
      final c = _liveClient((req) async {
        hit = true;
        return http.Response('[]', 200);
      });

      await expectLater(
        c.writes.createOrders(requests: const [], apiKey: _apiKey),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        c.writes.createOrders(
          requests: <CreateOrderRequest>[
            for (var i = 0; i < 16; i++)
              CreateOrderRequest(
                order: _sampleSignedOrder(),
                owner: 'owner-1',
                orderType: OrderType.gtc,
              ),
          ],
          apiKey: _apiKey,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(hit, isFalse);
    });
  });

  group('cancelOrder', () {
    test('DELETEs /order with {orderID} body and L2 headers', () async {
      http.BaseRequest? captured;
      String? capturedBody;
      final c = _liveClient((req) async {
        captured = req;
        if (req is http.Request) capturedBody = req.body;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'canceled': <String>['O-1'],
            'not_canceled': <String, dynamic>{},
          }),
          200,
        );
      });

      final resp = await c.writes.cancelOrder(
        orderId: 'O-1',
        apiKey: _apiKey,
        polyAddress: '0xEoa',
      );

      expect(captured!.method, 'DELETE');
      expect(captured!.url.path, '/order');
      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body['orderID'], 'O-1');
      expect(captured!.headers['POLY_API_KEY'], 'test-key');
      expect(captured!.headers['POLY_ADDRESS'], '0xEoa');

      expect(resp.canceled, ['O-1']);
      expect(resp.notCanceled, isEmpty);
    });

    test('rejects empty orderId without hitting the network', () async {
      var hit = false;
      final c = ClobClient(
        transport: HttpTransport(
          config: const TransportConfig(
            baseUrl: ClobClient.defaultBaseUrl,
            retryMax: 0,
          ),
          inner: MockClient((req) async {
            hit = true;
            return http.Response('{}', 200);
          }),
        ),
        mode: PolydartMode.live,
        liveTradingEnabled: true,
      );
      expect(
        () => c.writes.cancelOrder(orderId: '   ', apiKey: _apiKey),
        throwsA(isA<ValidationException>()),
      );
      expect(hit, isFalse);
    });
  });

  group('cancelOrders', () {
    test('DELETEs /orders with cleaned {orderIDs} body', () async {
      http.BaseRequest? captured;
      String? capturedBody;
      final c = _liveClient((req) async {
        captured = req;
        if (req is http.Request) capturedBody = req.body;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'canceled': <String>['O-1', 'O-2'],
            'not_canceled': <String, dynamic>{'O-3': 'already filled'},
          }),
          200,
        );
      });

      final resp = await c.writes.cancelOrders(
        orderIds: [' O-1 ', '', 'O-2', ' O-3'],
        apiKey: _apiKey,
        polyAddress: '0xEoa',
      );

      expect(captured!.method, 'DELETE');
      expect(captured!.url.path, '/orders');
      expect(captured!.headers['POLY_ADDRESS'], '0xEoa');
      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body['orderIDs'], ['O-1', 'O-2', 'O-3']);
      expect(resp.canceled, ['O-1', 'O-2']);
      expect(resp.notCanceled, {'O-3': 'already filled'});
    });

    test('rejects empty or blank-only list before network', () async {
      var hit = false;
      final c = _liveClient((_) async {
        hit = true;
        return http.Response('{}', 200);
      });
      expect(
        () => c.writes.cancelOrders(orderIds: const [], apiKey: _apiKey),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => c.writes.cancelOrders(orderIds: const ['   '], apiKey: _apiKey),
        throwsA(isA<ValidationException>()),
      );
      expect(hit, isFalse);
    });
  });

  group('cancelAllOrders', () {
    test('DELETEs /cancel-all with no body and L2 headers', () async {
      http.BaseRequest? captured;
      final c = _liveClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'canceled': <String>['O-1'],
          }),
          200,
        );
      });

      final resp = await c.writes.cancelAllOrders(
        apiKey: _apiKey,
        polyAddress: '0xEoa',
      );

      expect(captured!.method, 'DELETE');
      expect(captured!.url.path, '/cancel-all');
      expect(captured!.headers['POLY_SIGNATURE'], isNotNull);
      expect(captured!.headers['POLY_ADDRESS'], '0xEoa');
      expect(resp.canceled, ['O-1']);
    });
  });

  group('cancelMarket', () {
    test('DELETEs /cancel-market-orders with market+asset_id body', () async {
      http.BaseRequest? captured;
      String? capturedBody;
      final c = _liveClient((req) async {
        captured = req;
        if (req is http.Request) capturedBody = req.body;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'canceled': <String>['O-9'],
            'not_canceled': <String, dynamic>{},
          }),
          200,
        );
      });

      final resp = await c.writes.cancelMarket(
        apiKey: _apiKey,
        market: '0xMarket',
        assetId: 'token-1',
        polyAddress: '0xEoa',
      );

      expect(captured!.method, 'DELETE');
      expect(captured!.url.path, '/cancel-market-orders');
      expect(captured!.headers['POLY_SIGNATURE'], isNotNull);
      expect(captured!.headers['POLY_ADDRESS'], '0xEoa');
      final decoded = jsonDecode(capturedBody ?? '{}') as Map<String, dynamic>;
      expect(decoded['market'], '0xMarket');
      expect(decoded['asset_id'], 'token-1');
      expect(resp.canceled, ['O-9']);
    });

    test('throws ValidationException when both filters are empty', () async {
      final c = _liveClient((_) async => http.Response('{}', 200));
      expect(
        () => c.writes.cancelMarket(apiKey: _apiKey),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('heartbeat', () {
    test('POSTs /v1/heartbeats with nullable heartbeat_id', () async {
      http.BaseRequest? captured;
      String? capturedBody;
      final c = _liveClient((req) async {
        captured = req;
        if (req is http.Request) capturedBody = req.body;
        return http.Response(
          jsonEncode(<String, dynamic>{'status': 'ok'}),
          200,
        );
      });

      await c.writes.heartbeat(apiKey: _apiKey);

      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/v1/heartbeats');
      expect(jsonDecode(capturedBody!), <String, dynamic>{
        'heartbeat_id': null,
      });
    });

    test('includes heartbeat id when supplied', () async {
      String? capturedBody;
      final c = _liveClient((req) async {
        if (req is http.Request) capturedBody = req.body;
        return http.Response(
          jsonEncode(<String, dynamic>{'status': 'ok'}),
          200,
        );
      });

      await c.writes.heartbeat(apiKey: _apiKey, heartbeatId: 'hb-123');

      expect(jsonDecode(capturedBody!), <String, dynamic>{
        'heartbeat_id': 'hb-123',
      });
    });
  });

  group('CancelResponse decoding', () {
    test('accepts notCanceled camelCase variant', () {
      final r = CancelResponse.fromJson(<String, dynamic>{
        'canceled': <String>['O-1'],
        'notCanceled': <String, dynamic>{'O-2': 'reason'},
      });
      expect(r.canceled, ['O-1']);
      expect(r.notCanceled['O-2'], 'reason');
    });

    test('handles missing fields safely', () {
      final r = CancelResponse.fromJson(const <String, dynamic>{});
      expect(r.canceled, isEmpty);
      expect(r.notCanceled, isEmpty);
    });
  });
}
