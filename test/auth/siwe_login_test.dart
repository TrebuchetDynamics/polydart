// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/auth/siwe_login.dart';
import 'package:polydart/src/auth/wallet_signer.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:test/test.dart';

class _FakeSigner implements WalletSigner {
  @override
  String get address => '0x9d8a62f656a8d1615c1294fd71e9cfb3e4855a4f';

  @override
  int get chainId => 137;

  Uint8List? lastSignedMessage;

  @override
  Future<Uint8List> personalSign(Uint8List message) async {
    lastSignedMessage = message;
    // Deterministic 65-byte sig — enough for SIWE token assembly.
    return Uint8List.fromList(List<int>.generate(65, (i) => i & 0xff));
  }

  @override
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData) async {
    return Uint8List(65);
  }
}

void main() {
  group('SIWESession.login', () {
    test('GETs /nonce, signs, GETs /login, captures cookies', () async {
      String? loginAuthHeader;
      final mock = MockClient((req) async {
        switch (req.url.path) {
          case '/nonce':
            expect(req.method, 'GET');
            return http.Response(
              jsonEncode({'nonce': 'test-nonce-abc'}),
              200,
              headers: {
                'set-cookie':
                    'polymarketnonce=ABC123; Path=/, __cf_bm=BOT-MGMT; Path=/',
                'content-type': 'application/json',
              },
            );
          case '/login':
            expect(req.method, 'GET');
            loginAuthHeader =
                req.headers['Authorization'] ?? req.headers['authorization'];
            return http.Response(
              jsonEncode({'type': 'EOA', 'address': '0x9d8A...'}),
              200,
              headers: {
                'set-cookie':
                    'polymarketsession=SESSION-VALUE; Path=/, '
                    'polymarketauthtype=metamask; Path=/',
                'content-type': 'application/json',
              },
            );
          default:
            return http.Response('not found', 404);
        }
      });

      final signer = _FakeSigner();
      final session = SIWESession(
        signer: signer,
        gammaBaseUrl: 'https://gamma-api.example.com',
        httpClient: mock,
        clock: () => DateTime.utc(2026, 5, 8, 12, 0, 0),
      );

      await session.login();

      expect(session.hasSession, isTrue);
      // The Cookie header must include the session cookie pair.
      expect(
        session.cookieHeader().contains('polymarketsession=SESSION-VALUE'),
        isTrue,
      );
      expect(
        session.cookieHeader().contains('polymarketauthtype=metamask'),
        isTrue,
      );
      expect(session.cookieHeader().contains('polymarketnonce=ABC123'), isTrue);

      // The /login Authorization header must carry the SIWE bearer.
      expect(loginAuthHeader, isNotNull);
      expect(loginAuthHeader!.startsWith('Bearer '), isTrue);
      final token = loginAuthHeader!.substring('Bearer '.length);
      final decoded = utf8.decode(base64.decode(token));
      expect(decoded.contains('"nonce":"test-nonce-abc"'), isTrue);
      expect(decoded.contains(':::0x'), isTrue);

      // Signer should have been asked to personal-sign the SIWE blob.
      expect(signer.lastSignedMessage, isNotNull);
      final signedText = utf8.decode(signer.lastSignedMessage!);
      expect(
        signedText.contains('Welcome to Polymarket! Sign to connect.'),
        isTrue,
      );
    });

    test('throws TransportException when /nonce returns 500', () async {
      final mock = MockClient((req) async => http.Response('boom', 500));
      final session = SIWESession(
        signer: _FakeSigner(),
        gammaBaseUrl: 'https://gamma-api.example.com',
        httpClient: mock,
      );
      expect(() => session.login(), throwsA(isA<TransportException>()));
    });

    test('throws when nonce is empty', () async {
      final mock = MockClient((req) async {
        return http.Response(jsonEncode({'nonce': ''}), 200);
      });
      final session = SIWESession(
        signer: _FakeSigner(),
        gammaBaseUrl: 'https://gamma-api.example.com',
        httpClient: mock,
      );
      expect(() => session.login(), throwsA(isA<TransportException>()));
    });
  });

  group('cookieHeader', () {
    test('replaces same-name cookie on re-set', () async {
      var loginCalls = 0;
      final mock = MockClient((req) async {
        if (req.url.path == '/nonce') {
          return http.Response(
            jsonEncode({'nonce': 'n'}),
            200,
            headers: {
              'set-cookie': 'polymarketsession=OLD; Path=/',
              'content-type': 'application/json',
            },
          );
        }
        loginCalls++;
        return http.Response(
          '{}',
          200,
          headers: {
            'set-cookie': 'polymarketsession=NEW; Path=/',
            'content-type': 'application/json',
          },
        );
      });
      final session = SIWESession(
        signer: _FakeSigner(),
        gammaBaseUrl: 'https://gamma-api.example.com',
        httpClient: mock,
      );
      await session.login();
      expect(loginCalls, 1);
      expect(session.cookieHeader().contains('polymarketsession=NEW'), isTrue);
      expect(session.cookieHeader().contains('polymarketsession=OLD'), isFalse);
    });
  });
}
