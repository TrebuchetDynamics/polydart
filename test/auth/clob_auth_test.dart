import 'dart:convert';
import 'dart:typed_data';

import 'package:polydart/src/auth/clob_auth.dart';
import 'package:polydart/src/auth/wallet_signer.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:test/test.dart';

class _CannedSigner implements WalletSigner {
  _CannedSigner(this.address, this.chainId, this.signature);
  @override
  final String address;
  @override
  final int chainId;
  final Uint8List signature;
  Map<String, dynamic>? lastTyped;
  int signTypedDataCalls = 0;

  @override
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData) async {
    signTypedDataCalls++;
    lastTyped = typedData;
    return signature;
  }

  @override
  Future<Uint8List> personalSign(Uint8List message) async => signature;
}

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
      final canned = Uint8List.fromList(List<int>.filled(65, 0xab));
      canned[64] = 27;
      final signer = _CannedSigner('0xowner', 137, canned);
      final headers = await buildL1Headers(
        signer: signer,
        timestamp: 1700000000,
      );
      expect(headers['POLY_ADDRESS'], '0xowner');
      expect(headers['POLY_TIMESTAMP'], '1700000000');
      expect(headers['POLY_NONCE'], '0');
      expect(headers['POLY_SIGNATURE'], startsWith('0x'));
      expect(headers['POLY_SIGNATURE']!.length, 2 + 65 * 2);
      expect(signer.lastTyped!['primaryType'], 'ClobAuth');
    });

    test('rejects non-Polygon signer before wallet signing', () async {
      final canned = Uint8List.fromList(List<int>.filled(65, 0xab));
      canned[64] = 27;
      final signer = _CannedSigner('0xowner', 1, canned);

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
      expect(signer.lastTyped, isNull);
    });
  });
}
