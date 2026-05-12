import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/builder/builder.dart';
import 'package:test/test.dart';

void main() {
  group('LocalBuilderSigner', () {
    test('creates all required POLY_BUILDER headers', () async {
      final signer = LocalBuilderSigner(
        const LocalBuilderSignerConfig(
          key: 'test-key',
          secret: 'dGVzdC1zZWNyZXQ=',
          passphrase: 'test-pass',
        ),
      );

      final headers = await signer.createHeaders(
        method: 'POST',
        path: '/order',
        timestamp: 1234567890,
      );

      expect(headers[polyBuilderApiKeyHeader], 'test-key');
      expect(headers[polyBuilderPassphraseHeader], 'test-pass');
      expect(headers[polyBuilderTimestampHeader], '1234567890');
      expect(headers[polyBuilderSignatureHeader], isNotEmpty);
    });

    test('matches GenSignature output', () async {
      final signer = LocalBuilderSigner(
        const LocalBuilderSignerConfig(
          key: 'key',
          secret: 'bXktc2VjcmV0',
          passphrase: 'pass',
        ),
      );
      const body = '{"test":true}';

      final headers = await signer.createHeaders(
        method: 'POST',
        path: '/order',
        body: body,
        timestamp: 1234567890,
      );

      expect(
        headers[polyBuilderSignatureHeader],
        genSignature(
          secret: 'bXktc2VjcmV0',
          timestamp: 1234567890,
          method: 'POST',
          path: '/order',
          body: body,
        ),
      );
      expect(headers[polyBuilderSignatureHeader]!.contains('+'), isFalse);
      expect(headers[polyBuilderSignatureHeader]!.contains('/'), isFalse);
    });

    test('rejects incomplete config', () {
      expect(
        () => LocalBuilderSigner(const LocalBuilderSignerConfig()),
        throwsArgumentError,
      );
    });
  });

  group('RemoteBuilderSigner', () {
    test('POSTs signing request and returns headers', () async {
      Map<String, dynamic>? payload;
      final signer = RemoteBuilderSigner(
        const RemoteBuilderSignerConfig(
          url: 'https://signer.example.test/sign',
          token: 'test-token',
        ),
        httpClient: MockClient((req) async {
          expect(req.method, 'POST');
          expect(req.url.toString(), 'https://signer.example.test/sign');
          expect(req.headers['Authorization'], 'Bearer test-token');
          expect(req.headers['Content-Type'], contains('application/json'));
          payload = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(<String, String>{
              polyBuilderApiKeyHeader: 'remote-key',
              polyBuilderTimestampHeader: '1234567890',
              polyBuilderPassphraseHeader: 'remote-pass',
              polyBuilderSignatureHeader: 'remote-sig',
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );

      final headers = await signer.createHeaders(
        method: 'POST',
        path: '/order',
        body: '{"order":true}',
      );

      expect(payload!['method'], 'POST');
      expect(payload!['path'], '/order');
      expect(payload!['body'], '{"order":true}');
      expect(headers[polyBuilderApiKeyHeader], 'remote-key');
      expect(headers[polyBuilderSignatureHeader], 'remote-sig');
    });

    test('includes timestamp when caller provides one', () async {
      Map<String, dynamic>? payload;
      final signer = RemoteBuilderSigner(
        const RemoteBuilderSignerConfig(url: 'https://signer.test', token: 't'),
        httpClient: MockClient((req) async {
          payload = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(<String, String>{}), 200);
        }),
      );

      await signer.createHeaders(method: 'GET', path: '/nonce', timestamp: 123);

      expect(payload!['timestamp'], '123');
    });

    test('rejects empty URL or token', () {
      expect(
        () => RemoteBuilderSigner(
          const RemoteBuilderSignerConfig(url: '', token: 'token'),
        ),
        throwsArgumentError,
      );
      expect(
        () => RemoteBuilderSigner(
          const RemoteBuilderSignerConfig(
            url: 'https://example.test',
            token: '',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('throws on non-2xx signer response', () async {
      final signer = RemoteBuilderSigner(
        const RemoteBuilderSignerConfig(url: 'https://signer.test', token: 't'),
        httpClient: MockClient((req) async => http.Response('nope', 500)),
      );

      expect(
        () => signer.createHeaders(method: 'GET', path: '/test'),
        throwsA(isA<RemoteBuilderSignerException>()),
      );
    });
  });
}
