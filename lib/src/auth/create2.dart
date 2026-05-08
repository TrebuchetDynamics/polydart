/// CREATE2 wallet derivation.
///
/// Mirrors the relevant pieces of `internal/auth/signer.go`. Pure compute,
/// no I/O — these helpers run on every Flutter target.
///
/// Polymarket's CLOB selects a maker / funder address based on the
/// configured signature type. We expose:
///   * EOA (type 0)            — return the signer address
///   * Proxy (type 1)          — Magic / email account proxy wallet
///   * Gnosis Safe (type 2)    — browser-account Safe wallet
///   * Deposit wallet (type 3) — gas-abstracted relayer wallet
///
/// Deposit wallet derivation reproduces the ERC-1967 init code construction
/// from `polygolem.depositWalletInitCode`. Cross-validated against polygolem
/// for EOA `0x2c7536E3605D9C16a7a3D7b1898e529396a65c23` — see
/// `test/auth/create2_test.dart`.
library;

import 'dart:typed_data';

import '../errors/errors.dart';
import 'eth_hex.dart';

/// Polygon-mainnet contract addresses Polymarket deployed.
class PolymarketAddresses {
  PolymarketAddresses._();

  static const String proxyFactory =
      '0xab45c5a4b0c941a2f231c04c3f49182e1a254052';
  static const String safeFactory =
      '0xaacfeea03eb1561c4e67d661e40682bd20e3541b';
  static const String depositWalletFactory =
      '0x00000000000fb5c9adea0298d729a0cb3823cc07';
  static const String depositWalletImpl =
      '0x58ca52ebe0dadfdf531cde7062e76746de4db1eb';

  static const String proxyInitCodeHash =
      '0xd21df8dc65880a8606f09fe0ce3df9b8869287ab0b058be05aa9e8af6330a00b';
  static const String safeInitCodeHash =
      '0x2bce2127ff07fb632d16c8347c4ebf501f4841168bed00d9e6ef715ddb6fcecf';
}

/// Computes a CREATE2 address per EIP-1014:
///
/// ```
/// keccak256(0xff ‖ deployer ‖ salt ‖ initCodeHash)[12..32]
/// ```
String predictCreate2Address({
  required String deployer,
  required Uint8List salt,
  required Uint8List initCodeHash,
}) {
  if (salt.length != 32) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'salt must be 32 bytes (got ${salt.length})',
    );
  }
  if (initCodeHash.length != 32) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'initCodeHash must be 32 bytes (got ${initCodeHash.length})',
    );
  }
  final factoryBytes = hexToBytes(deployer);
  if (factoryBytes.length != 20) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message:
          'deployer must be a 20-byte address (got ${factoryBytes.length})',
    );
  }
  final digest = keccak256Bytes(
    concatBytes([
      Uint8List.fromList(<int>[0xff]),
      factoryBytes,
      salt,
      initCodeHash,
    ]),
  );
  return '0x${bytesToHex(digest.sublist(12))}';
}

/// Returns the Proxy wallet (signature type 1) for [eoaAddress] on Polygon.
String deriveProxyWallet(String eoaAddress) {
  final eoaBytes = hexToBytes(_strip0x(eoaAddress));
  if (eoaBytes.length != 20) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'EOA must be 20 bytes (got ${eoaBytes.length})',
    );
  }
  final salt = keccak256Bytes(eoaBytes);
  final initHash = hexToBytes(PolymarketAddresses.proxyInitCodeHash);
  return predictCreate2Address(
    deployer: PolymarketAddresses.proxyFactory,
    salt: salt,
    initCodeHash: initHash,
  );
}

/// Returns the Gnosis Safe wallet (signature type 2) for [eoaAddress].
String deriveSafeWallet(String eoaAddress) {
  final eoaBytes = hexToBytes(_strip0x(eoaAddress));
  if (eoaBytes.length != 20) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'EOA must be 20 bytes (got ${eoaBytes.length})',
    );
  }
  final padded = leftPadBytes(eoaBytes, length: 32);
  final salt = keccak256Bytes(padded);
  final initHash = hexToBytes(PolymarketAddresses.safeInitCodeHash);
  return predictCreate2Address(
    deployer: PolymarketAddresses.safeFactory,
    salt: salt,
    initCodeHash: initHash,
  );
}

/// Returns the deposit wallet (signature type 3) for [eoaAddress].
///
/// Reproduces the ERC-1967 proxy bytecode construction from
/// `polygolem/internal/auth/signer.go:depositWalletInitCode`.
String deriveDepositWallet(String eoaAddress) {
  final eoaBytes = hexToBytes(_strip0x(eoaAddress));
  if (eoaBytes.length != 20) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'EOA must be 20 bytes (got ${eoaBytes.length})',
    );
  }
  final factoryBytes = hexToBytes(PolymarketAddresses.depositWalletFactory);
  final implBytes = hexToBytes(PolymarketAddresses.depositWalletImpl);

  // args = leftPad32(factory) ‖ leftPad32(eoa)
  final args = concatBytes([
    leftPadBytes(factoryBytes, length: 32),
    leftPadBytes(eoaBytes, length: 32),
  ]);

  final salt = keccak256Bytes(args);
  final initCode = _depositWalletInitCode(implBytes, args);
  final initHash = keccak256Bytes(initCode);
  return predictCreate2Address(
    deployer: PolymarketAddresses.depositWalletFactory,
    salt: salt,
    initCodeHash: initHash,
  );
}

/// Returns the maker/funder address for a given [signatureType].
///
/// Throws [ValidationException] for unknown types or unsupported chain
/// combinations.
String makerAddressForSignatureType({
  required String eoaAddress,
  required int chainId,
  required int signatureType,
}) {
  switch (signatureType) {
    case 0:
      return normalizeAddress(eoaAddress);
    case 1:
      if (chainId != 137) {
        throw const ValidationException(
          code: ErrorCode.invalidValue,
          message:
              'proxy wallet derivation only supports Polygon (chainId=137)',
        );
      }
      return deriveProxyWallet(eoaAddress);
    case 2:
      if (chainId != 137 && chainId != 80002) {
        throw const ValidationException(
          code: ErrorCode.invalidValue,
          message: 'safe derivation supports Polygon (137) or Amoy (80002)',
        );
      }
      return deriveSafeWallet(eoaAddress);
    case 3:
      if (chainId != 137) {
        throw const ValidationException(
          code: ErrorCode.invalidValue,
          message:
              'deposit wallet derivation only supports Polygon (chainId=137)',
        );
      }
      return deriveDepositWallet(eoaAddress);
  }
  throw ValidationException(
    code: ErrorCode.invalidValue,
    message: 'unsupported signature type: $signatureType',
  );
}

/// Builds the ERC-1967 proxy init code Polymarket's deposit wallet uses.
///
/// Layout (160 bytes for a standard 64-byte args payload):
///   [0..10)   ERC-1967 prefix + (argsLen << 56) — 10 bytes big-endian
///   [10..30)  implementation address          — 20 bytes
///   [30..32)  push (0x60 0x09)                — 2 bytes
///   [32..64)  c2 constant                     — 32 bytes
///   [64..96)  c1 constant                     — 32 bytes
///   [96..160) packed args (factory ‖ walletId) — 64 bytes
Uint8List _depositWalletInitCode(Uint8List impl, Uint8List args) {
  final erc1967 = BigInt.parse('61003D3D8160233D3973', radix: 16);
  final argsLen = BigInt.from(args.length) << 56;
  final combined = erc1967 + argsLen;
  final combinedBytes = _bigIntBigEndian(combined, 10);

  final c2 = hexToBytes(
    '0x5155f3363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076',
  );
  final c1 = hexToBytes(
    '0xcc3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f3',
  );
  final six009 = Uint8List.fromList(<int>[0x60, 0x09]);

  return concatBytes([combinedBytes, impl, six009, c2, c1, args]);
}

Uint8List _bigIntBigEndian(BigInt value, int byteLen) {
  final out = Uint8List(byteLen);
  var n = value;
  for (var i = byteLen - 1; i >= 0; i--) {
    out[i] = (n & BigInt.from(0xff)).toInt();
    n = n >> 8;
  }
  return out;
}

String _strip0x(String s) {
  if (s.startsWith('0x') || s.startsWith('0X')) return s.substring(2);
  return s;
}
