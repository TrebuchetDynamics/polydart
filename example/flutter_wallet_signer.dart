/// Plain-Dart WalletSigner adapter pattern for Flutter wallet SDKs.
///
/// This is a compiling skeleton, not a complete wallet integration. Wire
/// [WalletRpcRequest] to Reown, WalletConnect, an embedded wallet, a hardware
/// wallet bridge, or a platform channel in your Flutter app. Reown and
/// WalletConnect session chains can be passed as EIP-155 CAIP-2 strings such as
/// `eip155:137`.
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
    _ensurePolymarketChain(chainId);
    final signature = await _walletRequest('eth_signTypedData_v4', <Object?>[
      address,
      jsonEncode(typedData),
    ]);
    return signatureHexToBytes(signature);
  }

  @override
  Future<Uint8List> personalSign(Uint8List message) async {
    _ensurePolymarketChain(chainId);
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
  _ensurePolymarketChain(chainId);

  return FlutterWalletSignerAdapter(
    address: address,
    chainId: chainId,
    walletRequest: walletRequest,
  );
}

FlutterWalletSignerAdapter buildFlutterWalletSignerFromEip155Chain({
  required String address,
  required String eip155ChainId,
  required WalletRpcRequest walletRequest,
}) {
  return buildFlutterWalletSigner(
    address: address,
    chainId: parseEip155ChainId(eip155ChainId),
    walletRequest: walletRequest,
  );
}

int parseEip155ChainId(String eip155ChainId) {
  final match = RegExp(r'^eip155:(\d+)$').firstMatch(eip155ChainId);
  if (match == null) {
    throw FormatException(
      'Reown/WalletConnect chain id must use EIP-155 CAIP-2 format like eip155:137',
      eip155ChainId,
    );
  }
  return int.parse(match.group(1)!);
}

void _ensurePolymarketChain(int chainId) {
  if (chainId != polymarketChainId) {
    throw ArgumentError.value(
      chainId,
      'chainId',
      'Polymarket signing expects Polygon mainnet',
    );
  }
}
