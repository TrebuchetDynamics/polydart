import 'dart:typed_data';

import 'package:polydart/src/auth/create2.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:test/test.dart';

const _eoa = '0x2c7536E3605D9C16a7a3D7b1898e529396a65c23';

void main() {
  group('CREATE2 parity vectors (cross-validated against polygolem)', () {
    test('proxy wallet for the canonical test EOA', () {
      expect(
        deriveProxyWallet(_eoa),
        '0x96a9892de6a11fe0b18cf63373b9763055eca8a6',
      );
    });

    test('safe wallet for the canonical test EOA', () {
      expect(
        deriveSafeWallet(_eoa),
        '0x907c14d6cea8e8fc78dd3db152f0a93f43276b4d',
      );
    });

    test('deposit wallet for the canonical test EOA', () {
      expect(
        deriveDepositWallet(_eoa),
        '0xfd5041047be8c192c725a66228f141196fa3cf9c',
      );
    });
  });

  group('makerAddressForSignatureType', () {
    test('type 0 returns the EOA itself', () {
      expect(
        makerAddressForSignatureType(
          eoaAddress: _eoa,
          chainId: 137,
          signatureType: 0,
        ),
        '0x2c7536e3605d9c16a7a3d7b1898e529396a65c23',
      );
    });

    test('type 1 returns the proxy wallet', () {
      expect(
        makerAddressForSignatureType(
          eoaAddress: _eoa,
          chainId: 137,
          signatureType: 1,
        ),
        '0x96a9892de6a11fe0b18cf63373b9763055eca8a6',
      );
    });

    test('type 1 rejects non-Polygon chains', () {
      expect(
        () => makerAddressForSignatureType(
          eoaAddress: _eoa,
          chainId: 1,
          signatureType: 1,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('type 2 supports Polygon and Amoy', () {
      expect(
        makerAddressForSignatureType(
          eoaAddress: _eoa,
          chainId: 137,
          signatureType: 2,
        ),
        '0x907c14d6cea8e8fc78dd3db152f0a93f43276b4d',
      );
      // Amoy uses the same algorithm — same address.
      expect(
        makerAddressForSignatureType(
          eoaAddress: _eoa,
          chainId: 80002,
          signatureType: 2,
        ),
        '0x907c14d6cea8e8fc78dd3db152f0a93f43276b4d',
      );
    });

    test('type 3 returns the deposit wallet', () {
      expect(
        makerAddressForSignatureType(
          eoaAddress: _eoa,
          chainId: 137,
          signatureType: 3,
        ),
        '0xfd5041047be8c192c725a66228f141196fa3cf9c',
      );
    });

    test('rejects unknown signature types', () {
      expect(
        () => makerAddressForSignatureType(
          eoaAddress: _eoa,
          chainId: 137,
          signatureType: 99,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('predictCreate2Address (low-level)', () {
    test('rejects bad salt size', () {
      expect(
        () => predictCreate2Address(
          deployer: '0x${'a' * 40}',
          salt: Uint8List(31),
          initCodeHash: Uint8List(32),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects bad init-code-hash size', () {
      expect(
        () => predictCreate2Address(
          deployer: '0x${'a' * 40}',
          salt: Uint8List(32),
          initCodeHash: Uint8List(31),
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
