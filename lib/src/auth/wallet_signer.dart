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
  /// Returns the 65-byte signature `(r ‖ s ‖ v)` with `v` normalized to
  /// 27 or 28.
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData);

  /// Signs the EIP-191 personal_sign envelope for [message]. The wallet
  /// itself adds the `\x19Ethereum Signed Message:\n<len>` prefix.
  Future<Uint8List> personalSign(Uint8List message);
}
