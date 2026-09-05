import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

// Contract sources: Polymarket/clob-client-v2 src/types/ordersV{1,2}.ts
// and src/order-utils/utils.ts, inspected 2026-09-04. Mock HTTP only.
const _key = ApiKey(
  key: 'test-key',
  secret: 'c2VjcmV0',
  passphrase: 'test-pass',
);

SignedOrder _order({String salt = '9007199254740991', bool v2 = true}) =>
    SignedOrder(
      salt: salt,
      maker: '0x1111111111111111111111111111111111111111',
      signer: '0x1111111111111111111111111111111111111111',
      taker: '0x0000000000000000000000000000000000000000',
      tokenId: '1234567890123456789012345678901234567890',
      makerAmount: '6000000',
      takerAmount: '10000000',
      side: Side.buy,
      signatureType: SignatureType.eoa,
      expiration: 0,
      nonce: 0,
      feeRateBps: 0,
      signature: '0xmock-signature',
      timestamp: v2 ? 1700000000000 : null,
      metadata: v2 ? bytes32Zero : null,
      builder: v2 ? bytes32Zero : null,
    );

void main() {
  for (final amount in ['0.1', '0.99', '0.999999']) {
    test('market BUY below one dollar fails before signing: $amount', () async {
      final signer = _MinimumSigner();
      final client = _minimumClient();
      addTearDown(client.close);
      await expectLater(
        createDepositWalletMarketOrder(
          client: client,
          signer: signer,
          apiKey: _key,
          params: CreateDepositWalletMarketOrderParams(
            tokenId: '10001',
            side: Side.buy,
            amount: amount,
            price: '0.1',
          ),
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            r'Minimum marketable buy amount is $1.',
          ),
        ),
      );
      expect(signer.calls, 0);
    });
  }

  for (final marketable in [false, true]) {
    test(
      'sub-dollar limit BUY is rejected only when marketable: $marketable',
      () async {
        final signer = _MinimumSigner();
        final client = _minimumClient();
        addTearDown(client.close);
        final request = createDepositWalletLimitOrder(
          client: client,
          signer: signer,
          apiKey: _key,
          params: CreateDepositWalletLimitOrderParams(
            tokenId: '10001',
            side: Side.buy,
            size: '1',
            price: marketable ? '0.1' : '0.05',
          ),
        );
        if (marketable) {
          await expectLater(request, throwsA(isA<ValidationException>()));
          expect(signer.calls, 0);
        } else {
          expect((await request).orderId, 'mock');
          expect(signer.calls, 1);
        }
      },
    );
  }

  for (final side in [Side.buy, Side.sell]) {
    test(
      'minimum does not reject one-dollar BUY or sub-dollar SELL: $side',
      () async {
        final signer = _MinimumSigner();
        final client = _minimumClient();
        addTearDown(client.close);
        final response = await createDepositWalletMarketOrder(
          client: client,
          signer: signer,
          apiKey: _key,
          params: CreateDepositWalletMarketOrderParams(
            tokenId: '10001',
            side: side,
            amount: side == Side.buy ? '1' : '0.1',
            price: '0.1',
          ),
        );
        expect(response.orderId, 'mock');
        expect(signer.calls, 1);
      },
    );
  }

  for (final update in [false, true]) {
    test(
      'balance read authenticates the endpoint without query parameters $update',
      () async {
        final path = update
            ? '/balance-allowance/update'
            : '/balance-allowance';
        final client = ClobClient(
          transport: HttpTransport(
            config: const TransportConfig(
              baseUrl: 'https://mock.test/proxy/clob',
            ),
            inner: MockClient((request) async {
              expect(request.url.queryParameters['signature_type'], '3');
              expect(
                request.headers['POLY_SIGNATURE'],
                signHmac(
                  secret: _key.secret,
                  timestamp: int.parse(request.headers['POLY_TIMESTAMP']!),
                  method: 'GET',
                  path: path,
                ),
              );
              return http.Response('{"balance":"0","allowances":{}}', 200);
            }),
          ),
        );
        addTearDown(client.close);
        const params = BalanceAllowanceParams(assetType: 'COLLATERAL');
        if (update) {
          await client.updateBalanceAllowance(apiKey: _key, params: params);
        } else {
          await client.balanceAllowance(apiKey: _key, params: params);
        }
      },
    );
  }

  for (final trades in [false, true]) {
    test(
      'authenticated ${trades ? "trades" : "orders"} consumes all cursor pages',
      () async {
        var reads = 0;
        final path = trades ? '/data/trades' : '/data/orders';
        final client = ClobClient(
          transport: HttpTransport(
            config: const TransportConfig(baseUrl: 'https://mock.test'),
            inner: MockClient((request) async {
              reads++;
              expect(request.url.path, path);
              expect(
                request.url.queryParameters['next_cursor'],
                reads == 1 ? null : 'page2',
              );
              expect(
                request.headers['POLY_SIGNATURE'],
                signHmac(
                  secret: _key.secret,
                  timestamp: int.parse(request.headers['POLY_TIMESTAMP']!),
                  method: 'GET',
                  path: path,
                ),
              );
              return http.Response(
                jsonEncode({
                  'data': [
                    {'id': 'record-$reads'},
                  ],
                  'next_cursor': reads == 1 ? 'page2' : 'LTE=',
                }),
                200,
              );
            }),
          ),
        );
        addTearDown(client.close);
        final List<Object> records = trades
            ? await client.listTrades(apiKey: _key)
            : await client.listOrders(apiKey: _key);
        expect(records, hasLength(2));
        expect(reads, 2);
      },
    );
  }

  test(
    'repeated order cursor fails rather than returning incomplete data or looping',
    () async {
      var reads = 0;
      final client = ClobClient(
        transport: HttpTransport(
          config: const TransportConfig(baseUrl: 'https://mock.test'),
          inner: MockClient((request) async {
            reads++;
            return http.Response('{"data":[],"next_cursor":"same"}', 200);
          }),
        ),
      );
      addTearDown(client.close);
      await expectLater(
        client.listOrders(apiKey: _key),
        throwsA(isA<FormatException>()),
      );
      expect(reads, 2);
    },
  );

  test('generated salts survive JSON number round trips on VM and web', () {
    final max = BigInt.parse('9007199254740991');
    for (var i = 0; i < 256; i++) {
      final salt = BigInt.parse(generateOrderSalt());
      expect(salt >= BigInt.zero && salt <= max, isTrue);
      final wire = jsonDecode(jsonEncode({'salt': salt.toInt()})) as Map;
      expect(BigInt.from(wire['salt'] as num), salt);
    }
  });

  for (final v2 in [false, true]) {
    test('V${v2 ? 2 : 1} serializes salt as an exact number', () {
      final order = _order(v2: v2);
      final wire = jsonDecode(jsonEncode(order.toJson())) as Map;
      expect(wire['salt'], isA<int>());
      expect(wire['salt'].toString(), order.salt);
      expect(wire['tokenId'], order.tokenId);
      expect(wire['makerAmount'], '6000000');
      expect(wire['expiration'], '0');
      expect(wire['side'], 'BUY');
      expect(wire.containsKey('nonce'), !v2);
      expect(wire.containsKey('feeRateBps'), !v2);
      expect(wire.containsKey('timestamp'), v2);
    });
  }

  for (final salt in [
    '-1',
    '9007199254740992',
    '18446744073709551615',
    '',
    '1.5',
    'NaN',
    '1e3',
    '0x10',
  ]) {
    test('rejects unsafe salt $salt instead of rounding a signed value', () {
      expect(
        () => _order(salt: salt).toJson(),
        throwsA(
          isA<ValidationException>().having((e) => e.field, 'field', 'salt'),
        ),
      );
    });
  }

  for (final tick in [0.1, 0.01, 0.001, 0.0001]) {
    test('official minimum_tick_size $tick populates the builder tick', () {
      expect(TickSize.fromJson({'minimum_tick_size': tick}).tickSize, '$tick');
      expect(TickSize.fromJson({'minimumTickSize': tick}).tickSize, '$tick');
    });
  }
  test('explicit invalid tick is not replaced by a valid minimum', () {
    expect(
      TickSize.fromJson(const {
        'tick_size': 0,
        'minimum_tick_size': 0.01,
      }).tickSize,
      '0',
    );
  });

  for (final batch in [false, true]) {
    test(
      'V2 ${batch ? "batch" : "single"} body is authenticated after serialization',
      () async {
        final path = batch ? '/orders' : '/order';
        final client = ClobClient(
          mode: PolydartMode.live,
          liveTradingEnabled: true,
          transport: HttpTransport(
            config: const TransportConfig(
              baseUrl: 'https://mock.test/proxy/clob',
            ),
            inner: MockClient((request) async {
              expect(request.url.path, '/proxy/clob$path');
              final body = jsonDecode(request.body);
              final entry = batch ? (body as List).single : body;
              expect(entry['order']['salt'], 9007199254740991);
              expect(entry['order'].containsKey('nonce'), isFalse);
              expect(entry['order'].containsKey('feeRateBps'), isFalse);
              expect(entry['owner'], _key.key);
              expect(
                request.headers['POLY_SIGNATURE'],
                signHmac(
                  secret: _key.secret,
                  timestamp: int.parse(request.headers['POLY_TIMESTAMP']!),
                  method: 'POST',
                  path: path,
                  body: request.body,
                ),
              );
              const response = {
                'success': true,
                'orderID': 'mock',
                'status': 'live',
              };
              return http.Response(
                jsonEncode(batch ? [response] : response),
                200,
              );
            }),
          ),
        );
        addTearDown(client.close);
        if (batch) {
          await client.writes.createOrders(
            requests: [
              CreateOrderRequest(
                order: _order(),
                owner: _key.key,
                orderType: OrderType.gtc,
              ),
            ],
            apiKey: _key,
          );
        } else {
          await client.writes.createOrder(
            order: _order(),
            owner: _key.key,
            apiKey: _key,
          );
        }
      },
    );
  }
}

ClobClient _minimumClient() => ClobClient(
  mode: PolydartMode.live,
  liveTradingEnabled: true,
  transport: HttpTransport(
    config: const TransportConfig(baseUrl: 'https://mock.test'),
    inner: MockClient((request) async {
      if (request.url.path == '/tick-size') {
        return http.Response('{"minimum_tick_size":0.01}', 200);
      }
      if (request.url.path == '/book') {
        return http.Response(
          '{"asks":[{"price":"0.1","size":"100"}],"bids":[]}',
          200,
        );
      }
      expect(request.url.path, '/order');
      return http.Response(
        '{"success":true,"orderID":"mock","status":"live"}',
        200,
      );
    }),
  ),
);

class _MinimumSigner implements WalletSigner {
  var calls = 0;
  @override
  String get address => '0x1111111111111111111111111111111111111111';
  @override
  int get chainId => 137;
  @override
  Future<Uint8List> personalSign(Uint8List message) =>
      throw UnimplementedError();
  @override
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData) async {
    calls++;
    return Uint8List(65)..[64] = 27;
  }
}
