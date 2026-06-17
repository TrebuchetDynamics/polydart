/// Abstract signer surface.
///
/// The SDK never holds a private key. Every cryptographic signature is
/// delegated to a [WalletSigner], which a consumer wires from whatever
/// wallet provider they ship — Reown / WalletConnect on Flutter, a local
/// secp256k1 key for tests / CLI, or a hardware-wallet bridge.
///
/// Implementations are responsible for any envelope transformations the
/// underlying wallet performs (e.g. MetaMask re-hashing typed data).
/// Polydart treats the signer as a black box that turns canonical inputs
/// into 65-byte secp256k1 signatures.
library;

import 'dart:typed_data';

/// Returns a copy of [signature] with an Ethereum recovery id normalized from
/// 0/1 to 27/28 when a wallet provider uses the compact variant.
///
/// Length validation remains the caller's responsibility so existing surfaces
/// can preserve their domain-specific error types. When a 65-byte signature is
/// provided, the recovery id must be one of 0, 1, 27, or 28.
Uint8List normalizeWalletSignature(Uint8List signature) {
  final normalized = Uint8List.fromList(signature);
  if (normalized.length == 65 && (normalized[64] == 0 || normalized[64] == 1)) {
    normalized[64] += 27;
  }
  if (normalized.length == 65 && normalized[64] != 27 && normalized[64] != 28) {
    throw FormatException(
      'wallet signature v must be 0, 1, 27, or 28; got ${normalized[64]}',
    );
  }
  return normalized;
}

abstract interface class WalletSigner {
  /// Owner address controlled by this signer (0x-prefixed hex).
  String get address;

  /// Chain id this signer is bound to. e.g. 137 for Polygon mainnet.
  int get chainId;

  /// Signs a canonical EIP-712 typed-data payload (`eth_signTypedData_v4`).
  ///
  /// [typedData] follows the JSON shape that MetaMask / WalletConnect
  /// expect:
  ///
  /// ```json
  /// {
  ///   "types":       { ... },
  ///   "primaryType": "ClobAuth",
  ///   "domain":      { ... },
  ///   "message":     { ... }
  /// }
  /// ```
  ///
  /// Returns the 65-byte signature `(r ‖ s ‖ v)`. Polydart accepts wallet
  /// providers that return `v` as either 0/1 or 27/28 and normalizes before
  /// packaging signatures.
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData);

  /// Signs the EIP-191 personal_sign envelope for [message]. The wallet
  /// itself adds the `\x19Ethereum Signed Message:\n<len>` prefix.
  Future<Uint8List> personalSign(Uint8List message);
}
