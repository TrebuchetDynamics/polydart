// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/auth/l2.dart';
import 'package:polydart/src/auth/wallet_signer.dart';
import 'package:polydart/src/clob/clob_client.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:test/test.dart';

class _CannedSigner implements WalletSigner {
  _CannedSigner();
  @override
  String get address => '0x0000000000000000000000000000000000001234';
  @override
  int get chainId => 137;

  Map<String, dynamic>? lastTyped;
  var signTypedDataCalls = 0;

  @override
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData) async {
    signTypedDataCalls++;
    lastTyped = typedData;
    return Uint8List.fromList(List<int>.filled(65, 0xab));
  }

  @override
  Future<Uint8List> personalSign(Uint8List message) async =>
      Uint8List.fromList(List<int>.filled(65, 0xcd));
}

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
  group('createApiKey', () {
    test('POSTs /auth/api-key with L1 headers and parses creds', () async {
      String? capturedPath;
      String? capturedMethod;
      Map<String, String>? capturedHeaders;

      final client = _client((req) async {
        capturedPath = req.url.path;
        capturedMethod = req.method;
        capturedHeaders = req.headers;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'apiKey': '64f6a5fb-3ec0-569b-5329-3c8483853f19',
            'secret': 'BASE64SECRETXX',
            'passphrase': 'pass-phrase-1',
          }),
          200,
        );
      });

      final signer = _CannedSigner();
      final key = await client.createApiKey(
        signer: signer,
        nowSeconds: 1700000000,
      );

      expect(capturedMethod, 'POST');
      expect(capturedPath, '/auth/api-key');
      expect(capturedHeaders!['POLY_ADDRESS'], signer.address);
      expect(capturedHeaders!['POLY_TIMESTAMP'], '1700000000');
      expect(capturedHeaders!['POLY_NONCE'], '0');
      expect(capturedHeaders!['POLY_SIGNATURE']!.startsWith('0x'), isTrue);
      expect(signer.lastTyped!['primaryType'], 'ClobAuth');

      expect(key.key, '64f6a5fb-3ec0-569b-5329-3c8483853f19');
      expect(key.secret, 'BASE64SECRETXX');
      expect(key.passphrase, 'pass-phrase-1');
    });

    test('accepts api_key / pass_phrase snake_case variants', () async {
      final client = _client((req) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'api_key': 'aaaa1111-2222-3333-4444-555566667777',
            'secret': 's',
            'pass_phrase': 'p',
          }),
          200,
        );
      });
      final key = await client.createApiKey(
        signer: _CannedSigner(),
        nowSeconds: 1,
      );
      expect(key.key, 'aaaa1111-2222-3333-4444-555566667777');
      expect(key.passphrase, 'p');
    });
  });

  group('deriveApiKey', () {
    test('GETs /auth/derive-api-key with L1 headers', () async {
      String? capturedMethod;
      String? capturedPath;
      final client = _client((req) async {
        capturedMethod = req.method;
        capturedPath = req.url.path;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'apiKey': 'cccc2222-3333-4444-5555-666677778888',
            'secret': 's2',
            'passphrase': 'p2',
          }),
          200,
        );
      });
      final key = await client.deriveApiKey(
        signer: _CannedSigner(),
        nowSeconds: 1700000001,
      );
      expect(capturedMethod, 'GET');
      expect(capturedPath, '/auth/derive-api-key');
      expect(key.key, 'cccc2222-3333-4444-5555-666677778888');
    });
  });

  group('createOrDeriveApiKey', () {
    test('falls back to derive when POST fails', () async {
      var calls = 0;
      final client = _client((req) async {
        calls++;
        if (req.method == 'POST') {
          return http.Response('conflict', 409);
        }
        expect(req.url.path, '/auth/derive-api-key');
        return http.Response(
          jsonEncode(<String, dynamic>{
            'apiKey': 'dddd3333-4444-5555-6666-777788889999',
            'secret': 's3',
            'passphrase': 'p3',
          }),
          200,
        );
      });
      final signer = _CannedSigner();
      final key = await client.createOrDeriveApiKey(
        signer: signer,
        nowSeconds: 1700000002,
      );
      expect(calls, 2);
      expect(signer.signTypedDataCalls, 1);
      expect(key.key, 'dddd3333-4444-5555-6666-777788889999');
    });

    test('returns POST result on success without falling through', () async {
      var calls = 0;
      final client = _client((req) async {
        calls++;
        expect(req.method, 'POST');
        return http.Response(
          jsonEncode(<String, dynamic>{
            'apiKey': 'eeee4444-5555-6666-7777-88889999aaaa',
            'secret': 's4',
            'passphrase': 'p4',
          }),
          200,
        );
      });
      final key = await client.createOrDeriveApiKey(
        signer: _CannedSigner(),
        nowSeconds: 1700000003,
      );
      expect(calls, 1);
      expect(key.key, 'eeee4444-5555-6666-7777-88889999aaaa');
    });
  });

  group('createBuilderFeeKey', () {
    const apiKey = ApiKey(
      key: 'l2-key-uuid',
      secret: 'BASE64SECRETXX',
      passphrase: 'l2-pass',
    );

    test(
      'POSTs /auth/builder-api-key with L2 headers and parses {key,...}',
      () async {
        String? capturedPath;
        String? capturedMethod;
        Map<String, String>? capturedHeaders;

        final client = _client((req) async {
          capturedPath = req.url.path;
          capturedMethod = req.method;
          capturedHeaders = req.headers;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'key': 'fee-key-uuid',
              'secret': 'BASE64SECRETYY',
              'passphrase': 'fee-pass',
            }),
            200,
          );
        });

        final feeKey = await client.createBuilderFeeKey(apiKey: apiKey);

        expect(capturedMethod, 'POST');
        expect(capturedPath, '/auth/builder-api-key');
        expect(capturedHeaders!['POLY_API_KEY'], 'l2-key-uuid');
        expect(capturedHeaders!['POLY_PASSPHRASE'], 'l2-pass');
        expect(capturedHeaders!['POLY_TIMESTAMP'], isNotNull);
        expect(capturedHeaders!['POLY_SIGNATURE'], isNotNull);

        expect(feeKey.key, 'fee-key-uuid');
        expect(feeKey.secret, 'BASE64SECRETYY');
        expect(feeKey.passphrase, 'fee-pass');
      },
    );
  });

  group('listBuilderFeeKeys', () {
    const apiKey = ApiKey(
      key: 'l2-key-uuid',
      secret: 'BASE64SECRETXX',
      passphrase: 'l2-pass',
    );

    test('GETs /auth/builder-api-keys and decodes records', () async {
      String? capturedPath;
      String? capturedMethod;
      final client = _client((req) async {
        capturedPath = req.url.path;
        capturedMethod = req.method;
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            {
              'key': 'fee-1',
              'created_at': '2026-05-08T00:00:00Z',
              'updatedAt': '2026-05-08T01:00:00Z',
            },
            {'key': 'fee-2'},
          ]),
          200,
        );
      });

      final rows = await client.listBuilderFeeKeys(apiKey: apiKey);

      expect(capturedMethod, 'GET');
      expect(capturedPath, '/auth/builder-api-keys');
      expect(rows, hasLength(2));
      expect(rows[0].key, 'fee-1');
      expect(rows[0].createdAt, '2026-05-08T00:00:00Z');
      expect(rows[0].updatedAt, '2026-05-08T01:00:00Z');
      expect(rows[1].key, 'fee-2');
    });
  });

  group('revokeBuilderFeeKey', () {
    const apiKey = ApiKey(
      key: 'l2-key-uuid',
      secret: 'BASE64SECRETXX',
      passphrase: 'l2-pass',
    );

    test('DELETEs /auth/builder-api-key/<key>', () async {
      String? capturedPath;
      String? capturedMethod;
      final client = _client((req) async {
        capturedPath = req.url.path;
        capturedMethod = req.method;
        return http.Response('{}', 200);
      });

      await client.revokeBuilderFeeKey(apiKey: apiKey, builderKey: 'fee-1');

      expect(capturedMethod, 'DELETE');
      expect(capturedPath, '/auth/builder-api-key/fee-1');
    });

    test('rejects empty builderKey without hitting the network', () async {
      var hit = false;
      final client = _client((req) async {
        hit = true;
        return http.Response('{}', 200);
      });

      expect(
        () => client.revokeBuilderFeeKey(apiKey: apiKey, builderKey: '   '),
        throwsA(isA<ValidationException>()),
      );
      expect(hit, isFalse);
    });
  });
}
