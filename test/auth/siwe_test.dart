// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';
import 'dart:typed_data';

import 'package:polydart/src/auth/siwe.dart';
import 'package:test/test.dart';

void main() {
  group('toEIP55Checksum', () {
    test('matches go-ethereum HexToAddress(...).Hex() output', () {
      final got = toEIP55Checksum('0x9d8a62f656a8d1615c1294fd71e9cfb3e4855a4f');
      expect(got, '0x9d8A62f656a8d1615C1294fd71e9CFb3E4855A4F');
    });

    test('uppercases input is normalized', () {
      final got = toEIP55Checksum('0X9D8A62F656A8D1615C1294FD71E9CFB3E4855A4F');
      expect(got, '0x9d8A62f656a8d1615C1294fd71e9CFb3E4855A4F');
    });

    test('rejects wrong-length input', () {
      expect(() => toEIP55Checksum('0xabc'), throwsArgumentError);
    });
  });

  group('SIWEMessage.toString', () {
    test('matches EIP-4361 layout', () {
      final msg = buildPolymarketSIWE(
        address: '0x9d8a62f656a8d1615c1294fd71e9cfb3e4855a4f',
        nonce: 'abc123',
        chainId: 137,
        now: DateTime.utc(2026, 5, 8, 12, 0, 0),
      );
      final got = msg.toString();
      const want = 'polymarket.com wants you to sign in with your Ethereum account:\n'
          '0x9d8A62f656a8d1615C1294fd71e9CFb3E4855A4F\n\n'
          'Welcome to Polymarket! Sign to connect.\n\n'
          'URI: https://polymarket.com\n'
          'Version: 1\n'
          'Chain ID: 137\n'
          'Nonce: abc123\n'
          'Issued At: 2026-05-08T12:00:00Z\n'
          'Expiration Time: 2026-05-15T12:00:00Z';
      expect(got, want);
    });
  });

  group('buildSIWEBearerToken', () {
    test('base64-encodes JSON + ":::" + 0x signature', () {
      final msg = buildPolymarketSIWE(
        address: '0x9d8a62f656a8d1615c1294fd71e9cfb3e4855a4f',
        nonce: 'abc',
        chainId: 137,
        now: DateTime.utc(2026, 5, 8, 12, 0, 0),
      );
      final sig = Uint8List.fromList(List<int>.generate(65, (i) => i));

      final token = buildSIWEBearerToken(msg, sig);
      final decoded = utf8.decode(base64.decode(token));

      expect(decoded.contains(':::0x'), isTrue);
      expect(decoded.contains('"chainId":137'), isTrue);
      expect(
        decoded.contains(
          '"address":"0x9d8A62f656a8d1615C1294fd71e9CFb3E4855A4F"',
        ),
        isTrue,
      );
      expect(decoded.contains('"nonce":"abc"'), isTrue);
    });
  });
}
