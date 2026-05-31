import 'package:polydart/src/transport/redact.dart';
import 'package:test/test.dart';

void main() {
  group('redactSecret', () {
    test('empty stays empty', () {
      expect(redactSecret(''), '');
    });

    test('short strings become [REDACTED]', () {
      expect(redactSecret('abc'), '[REDACTED]');
      expect(redactSecret('12345678'), '[REDACTED]');
    });

    test('longer strings keep first and last 4 chars', () {
      expect(redactSecret('abcd1234efgh'), 'abcd...efgh');
      expect(redactSecret('0123456789ab'), '0123...89ab');
    });
  });

  group('redactMap', () {
    test('redacts known sensitive headers', () {
      final out = redactMap({
        'POLY_PRIVATE_KEY': '0123456789abcdef',
        'POLY_API_KEY': 'short',
        'X-Public': 'safe',
      });
      expect(out['POLY_PRIVATE_KEY'], '0123...cdef');
      expect(out['POLY_API_KEY'], '[REDACTED]');
      expect(out['X-Public'], 'safe');
    });

    test('case-insensitive header match', () {
      final out = redactMap({'poly_secret': 'hunter22'});
      expect(out['poly_secret'], '[REDACTED]');
    });

    test('redacts relayer API key while preserving address provenance', () {
      final out = redactMap({
        'RELAYER_API_KEY': 'relayer-secret-token',
        'RELAYER_API_KEY_ADDRESS': '0xowner',
      });

      expect(out['RELAYER_API_KEY'], 'rela...oken');
      expect(out['RELAYER_API_KEY_ADDRESS'], '0xowner');
    });

    test('non-sensitive headers pass through', () {
      final out = redactMap({'Content-Type': 'application/json'});
      expect(out['Content-Type'], 'application/json');
    });
  });
}
