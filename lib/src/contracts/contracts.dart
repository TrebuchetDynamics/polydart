// ignore_for_file: constant_identifier_names

/// Public Polygon contract registry and read-only deployment checks.
///
/// Mirrors `polygolem/pkg/contracts` for consumers that need contract
/// addresses, adapter routing, or `eth_getCode` readiness checks.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

const int PolygonChainID = 137;
const String PolygonRPC = 'https://polygon-bor-rpc.publicnode.com';

const String DepositWalletFactory =
    '0x00000000000Fb5C9ADea0298D729A0CB3823Cc07';
const String ProxyFactory = '0xaB45c5A4B0c941a2F231C04C3f49182e1A254052';
const String GnosisSafeFactory = '0xaacFeEa03eb1561C4e67d661e40682Bd20E3541b';

const String CTFExchangeV2 = '0xE111180000d2663C0091e4f400237545B87B996B';
const String NegRiskExchangeV2 = '0xe2222d279d744050d28e00520010520000310F59';
const String NegRiskAdapterV2 = '0xd91E80cF2E7be2e162c6513ceD06f1dD0dA35296';

const String CtfCollateralAdapter =
    '0xAdA100Db00Ca00073811820692005400218FcE1f';
const String NegRiskCtfCollateralAdapter =
    '0xadA2005600Dec949baf300f4C6120000bDB6eAab';

const String CollateralOnramp = '0x93070a847efEf7F70739046A929D47a521F5B8ee';
const String CollateralOfframp = '0x2957922Eb93258b93368531d39fAcCA3B4dC5854';
const String PermissionedRamp = '0xebC2459Ec962869ca4c0bd1E06368272732BCb08';

const String PUSD = '0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB';
const String CTF = '0x4D97DCd97eC945f40cF65F87097ACe5EA0476045';
const String USDCE = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';

/// Polymarket Polygon contract registry used by Polygolem.
final class Registry {
  const Registry({
    required this.chainID,
    required this.depositWalletFactory,
    required this.proxyFactory,
    required this.gnosisSafeFactory,
    required this.ctfExchangeV2,
    required this.negRiskExchangeV2,
    required this.negRiskAdapterV2,
    required this.ctfCollateralAdapter,
    required this.negRiskCtfCollateralAdapter,
    required this.collateralOnramp,
    required this.collateralOfframp,
    required this.permissionedRamp,
    required this.pusd,
    required this.ctf,
    required this.usdce,
  });

  final int chainID;
  final String depositWalletFactory;
  final String proxyFactory;
  final String gnosisSafeFactory;
  final String ctfExchangeV2;
  final String negRiskExchangeV2;
  final String negRiskAdapterV2;
  final String ctfCollateralAdapter;
  final String negRiskCtfCollateralAdapter;
  final String collateralOnramp;
  final String collateralOfframp;
  final String permissionedRamp;
  final String pusd;
  final String ctf;
  final String usdce;

  Map<String, Object> toJson() {
    return <String, Object>{
      'chainID': chainID,
      'depositWalletFactory': depositWalletFactory,
      'proxyFactory': proxyFactory,
      'gnosisSafeFactory': gnosisSafeFactory,
      'ctfExchangeV2': ctfExchangeV2,
      'negRiskExchangeV2': negRiskExchangeV2,
      'negRiskAdapterV2': negRiskAdapterV2,
      'ctfCollateralAdapter': ctfCollateralAdapter,
      'negRiskCtfCollateralAdapter': negRiskCtfCollateralAdapter,
      'collateralOnramp': collateralOnramp,
      'collateralOfframp': collateralOfframp,
      'permissionedRamp': permissionedRamp,
      'pusd': pusd,
      'ctf': ctf,
      'usdce': usdce,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Registry &&
            chainID == other.chainID &&
            depositWalletFactory == other.depositWalletFactory &&
            proxyFactory == other.proxyFactory &&
            gnosisSafeFactory == other.gnosisSafeFactory &&
            ctfExchangeV2 == other.ctfExchangeV2 &&
            negRiskExchangeV2 == other.negRiskExchangeV2 &&
            negRiskAdapterV2 == other.negRiskAdapterV2 &&
            ctfCollateralAdapter == other.ctfCollateralAdapter &&
            negRiskCtfCollateralAdapter == other.negRiskCtfCollateralAdapter &&
            collateralOnramp == other.collateralOnramp &&
            collateralOfframp == other.collateralOfframp &&
            permissionedRamp == other.permissionedRamp &&
            pusd == other.pusd &&
            ctf == other.ctf &&
            usdce == other.usdce;
  }

  @override
  int get hashCode => Object.hash(
    chainID,
    depositWalletFactory,
    proxyFactory,
    gnosisSafeFactory,
    ctfExchangeV2,
    negRiskExchangeV2,
    negRiskAdapterV2,
    ctfCollateralAdapter,
    negRiskCtfCollateralAdapter,
    collateralOnramp,
    collateralOfframp,
    permissionedRamp,
    pusd,
    ctf,
    usdce,
  );
}

/// Returns the contract registry for Polymarket on Polygon.
Registry polygonMainnet() {
  return const Registry(
    chainID: PolygonChainID,
    depositWalletFactory: DepositWalletFactory,
    proxyFactory: ProxyFactory,
    gnosisSafeFactory: GnosisSafeFactory,
    ctfExchangeV2: CTFExchangeV2,
    negRiskExchangeV2: NegRiskExchangeV2,
    negRiskAdapterV2: NegRiskAdapterV2,
    ctfCollateralAdapter: CtfCollateralAdapter,
    negRiskCtfCollateralAdapter: NegRiskCtfCollateralAdapter,
    collateralOnramp: CollateralOnramp,
    collateralOfframp: CollateralOfframp,
    permissionedRamp: PermissionedRamp,
    pusd: PUSD,
    ctf: CTF,
    usdce: USDCE,
  );
}

/// Returns the V2 collateral adapter address for a market kind.
String redeemAdapterFor(bool negativeRisk) {
  return negativeRisk ? NegRiskCtfCollateralAdapter : CtfCollateralAdapter;
}

/// Reports whether an address has bytecode on-chain.
final class DeploymentStatus {
  const DeploymentStatus({
    required this.address,
    required this.deployed,
    required this.source,
  });

  final String address;
  final bool deployed;
  final String source;

  Map<String, Object> toJson() {
    return <String, Object>{
      'address': address,
      'deployed': deployed,
      'source': source,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DeploymentStatus &&
            address == other.address &&
            deployed == other.deployed &&
            source == other.source;
  }

  @override
  int get hashCode => Object.hash(address, deployed, source);
}

/// Checks Polygon `eth_getCode` for non-empty bytecode.
Future<DeploymentStatus> contractDeployed(
  String address, {
  String rpcUrl = PolygonRPC,
  http.Client? client,
}) async {
  final normalizedAddress = _requireHexAddress(address);
  final code = await _ethGetCode(
    normalizedAddress,
    rpcUrl: rpcUrl,
    client: client,
  );
  return DeploymentStatus(
    address: normalizedAddress,
    deployed: code.length > 2,
    source: 'polygon_eth_getCode',
  );
}

/// Checks whether the deterministic deposit-wallet address has bytecode.
Future<DeploymentStatus> depositWalletDeployed(
  String depositWallet, {
  String rpcUrl = PolygonRPC,
  http.Client? client,
}) {
  return contractDeployed(depositWallet, rpcUrl: rpcUrl, client: client);
}

Future<String> _ethGetCode(
  String address, {
  required String rpcUrl,
  required http.Client? client,
}) async {
  final effectiveRpcUrl = rpcUrl.trim().isEmpty ? PolygonRPC : rpcUrl.trim();
  final ownsClient = client == null;
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient.post(
      Uri.parse(effectiveRpcUrl),
      headers: const <String, String>{'content-type': 'application/json'},
      body: jsonEncode(<String, Object>{
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'eth_getCode',
        'params': <String>[address, 'latest'],
      }),
    );
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw http.ClientException(
        'eth_getCode HTTP ${response.statusCode}: ${response.body}',
        Uri.parse(effectiveRpcUrl),
      );
    }

    final decoded = _decodeRpcResponse(response.body, 'eth_getCode');
    final error = decoded['error'];
    if (error != null) {
      throw StateError('eth_getCode error: $error');
    }
    final result = decoded['result'];
    if (result is! String) {
      throw const FormatException('eth_getCode result must be a hex string');
    }
    return result.trim();
  } finally {
    if (ownsClient) {
      httpClient.close();
    }
  }
}

Map<String, dynamic> _decodeRpcResponse(String body, String method) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('$method response must be a JSON object');
  }
  return decoded;
}

String _requireHexAddress(String address) {
  final trimmed = address.trim();
  if (!_hexAddressPattern.hasMatch(trimmed)) {
    throw ArgumentError.value(address, 'address', 'invalid Ethereum address');
  }
  return trimmed;
}

final RegExp _hexAddressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');
