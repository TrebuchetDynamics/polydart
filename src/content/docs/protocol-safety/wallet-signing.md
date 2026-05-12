---
title: Wallet-Mediated Signing
description: Understand the WalletSigner boundary and how Polydart avoids raw private keys.
sidebar:
  order: 1
---

Polydart treats wallets as external signers. The SDK builds canonical messages and typed-data payloads, then delegates every signature to a caller-provided `WalletSigner`.

The SDK does not require raw private keys. Flutter apps should connect `WalletSigner` to their wallet provider, session manager, hardware wallet bridge, or test signer.

## WalletSigner Contract

`WalletSigner` is the only signing interface the public SDK expects.

```dart
import 'dart:typed_data';

import 'package:polydart/polydart.dart';

final class AppWalletSigner implements WalletSigner {
  AppWalletSigner({
    required this.address,
    required this.chainId,
    required this.wallet,
  });

  @override
  final String address;

  @override
  final int chainId;

  final AppWalletBridge wallet;

  @override
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData) {
    return wallet.signTypedDataV4(typedData);
  }

  @override
  Future<Uint8List> personalSign(Uint8List message) {
    return wallet.personalSign(message);
  }
}

abstract interface class AppWalletBridge {
  Future<Uint8List> signTypedDataV4(Map<String, dynamic> typedData);
  Future<Uint8List> personalSign(Uint8List message);
}
```

Keep provider-specific account selection, session refresh, chain switching, and user prompts inside the bridge. Polydart only sees the public address, chain id, and signature bytes.

## Build Typed Data Separately

Typed-data builders are pure and side-effect free. They are useful for previewing or logging the exact payload that will be shown to the wallet.

```dart
import 'package:polydart/polydart.dart';

Map<String, dynamic> clobAuthPreview(WalletSigner signer) {
  final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  return buildClobAuthTypedData(
    address: signer.address,
    chainId: signer.chainId,
    timestamp: timestamp,
    nonce: 0,
    message: clobAuthDefaultMessage,
  );
}
```

## Sign Through The Wallet

Signing helpers call `WalletSigner` and validate the returned signature shape.

```dart
import 'package:polydart/polydart.dart';

Future<String> signEnableTradingControlMessage(WalletSigner signer) {
  final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  return signEnableTradingClobAuthTypedData(
    signer: signer,
    timestamp: timestamp,
    nonce: 0,
  );
}
```

The returned value is a hex signature. It is not a private key, API key, or CLOB credential.

## Browser Cookie Boundary

`SIWESession.login()` and `mintV2APIKey()` use HTTP cookies. They are suitable
for Dart VM, mobile, desktop, tests, and backend/proxy code that can read
`Set-Cookie` and send `Cookie` headers. Flutter Web code cannot rely on that
same API shape because browsers hide `Set-Cookie` from JavaScript and block
manual `Cookie` headers.

For Flutter Web, keep wallet signature prompts in the app and put any
cookie-backed SIWE or relayer-key minting behind a backend/proxy boundary unless
you have a browser-native credential flow with the upstream service.

## Address And Chain Checks

Signing helpers that target Polymarket require Polygon mainnet (`chainId == 137`). If the wallet is on another chain, the helper throws `ValidationException` before requesting a signature.

```dart
if (signer.chainId != polygonChainId) {
  throw const ValidationException(
    code: ErrorCode.invalidValue,
    message: 'Switch wallet to Polygon before signing Polymarket payloads.',
    field: 'chainId',
  );
}
```
