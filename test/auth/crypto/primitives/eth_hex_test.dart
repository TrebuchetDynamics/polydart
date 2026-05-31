import 'package:polydart/src/auth/eth_hex.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:test/test.dart';

void main() {
  group('stripHexPrefix', () {
    test('removes lowercase and uppercase prefixes only', () {
      expect(stripHexPrefix('0xdead'), 'dead');
      expect(stripHexPrefix('0Xdead'), 'dead');
      expect(stripHexPrefix('dead'), 'dead');
    });
  });

  group('hexToBytes', () {
    test('handles 0x and bare', () {
      expect(hexToBytes('0xdeadbeef'), [0xde, 0xad, 0xbe, 0xef]);
      expect(hexToBytes('deadbeef'), [0xde, 0xad, 0xbe, 0xef]);
    });

    test('odd-length pads', () {
      expect(hexToBytes('0xabc'), [0x0a, 0xbc]);
    });

    test('empty', () {
      expect(hexToBytes(''), isEmpty);
      expect(hexToBytes('0x'), isEmpty);
    });

    test('rejects garbage', () {
      expect(() => hexToBytes('0xZZ'), throwsA(isA<ValidationException>()));
    });
  });

  group('bytesToHex0x', () {
    test('round-trips with hexToBytes', () {
      final bytes = [0x12, 0x34, 0xab, 0xcd, 0x00, 0xff];
      expect(hexToBytes(bytesToHex0x(bytes)), bytes);
    });
  });

  group('normalizeAddress', () {
    test('lowers and 0x-prefixes', () {
      expect(
        normalizeAddress('2c7536E3605D9C16a7a3D7b1898e529396a65c23'),
        '0x2c7536e3605d9c16a7a3d7b1898e529396a65c23',
      );
    });

    test('left-pads short forms', () {
      expect(
        normalizeAddress('0xabc'),
        '0x0000000000000000000000000000000000000abc',
      );
    });

    test('rejects oversize', () {
      expect(
        () => normalizeAddress('0x${'a' * 41}'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects non-hex', () {
      expect(
        () => normalizeAddress('0xZZ'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('uint256BigEndian', () {
    test('zero is 32 zero bytes', () {
      final z = uint256BigEndian(BigInt.zero);
      expect(z.length, 32);
      expect(z.every((b) => b == 0), isTrue);
    });

    test('one is right-aligned', () {
      final one = uint256BigEndian(BigInt.one);
      expect(one.length, 32);
      expect(one[31], 1);
      expect(one[30], 0);
    });

    test('encodes 137', () {
      final v = uint256BigEndian(BigInt.from(137));
      expect(v[31], 137);
      expect(v[30], 0);
    });

    test('encodes a 20-byte value', () {
      final big = BigInt.parse('1' * 40, radix: 16);
      final v = uint256BigEndian(big);
      expect(v.length, 32);
    });

    test('rejects negative', () {
      expect(
        () => uint256BigEndian(BigInt.from(-1)),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('keccak256', () {
    test('"abc" matches the canonical EVM digest', () {
      // keccak256("abc") =
      // 4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45
      expect(
        bytesToHex(keccak256Utf8('abc')),
        '4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45',
      );
    });

    test('empty string digest', () {
      // keccak256("") =
      // c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
      expect(
        bytesToHex(keccak256Utf8('')),
        'c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470',
      );
    });
  });
}
