import 'dart:typed_data';

import 'package:polydart/src/auth/eip712.dart';
import 'package:polydart/src/auth/eth_hex.dart';
import 'package:test/test.dart';

void main() {
  group('eip712TypeHash', () {
    test('canonical EIP712Domain locks in keccak of the type string', () {
      // keccak256("EIP712Domain(string name,string version,uint256 chainId)")
      // Computed with `dart run tool/compute_typehash.dart`. Treat as a
      // parity fixture — bumping this means we changed the type
      // serialization and broke compatibility with polygolem.
      final h = eip712TypeHash('EIP712Domain', const [
        Eip712Field('name', 'string'),
        Eip712Field('version', 'string'),
        Eip712Field('chainId', 'uint256'),
      ]);
      expect(
        bytesToHex(h),
        'c2f8787176b8ac6bf7215b4adcc1e069bf4ab82d9ab1df05a57a91d425935b6e',
      );
      // Different field order produces a different hash.
      final h3 = eip712TypeHash('EIP712Domain', const [
        Eip712Field('version', 'string'),
        Eip712Field('name', 'string'),
        Eip712Field('chainId', 'uint256'),
      ]);
      expect(h3, isNot(h));
    });

    test('ClobAuth canonical type hash', () {
      // keccak256("ClobAuth(address address,string timestamp,uint256 nonce,string message)")
      // Computed with `dart run tool/compute_typehash.dart`.
      final h = eip712TypeHash('ClobAuth', const [
        Eip712Field('address', 'address'),
        Eip712Field('timestamp', 'string'),
        Eip712Field('nonce', 'uint256'),
        Eip712Field('message', 'string'),
      ]);
      expect(
        bytesToHex(h),
        '52578c5c725a28a84fedc8c22aa47947822942f35b4dc350db028e45320e035c',
      );
    });
  });

  group('eip712DomainSeparator', () {
    test('domain hash is 32 bytes and depends on chainId', () {
      const a = Eip712Domain(name: 'X', version: '1', chainId: 137);
      const b = Eip712Domain(name: 'X', version: '1', chainId: 1);
      final ha = eip712DomainSeparator(a);
      final hb = eip712DomainSeparator(b);
      expect(ha.length, 32);
      expect(ha, isNot(hb));
    });
  });

  group('hashTypedData (envelope)', () {
    test('changes when domain or message changes', () {
      const fields = <Eip712Field>[
        Eip712Field('to', 'address'),
        Eip712Field('amount', 'uint256'),
      ];
      final h1 = hashTypedData(
        domain: const Eip712Domain(name: 'X', version: '1', chainId: 137),
        primaryType: 'Transfer',
        fields: fields,
        message: <String, Object?>{
          'to': '0x${'a' * 40}',
          'amount': BigInt.from(100),
        },
      );
      final h2 = hashTypedData(
        domain: const Eip712Domain(name: 'X', version: '1', chainId: 1),
        primaryType: 'Transfer',
        fields: fields,
        message: <String, Object?>{
          'to': '0x${'a' * 40}',
          'amount': BigInt.from(100),
        },
      );
      final h3 = hashTypedData(
        domain: const Eip712Domain(name: 'X', version: '1', chainId: 137),
        primaryType: 'Transfer',
        fields: fields,
        message: <String, Object?>{
          'to': '0x${'a' * 40}',
          'amount': BigInt.from(101),
        },
      );
      expect(h1, isNot(h2));
      expect(h1, isNot(h3));
      expect(h1, isA<Uint8List>());
      expect(h1.length, 32);
    });
  });

  test('atomic encoder rejects bad bytes32', () {
    expect(
      () => hashTypedData(
        domain: const Eip712Domain(name: 'X', version: '1', chainId: 137),
        primaryType: 'T',
        fields: const [Eip712Field('h', 'bytes32')],
        message: <String, Object?>{'h': '0x12'},
      ),
      throwsA(isA<Object>()),
    );
  });
}
