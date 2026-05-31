import 'dart:convert';
import 'package:polydart/src/auth/clob_auth.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:test/test.dart';

import '../support/auth_test_fixtures.dart';
import '../support/fake_wallet_signer.dart';

void main() {
  group('buildClobAuthTypedData', () {
    test('matches the wallet provider shape', () {
      final typed = buildClobAuthTypedData(
        address: '0xabc',
        chainId: 137,
        timestamp: 1700000000,
        nonce: 0,
      );
      expect(typed['primaryType'], 'ClobAuth');
      expect(typed['domain']['name'], 'ClobAuthDomain');
      expect(typed['domain']['version'], '1');
      expect(typed['domain']['chainId'], 137);
      expect(typed['message']['address'], '0xabc');
      expect(typed['message']['timestamp'], '1700000000');
      expect(typed['message']['nonce'], 0);
      expect(typed['message']['message'], clobAuthDefaultMessage);
      // JSON-serializable end-to-end.
      expect(() => jsonEncode(typed), returnsNormally);
    });
  });

  group('hashClobAuth', () {
    test('different timestamps produce different digests', () {
      final h1 = hashClobAuth(
        address: '0x${'a' * 40}',
        chainId: 137,
        timestamp: 1700000000,
        nonce: 0,
      );
      final h2 = hashClobAuth(
        address: '0x${'a' * 40}',
        chainId: 137,
        timestamp: 1700000001,
        nonce: 0,
      );
      expect(h1.length, 32);
      expect(h1, isNot(h2));
    });
  });

  group('buildL1Headers', () {
    test('returns POLY_* headers wired to signer', () async {
      final canned = deterministicSignature((i) => i == 64 ? 27 : 0xab);
      final signer = FakeWalletSigner(
        address: '0xowner',
        chainId: 137,
        signature: canned,
      );
      final headers = await buildL1Headers(
        signer: signer,
        timestamp: 1700000000,
      );
      expect(headers['POLY_ADDRESS'], '0xowner');
      expect(headers['POLY_TIMESTAMP'], '1700000000');
      expect(headers['POLY_NONCE'], '0');
      expect(headers['POLY_SIGNATURE'], startsWith('0x'));
      expect(headers['POLY_SIGNATURE']!.length, 2 + 65 * 2);
      expect(signer.lastTypedData!['primaryType'], 'ClobAuth');
    });

    test('rejects non-Polygon signer before wallet signing', () async {
      final canned = deterministicSignature((i) => i == 64 ? 27 : 0xab);
      final signer = FakeWalletSigner(
        address: '0xowner',
        chainId: 1,
        signature: canned,
      );

      await expectLater(
        buildL1Headers(signer: signer, timestamp: 1700000000),
        throwsA(
          isA<ValidationException>()
              .having(
                (error) => error.message,
                'message',
                contains('CLOB auth signing requires Polygon chainId=137'),
              )
              .having((error) => error.field, 'field', 'chainId'),
        ),
      );
      expect(signer.signTypedDataCalls, 0);
      expect(signer.lastTypedData, isNull);
    });
  });
}
