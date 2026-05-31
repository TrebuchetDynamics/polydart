import 'dart:typed_data';

import 'package:polydart/src/auth/wallet_signer.dart';

import 'auth_test_fixtures.dart';

class FakeWalletSigner implements WalletSigner {
  FakeWalletSigner({
    Uint8List? signature,
    this.chainId = 137,
    this.address = canonicalEoaAddress,
  }) : signature = signature ?? Uint8List(65);

  final Uint8List signature;

  @override
  final int chainId;

  @override
  final String address;

  Map<String, dynamic>? lastTypedData;
  Uint8List? lastPersonalSignMessage;
  int signTypedDataCalls = 0;
  int personalSignCalls = 0;

  @override
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData) async {
    signTypedDataCalls++;
    lastTypedData = typedData;
    return signature;
  }

  @override
  Future<Uint8List> personalSign(Uint8List message) async {
    personalSignCalls++;
    lastPersonalSignMessage = message;
    return signature;
  }
}
