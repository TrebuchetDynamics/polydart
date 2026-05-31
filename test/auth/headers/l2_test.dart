import 'package:polydart/src/auth/l2.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:test/test.dart';

import '../support/auth_test_fixtures.dart';

void main() {
  group('signHmac', () {
    test('parity fixture: matches polygolem output', () {
      // Computed from polygolem (`go run` of internal/auth.SignHMAC) for
      // the same inputs. If this changes, our HMAC pipeline broke parity.
      final sig = signHmac(
        secret: canonicalHmacSecret,
        timestamp: 1700000000,
        method: 'GET',
        path: '/book',
      );
      expect(sig, 'sGnIqIS0w73jlTVhz44U7ULfi9vy6WvUM6twuXXWi-o=');
    });

    test('deterministic for the same inputs', () {
      final a = signHmac(
        secret: canonicalHmacSecret,
        timestamp: 1700000000,
        method: 'GET',
        path: '/book',
      );
      final b = signHmac(
        secret: canonicalHmacSecret,
        timestamp: 1700000000,
        method: 'GET',
        path: '/book',
      );
      expect(a, b);
      expect(a, isNotEmpty);
      // No raw '+' or '/' characters — already URL-safe.
      expect(a.contains('+'), isFalse);
      expect(a.contains('/'), isFalse);
    });

    test('differs across timestamps', () {
      final a = signHmac(
        secret: canonicalHmacSecret,
        timestamp: 1700000000,
        method: 'GET',
        path: '/book',
      );
      final b = signHmac(
        secret: canonicalHmacSecret,
        timestamp: 1700000001,
        method: 'GET',
        path: '/book',
      );
      expect(a, isNot(b));
    });

    test('differs when body changes', () {
      final a = signHmac(
        secret: canonicalHmacSecret,
        timestamp: 1700000000,
        method: 'POST',
        path: '/order',
        body: '{"token_id":"123"}',
      );
      final b = signHmac(
        secret: canonicalHmacSecret,
        timestamp: 1700000000,
        method: 'POST',
        path: '/order',
        body: '{"token_id":"124"}',
      );
      expect(a, isNot(b));
    });

    test('survives non-base64 secret (raw bytes fallback)', () {
      final sig = signHmac(
        secret: 'this-is-not-base64!!!',
        timestamp: 1700000000,
        method: 'GET',
        path: '/x',
      );
      expect(sig, isNotEmpty);
    });
  });

  group('buildL2Headers', () {
    test('full header set', () {
      final headers = buildL2Headers(
        apiKey: const ApiKey(
          key: 'k',
          secret: canonicalHmacSecret,
          passphrase: 'p',
        ),
        timestamp: 1700000000,
        method: 'GET',
        path: '/book',
      );
      expect(headers['POLY_API_KEY'], 'k');
      expect(headers['POLY_PASSPHRASE'], 'p');
      expect(headers['POLY_TIMESTAMP'], '1700000000');
      expect(headers['POLY_SIGNATURE'], isNotEmpty);
    });

    test('rejects missing fields', () {
      expect(
        () => buildL2Headers(
          apiKey: const ApiKey(key: '', secret: 's', passphrase: 'p'),
          timestamp: 1700000000,
          method: 'GET',
          path: '/x',
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('builder headers', () {
    test('rejects empty config', () {
      expect(
        () => buildBuilderHeaders(
          config: const BuilderConfig(key: '', secret: 's', passphrase: 'p'),
          timestamp: 1700000000,
          method: 'POST',
          path: '/order',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('returns POLY_BUILDER_* set', () {
      final headers = buildBuilderHeaders(
        config: const BuilderConfig(
          key: 'bk',
          secret: canonicalHmacSecret,
          passphrase: 'bp',
        ),
        timestamp: 1700000000,
        method: 'POST',
        path: '/order',
      );
      expect(headers['POLY_BUILDER_API_KEY'], 'bk');
      expect(headers['POLY_BUILDER_PASSPHRASE'], 'bp');
      expect(headers['POLY_BUILDER_SIGNATURE'], isNotEmpty);
      expect(headers.containsKey('POLY_API_KEY'), isFalse);
    });
  });

  group('compactJson', () {
    test('strips whitespace outside strings', () {
      expect(compactJson('{"a": 1, "b": [1, 2]}'), '{"a":1,"b":[1,2]}');
    });

    test('preserves whitespace inside strings', () {
      expect(compactJson('{"k": " hello world "}'), '{"k":" hello world "}');
    });

    test('handles escaped quotes inside strings', () {
      expect(compactJson(r'{"k": "a\"b "}'), r'{"k":"a\"b "}');
    });
  });

  test('ApiKey.redacted returns redacted view', () {
    const k = ApiKey(
      key: 'my-secret-key-123',
      secret: 'supersecret',
      passphrase: 'pass',
    );
    expect(k.redacted().key, isNot('my-secret-key-123'));
    expect(k.redacted().secret, isNot('supersecret'));
    expect(k.redacted().passphrase, '[REDACTED]');
  });
}
