import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

const _address = '0x0000000000000000000000000000000000001234';
const _cacheKey = CredentialKey(eoaAddress: _address, chainId: 137);
const _cachedClobKey = ApiKey(
  key: 'cached-clob-key',
  secret: 'cached-clob-secret',
  passphrase: 'cached-clob-pass',
);
const _cachedBuilderFeeKey = ApiKey(
  key: 'cached-builder-key',
  secret: 'cached-builder-secret',
  passphrase: 'cached-builder-pass',
);

void main() {
  group('LiveCredentialService.ensure', () {
    test(
      'returns cached CLOB and builder keys without signing or HTTP',
      () async {
        final store = MemoryCredentialStore();
        await store.writeClobApiKey(_cacheKey, _cachedClobKey);
        await store.writeBuilderFeeKey(_cacheKey, _cachedBuilderFeeKey);
        final signer = _CannedSigner();
        final client = _client((_) async => fail('HTTP should not be called'));

        final result = await LiveCredentialService(
          clob: client,
          credentialStore: store,
          nowSeconds: () => 1700000000,
        ).ensure(signer: signer);

        expect(result.clobApiKey.status, LiveCredentialStatus.cached);
        expect(result.clobApiKey.value, same(_cachedClobKey));
        expect(result.builderFeeKey.status, LiveCredentialStatus.cached);
        expect(result.builderFeeKey.value, same(_cachedBuilderFeeKey));
        expect(result.clobApiKey.isReady, isTrue);
        expect(result.ready, isTrue);
        expect(signer.signTypedDataCalls, 0);
        expect(result.toString(), isNot(contains('cached-clob-secret')));
        expect(result.toString(), isNot(contains('cached-builder-secret')));
      },
    );

    test('creates CLOB and builder-fee keys and stores both', () async {
      final requests = <Map<String, dynamic>>[];
      final store = MemoryCredentialStore();
      final signer = _CannedSigner();
      final client = _client((req) async {
        requests.add(_request(req));
        if (req.url.path == '/auth/builder-api-key') {
          return _apiKeyResponse(
            key: 'created-builder-key',
            secret: 'created-builder-secret',
            passphrase: 'created-builder-pass',
          );
        }
        return _apiKeyResponse(
          key: 'created-clob-key',
          secret: 'created-clob-secret',
          passphrase: 'created-clob-pass',
        );
      });

      final result = await LiveCredentialService(
        clob: client,
        credentialStore: store,
        nowSeconds: () => 1700000001,
      ).ensure(signer: signer);

      expect(
        requests.map((r) => '${r['method']} ${r['path']}').toList(),
        <String>['POST /auth/api-key', 'POST /auth/builder-api-key'],
      );
      final headers = requests[0]['headers'] as Map<String, String>;
      expect(headers['POLY_ADDRESS'], _address);
      expect(headers['POLY_TIMESTAMP'], '1700000001');
      expect(headers['POLY_NONCE'], '0');
      expect(headers['POLY_SIGNATURE'], startsWith('0x'));
      final builderHeaders = requests[1]['headers'] as Map<String, String>;
      expect(builderHeaders['POLY_API_KEY'], 'created-clob-key');
      expect(builderHeaders['POLY_PASSPHRASE'], 'created-clob-pass');
      expect(builderHeaders['POLY_SIGNATURE'], isNotNull);
      expect(signer.signTypedDataCalls, 1);
      expect(signer.lastTypedData!['primaryType'], 'ClobAuth');
      expect(result.clobApiKey.status, LiveCredentialStatus.created);
      expect(result.clobApiKey.value!.key, 'created-clob-key');
      expect(result.builderFeeKey.status, LiveCredentialStatus.created);
      expect(result.builderFeeKey.value!.key, 'created-builder-key');

      final storedClob = await store.readClobApiKey(_cacheKey);
      expect(storedClob!.key, 'created-clob-key');
      expect(storedClob.secret, 'created-clob-secret');
      final storedBuilder = await store.readBuilderFeeKey(_cacheKey);
      expect(storedBuilder!.key, 'created-builder-key');
      expect(storedBuilder.secret, 'created-builder-secret');
    });

    test(
      'uses cached CLOB key when creating a missing builder-fee key',
      () async {
        final store = MemoryCredentialStore();
        await store.writeClobApiKey(_cacheKey, _cachedClobKey);
        final signer = _CannedSigner();
        Map<String, dynamic>? request;
        final client = _client((req) async {
          request = _request(req);
          return _apiKeyResponse(
            key: 'new-builder-key',
            secret: 'new-builder-secret',
            passphrase: 'new-builder-pass',
          );
        });

        final result = await LiveCredentialService(
          clob: client,
          credentialStore: store,
          nowSeconds: () => 1700000006,
        ).ensure(signer: signer);

        expect(request!['method'], 'POST');
        expect(request!['path'], '/auth/builder-api-key');
        final headers = request!['headers'] as Map<String, String>;
        expect(headers['POLY_API_KEY'], _cachedClobKey.key);
        expect(headers['POLY_PASSPHRASE'], _cachedClobKey.passphrase);
        expect(signer.signTypedDataCalls, 0);
        expect(result.clobApiKey.status, LiveCredentialStatus.cached);
        expect(result.builderFeeKey.status, LiveCredentialStatus.created);
        expect(result.builderFeeKey.value!.key, 'new-builder-key');
      },
    );

    test('derives with the same L1 signature after create conflict', () async {
      final signer = _CannedSigner();
      final seen = <Map<String, dynamic>>[];
      final client = _client((req) async {
        final request = _request(req);
        seen.add(request);
        if (req.url.path == '/auth/builder-api-key') {
          return _apiKeyResponse(
            key: 'builder-after-derived',
            secret: 'builder-secret',
            passphrase: 'builder-pass',
          );
        }
        if (req.method == 'POST') {
          return http.Response('already exists', 409);
        }
        return _apiKeyResponse(
          key: 'derived-clob-key',
          secret: 'derived-clob-secret',
          passphrase: 'derived-clob-pass',
        );
      });

      final result = await LiveCredentialService(
        clob: client,
        nowSeconds: () => 1700000002,
      ).ensure(signer: signer);

      expect(seen.map((r) => '${r['method']} ${r['path']}').toList(), <String>[
        'POST /auth/api-key',
        'GET /auth/derive-api-key',
        'POST /auth/builder-api-key',
      ]);
      final createHeaders = seen[0]['headers'] as Map<String, String>;
      final deriveHeaders = seen[1]['headers'] as Map<String, String>;
      expect(deriveHeaders['POLY_SIGNATURE'], createHeaders['POLY_SIGNATURE']);
      expect(signer.signTypedDataCalls, 1);
      expect(result.clobApiKey.status, LiveCredentialStatus.derived);
      expect(result.clobApiKey.value!.key, 'derived-clob-key');
      expect(result.builderFeeKey.status, LiveCredentialStatus.created);
      expect(result.builderFeeKey.value!.key, 'builder-after-derived');
    });

    test('returns userRejected when the wallet signer rejects', () async {
      final client = _client((_) async => fail('HTTP should not be called'));

      final result = await LiveCredentialService(
        clob: client,
        nowSeconds: () => 1700000003,
      ).ensure(signer: _RejectingSigner());

      expect(result.clobApiKey.status, LiveCredentialStatus.userRejected);
      expect(result.clobApiKey.value, isNull);
      expect(result.clobApiKey.action, LiveCredentialAction.requestSignature);
      expect(result.builderFeeKey.status, LiveCredentialStatus.blocked);
      expect(result.builderFeeKey.action, LiveCredentialAction.retry);
      expect(result.ready, isFalse);
    });

    test(
      'returns blocked when create and derive both fail over transport',
      () async {
        final client = _client((req) async {
          if (req.method == 'POST') return http.Response('conflict', 409);
          return http.Response('unavailable', 503);
        });

        final result = await LiveCredentialService(
          clob: client,
          nowSeconds: () => 1700000004,
        ).ensure(signer: _CannedSigner());

        expect(result.clobApiKey.status, LiveCredentialStatus.blocked);
        expect(result.clobApiKey.action, LiveCredentialAction.retry);
        expect(result.clobApiKey.value, isNull);
        expect(result.builderFeeKey.status, LiveCredentialStatus.blocked);
        expect(result.ready, isFalse);
      },
    );

    test(
      'returns partial success when builder-fee key creation fails',
      () async {
        final store = MemoryCredentialStore();
        await store.writeClobApiKey(_cacheKey, _cachedClobKey);
        final client = _client((req) async {
          expect(req.url.path, '/auth/builder-api-key');
          return http.Response('builder unavailable', 503);
        });

        final result = await LiveCredentialService(
          clob: client,
          credentialStore: store,
          nowSeconds: () => 1700000007,
        ).ensure(signer: _CannedSigner());

        expect(result.clobApiKey.status, LiveCredentialStatus.cached);
        expect(result.clobApiKey.value, same(_cachedClobKey));
        expect(result.builderFeeKey.status, LiveCredentialStatus.blocked);
        expect(result.builderFeeKey.action, LiveCredentialAction.retry);
        expect(result.builderFeeKey.value, isNull);
        expect(result.ready, isFalse);
      },
    );

    test('throws malformed API-key responses instead of hiding them', () async {
      final client = _client((_) async {
        return http.Response(jsonEncode(<String, dynamic>{}), 200);
      });

      await expectLater(
        LiveCredentialService(
          clob: client,
          nowSeconds: () => 1700000005,
        ).ensure(signer: _CannedSigner()),
        throwsA(isA<AuthException>()),
      );
    });
  });
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

http.Response _apiKeyResponse({
  required String key,
  required String secret,
  required String passphrase,
}) {
  return http.Response(
    jsonEncode(<String, dynamic>{
      'apiKey': key,
      'secret': secret,
      'passphrase': passphrase,
    }),
    200,
  );
}

Map<String, dynamic> _request(http.BaseRequest req) {
  return <String, dynamic>{
    'method': req.method,
    'path': req.url.path,
    'headers': req.headers,
  };
}

class _CannedSigner implements WalletSigner {
  @override
  String get address => _address;

  @override
  int get chainId => 137;

  var signTypedDataCalls = 0;
  Map<String, dynamic>? lastTypedData;

  @override
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData) async {
    signTypedDataCalls++;
    lastTypedData = typedData;
    return Uint8List.fromList(List<int>.filled(65, 0xab));
  }

  @override
  Future<Uint8List> personalSign(Uint8List message) async {
    return Uint8List.fromList(List<int>.filled(65, 0xcd));
  }
}

final class _RejectingSigner extends _CannedSigner {
  @override
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData) async {
    throw const WalletSignatureRejectedException('user rejected ClobAuth');
  }
}
