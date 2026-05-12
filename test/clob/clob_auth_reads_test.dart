// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/auth/l2.dart';
import 'package:polydart/src/clob/clob_auth_types.dart';
import 'package:polydart/src/clob/clob_client.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:test/test.dart';

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
  );
}

void main() {
  group('listOrders', () {
    test(
      'GETs /data/orders with POLY_API_KEY headers and parses records',
      () async {
        Map<String, String>? capturedHeaders;
        String? capturedPath;

        final client = _client((req) async {
          capturedPath = req.url.path;
          capturedHeaders = req.headers;
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              {
                'id': 'ord-1',
                'status': 'LIVE',
                'owner': '0xowner',
                'market': '0xmarket',
                'asset_id': 'token-1',
                'side': 'BUY',
                'original_size': '10',
                'size_matched': '0',
                'price': '0.50',
                'outcome': 'YES',
                'type': 'GTC',
                'signature_type': 0,
                'created_at': '2026-05-07T00:00:00Z',
                'expiration': '0',
                'maker_address': '0xmaker',
                'associate_trades': <String>['t1', 't2'],
              },
            ]),
            200,
          );
        });

        final orders = await client.listOrders(apiKey: _testApiKey);
        expect(capturedPath, '/data/orders');
        expect(capturedHeaders!['POLY_API_KEY'], _testApiKey.key);
        expect(capturedHeaders!['POLY_PASSPHRASE'], _testApiKey.passphrase);
        expect(capturedHeaders!['POLY_SIGNATURE'], isNotNull);
        expect(orders, hasLength(1));
        expect(orders.first.id, 'ord-1');
        expect(orders.first.associateTrades, hasLength(2));
      },
    );
  });

  group('listTrades', () {
    test('GETs /data/trades with HMAC headers', () async {
      String? capturedPath;
      final client = _client((req) async {
        capturedPath = req.url.path;
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            {
              'id': 't-1',
              'status': 'CONFIRMED',
              'market': '0xmarket',
              'asset_id': 'token-1',
              'side': 'BUY',
              'price': '0.50',
              'size': '5',
              'fee_rate_bps': '0',
              'outcome': 'YES',
              'owner': '0xowner',
              'builder': '0xbuilder',
              'matched_amount': '5',
              'transaction_hash': '0xhash',
              'created_at': '2026-05-07T00:00:00Z',
              'last_updated': '2026-05-07T00:01:00Z',
            },
          ]),
          200,
        );
      });

      final trades = await client.listTrades(apiKey: _testApiKey);
      expect(capturedPath, '/data/trades');
      expect(trades, hasLength(1));
      expect(trades.first.id, 't-1');
      expect(trades.first.builder, '0xbuilder');
    });
  });

  group('order (single by id)', () {
    test('GETs /data/order/:id and parses record', () async {
      String? capturedPath;
      final client = _client((req) async {
        capturedPath = req.url.path;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'id': 'ord-42',
            'status': 'LIVE',
            'owner': '0xowner',
            'market': '0xmarket',
            'asset_id': 'token-1',
            'side': 'BUY',
            'original_size': '10',
            'size_matched': '5',
            'price': '0.49',
            'outcome': 'YES',
            'type': 'GTC',
            'signature_type': 3,
            'created_at': '2026-05-07T00:00:00Z',
            'expiration': '0',
            'maker_address': '0xmaker',
          }),
          200,
        );
      });

      final order = await client.order(orderId: 'ord-42', apiKey: _testApiKey);
      expect(capturedPath, '/data/order/ord-42');
      expect(order.id, 'ord-42');
      expect(order.signatureType, 3);
      expect(order.sizeMatched, '5');
    });
  });

  group('balanceAllowance', () {
    test('GETs /balance-allowance with query + HMAC', () async {
      Uri? capturedUrl;
      final client = _client((req) async {
        capturedUrl = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'balance': '1000000',
            'allowances': <String, String>{'0xCtfExchangeV2': '999999999'},
          }),
          200,
        );
      });

      final resp = await client.balanceAllowance(
        apiKey: _testApiKey,
        params: const BalanceAllowanceParams(
          assetType: 'COLLATERAL',
          signatureType: 3,
        ),
      );
      expect(capturedUrl!.path, '/balance-allowance');
      expect(capturedUrl!.queryParameters['asset_type'], 'COLLATERAL');
      expect(capturedUrl!.queryParameters['signature_type'], '3');
      expect(resp.balance, '1000000');
      expect(resp.allowances['0xCtfExchangeV2'], '999999999');
    });
  });

  group('updateBalanceAllowance', () {
    test('GETs /balance-allowance/update with query + HMAC', () async {
      String? capturedPath;
      final client = _client((req) async {
        capturedPath = req.url.path;
        return http.Response(
          jsonEncode(<String, dynamic>{'balance': '2000000'}),
          200,
        );
      });

      final resp = await client.updateBalanceAllowance(
        apiKey: _testApiKey,
        params: const BalanceAllowanceParams(
          assetType: 'CONDITIONAL',
          tokenId: 'token-9',
          signatureType: 3,
        ),
      );
      expect(capturedPath, '/balance-allowance/update');
      expect(resp.balance, '2000000');
    });
  });
}
