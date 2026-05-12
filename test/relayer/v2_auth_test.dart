// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/auth/siwe_login.dart';
import 'package:polydart/src/auth/wallet_signer.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/relayer/v2_auth.dart';
import 'package:test/test.dart';

class _StubSigner implements WalletSigner {
  @override
  String get address => '0x9d8a62f656a8d1615c1294fd71e9cfb3e4855a4f';
  @override
  int get chainId => 137;
  @override
  Future<Uint8List> personalSign(Uint8List message) async =>
      Uint8List.fromList(List<int>.generate(65, (i) => i & 0xff));
  @override
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData) async =>
      Uint8List(65);
}

Future<SIWESession> _loggedInSession() async {
  final mock = MockClient((req) async {
    switch (req.url.path) {
      case '/nonce':
        return http.Response(
          jsonEncode({'nonce': 'n'}),
          200,
          headers: {'set-cookie': '__cf_bm=cf; Path=/'},
        );
      default:
        return http.Response(
          '{}',
          200,
          headers: {'set-cookie': 'polymarketsession=SESSION; Path=/'},
        );
    }
  });
  final session = SIWESession(
    signer: _StubSigner(),
    gammaBaseUrl: 'https://gamma-api.example.com',
    httpClient: mock,
  );
  await session.login();
  return session;
}

void main() {
  group('mintV2APIKey', () {
    test(
      'POSTs /relayer/api/auth with cookie + parses {apiKey, address}',
      () async {
        final session = await _loggedInSession();

        String? sawCookie;
        String? sawBody;
        String? sawMethod;
        String? sawPath;
        final mock = MockClient((req) async {
          sawMethod = req.method;
          sawPath = req.url.path;
          sawCookie = req.headers['Cookie'] ?? req.headers['cookie'];
          sawBody = req.body;
          return http.Response(
            jsonEncode({
              'apiKey': '019e0650-uuid',
              'address': '0xabc',
              'createdAt': '2026-05-08T00:00:00Z',
            }),
            200,
          );
        });

        final key = await mintV2APIKey(
          session: session,
          relayerBaseUrl: 'https://relayer-v2.example.com',
          httpClient: mock,
        );

        expect(sawMethod, 'POST');
        expect(sawPath, '/relayer/api/auth');
        expect(sawBody, '{}');
        expect(sawCookie, contains('polymarketsession=SESSION'));

        expect(key.key, '019e0650-uuid');
        expect(key.address, '0xabc');
        expect(key.createdAt, '2026-05-08T00:00:00Z');
      },
    );

    test('throws when SIWESession has no cookies', () async {
      final session = SIWESession(
        signer: _StubSigner(),
        gammaBaseUrl: 'https://gamma-api.example.com',
      );
      expect(
        () => mintV2APIKey(session: session),
        throwsA(isA<AuthException>()),
      );
    });

    test('throws on non-2xx', () async {
      final session = await _loggedInSession();
      final mock = MockClient(
        (req) async => http.Response('unauthorized', 401),
      );
      expect(
        () => mintV2APIKey(session: session, httpClient: mock),
        throwsA(isA<TransportException>()),
      );
    });

    test('throws on incomplete response', () async {
      final session = await _loggedInSession();
      final mock = MockClient(
        (req) async =>
            http.Response(jsonEncode({'apiKey': '', 'address': ''}), 200),
      );
      expect(
        () => mintV2APIKey(session: session, httpClient: mock),
        throwsA(isA<TransportException>()),
      );
    });
  });

  group('V2APIKey.v2Headers', () {
    test('emits RELAYER_API_KEY + RELAYER_API_KEY_ADDRESS', () {
      const key = V2APIKey(key: 'uuid-1', address: '0xabc');
      final headers = key.v2Headers();
      expect(headers['RELAYER_API_KEY'], 'uuid-1');
      expect(headers['RELAYER_API_KEY_ADDRESS'], '0xabc');
    });
  });
}
