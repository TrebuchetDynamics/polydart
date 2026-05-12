/// Plain-Dart WalletSigner adapter pattern for Flutter wallet SDKs.
///
/// This is a compiling skeleton, not a complete wallet integration. Wire
/// [WalletRpcRequest] to Reown, WalletConnect, an embedded wallet, a hardware
/// wallet bridge, or a platform channel in your Flutter app.
///
/// It does not contain raw private keys and does not submit orders or funding
/// transactions.
///
/// Analyze: `dart analyze example/flutter_wallet_signer.dart`
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:polydart/polydart.dart';

typedef WalletRpcRequest =
    Future<String> Function(String method, List<Object?> params);

final class FlutterWalletSignerAdapter implements WalletSigner {
  FlutterWalletSignerAdapter({
    required this.address,
    required this.chainId,
    required WalletRpcRequest walletRequest,
  }) : _walletRequest = walletRequest;

  @override
  final String address;

  @override
  final int chainId;

  final WalletRpcRequest _walletRequest;

  @override
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData) async {
    final signature = await _walletRequest('eth_signTypedData_v4', <Object?>[
      address,
      jsonEncode(typedData),
    ]);
    return signatureHexToBytes(signature);
  }

  @override
  Future<Uint8List> personalSign(Uint8List message) async {
    final signature = await _walletRequest('personal_sign', <Object?>[
      bytesToHex0x(message),
      address,
    ]);
    return signatureHexToBytes(signature);
  }
}

Uint8List signatureHexToBytes(String signature) {
  final bytes = hexToBytes(signature);
  if (bytes.length != 65) {
    throw FormatException(
      'wallet signature must be 65 bytes, got ${bytes.length}',
    );
  }

  final v = bytes[64];
  if (v == 0 || v == 1) {
    bytes[64] = v + 27;
  }
  if (bytes[64] != 27 && bytes[64] != 28) {
    throw FormatException('wallet signature v must be 27 or 28, got $v');
  }

  return bytes;
}

FlutterWalletSignerAdapter buildFlutterWalletSigner({
  required String address,
  required int chainId,
  required WalletRpcRequest walletRequest,
}) {
  if (chainId != polymarketChainId) {
    throw ArgumentError.value(
      chainId,
      'chainId',
      'Polymarket signing expects Polygon mainnet',
    );
  }

  return FlutterWalletSignerAdapter(
    address: address,
    chainId: chainId,
    walletRequest: walletRequest,
  );
}
