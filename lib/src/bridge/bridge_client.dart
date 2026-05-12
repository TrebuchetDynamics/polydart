/// Polymarket Bridge API client.
///
/// Mirrors `pkg/bridge/bridge.go` — read-only access to supported assets,
/// deposit address creation, deposit-status polling, and quotes served from
/// `https://bridge.polymarket.com`. The client is HTTP-only and performs no
/// signing.
library;

import '../transport/http_transport.dart';
import '../transport/transport_config.dart';

/// Public Polymarket Bridge API base URL.
const String defaultBridgeBaseUrl = 'https://bridge.polymarket.com';

final class BridgeClient {
  BridgeClient({HttpTransport? transport})
    : _transport =
          transport ??
          HttpTransport(
            config: const TransportConfig(baseUrl: defaultBridgeBaseUrl),
          );

  final HttpTransport _transport;

  /// Closes the underlying transport.
  void close() => _transport.close();

  /// Requests a per-chain deposit address set for a Polymarket account.
  Future<CreateDepositAddressResponse> createDepositAddress(
    String address,
  ) async {
    final body = await _transport.postJson('/deposit', <String, String>{
      'address': address,
    });
    return CreateDepositAddressResponse.fromJson(body);
  }

  /// Returns the assets the Bridge currently accepts as deposit collateral.
  Future<SupportedAssetsResponse> supportedAssets() async {
    final body = await _transport.getJson('/supported-assets');
    return SupportedAssetsResponse.fromJson(body);
  }

  /// Polls the Bridge for deposit transactions targeting [depositAddress].
  Future<DepositStatusResponse> depositStatus(String depositAddress) async {
    final body = await _transport.getJson('/status/$depositAddress');
    return DepositStatusResponse.fromJson(body);
  }

  /// Prices a deposit move described by [request].
  Future<QuoteResponse> quote(QuoteRequest request) async {
    final body = await _transport.postJson('/quote', request.toJson());
    return QuoteResponse.fromJson(body);
  }
}

final class DepositAddress {
  const DepositAddress({
    required this.evm,
    required this.svm,
    required this.btc,
  });

  factory DepositAddress.fromJson(Map<String, dynamic> json) => DepositAddress(
    evm: _string(json['evm']),
    svm: _string(json['svm']),
    btc: _string(json['btc']),
  );

  final String evm;
  final String svm;
  final String btc;
}

final class CreateDepositAddressResponse {
  const CreateDepositAddressResponse({
    required this.address,
    required this.note,
  });

  factory CreateDepositAddressResponse.fromJson(Map<String, dynamic> json) {
    return CreateDepositAddressResponse(
      address: DepositAddress.fromJson(_map(json['address'])),
      note: _string(json['note']),
    );
  }

  final DepositAddress address;
  final String note;
}

final class TokenInfo {
  const TokenInfo({
    required this.name,
    required this.symbol,
    required this.address,
    required this.decimals,
  });

  factory TokenInfo.fromJson(Map<String, dynamic> json) => TokenInfo(
    name: _string(json['name']),
    symbol: _string(json['symbol']),
    address: _string(json['address']),
    decimals: _int(json['decimals']),
  );

  final String name;
  final String symbol;
  final String address;
  final int decimals;
}

final class SupportedAsset {
  const SupportedAsset({
    required this.chainId,
    required this.chainName,
    required this.token,
    required this.minCheckoutUsd,
  });

  factory SupportedAsset.fromJson(Map<String, dynamic> json) => SupportedAsset(
    chainId: _string(json['chainId']),
    chainName: _string(json['chainName']),
    token: TokenInfo.fromJson(_map(json['token'])),
    minCheckoutUsd: _double(json['minCheckoutUsd']),
  );

  final String chainId;
  final String chainName;
  final TokenInfo token;
  final double minCheckoutUsd;
}

final class SupportedAssetsResponse {
  const SupportedAssetsResponse({required this.supportedAssets});

  factory SupportedAssetsResponse.fromJson(Map<String, dynamic> json) {
    final assets = _list(json['supportedAssets'])
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => SupportedAsset.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
    return SupportedAssetsResponse(supportedAssets: assets);
  }

  final List<SupportedAsset> supportedAssets;
}

final class DepositTransaction {
  const DepositTransaction({
    required this.fromChainId,
    required this.fromTokenAddress,
    required this.fromAmountBaseUnit,
    required this.toChainId,
    required this.toTokenAddress,
    required this.txHash,
    required this.createdTimeMs,
    required this.status,
  });

  factory DepositTransaction.fromJson(Map<String, dynamic> json) {
    return DepositTransaction(
      fromChainId: _string(json['fromChainId']),
      fromTokenAddress: _string(json['fromTokenAddress']),
      fromAmountBaseUnit: _string(json['fromAmountBaseUnit']),
      toChainId: _string(json['toChainId']),
      toTokenAddress: _string(json['toTokenAddress']),
      txHash: _string(json['txHash']),
      createdTimeMs: _int(json['createdTimeMs']),
      status: _string(json['status']),
    );
  }

  final String fromChainId;
  final String fromTokenAddress;
  final String fromAmountBaseUnit;
  final String toChainId;
  final String toTokenAddress;
  final String txHash;
  final int createdTimeMs;
  final String status;
}

final class DepositStatusResponse {
  const DepositStatusResponse({required this.transactions});

  factory DepositStatusResponse.fromJson(Map<String, dynamic> json) {
    final transactions = _list(json['transactions'])
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => DepositTransaction.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
    return DepositStatusResponse(transactions: transactions);
  }

  final List<DepositTransaction> transactions;
}

final class QuoteRequest {
  const QuoteRequest({
    required this.fromAmountBaseUnit,
    required this.fromChainId,
    required this.fromTokenAddress,
    required this.recipientAddress,
    required this.toChainId,
    required this.toTokenAddress,
  });

  final String fromAmountBaseUnit;
  final String fromChainId;
  final String fromTokenAddress;
  final String recipientAddress;
  final String toChainId;
  final String toTokenAddress;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'fromAmountBaseUnit': fromAmountBaseUnit,
    'fromChainId': fromChainId,
    'fromTokenAddress': fromTokenAddress,
    'recipientAddress': recipientAddress,
    'toChainId': toChainId,
    'toTokenAddress': toTokenAddress,
  };
}

final class FeeBreakdown {
  const FeeBreakdown({
    required this.appFeeLabel,
    required this.appFeePercent,
    required this.appFeeUsd,
    required this.fillCostPercent,
    required this.fillCostUsd,
    required this.gasUsd,
    required this.maxSlippage,
    required this.minReceived,
    required this.swapImpact,
    required this.swapImpactUsd,
    required this.totalImpact,
    required this.totalImpactUsd,
  });

  factory FeeBreakdown.fromJson(Map<String, dynamic> json) => FeeBreakdown(
    appFeeLabel: _string(json['appFeeLabel']),
    appFeePercent: _double(json['appFeePercent']),
    appFeeUsd: _double(json['appFeeUsd']),
    fillCostPercent: _double(json['fillCostPercent']),
    fillCostUsd: _double(json['fillCostUsd']),
    gasUsd: _double(json['gasUsd']),
    maxSlippage: _double(json['maxSlippage']),
    minReceived: _double(json['minReceived']),
    swapImpact: _double(json['swapImpact']),
    swapImpactUsd: _double(json['swapImpactUsd']),
    totalImpact: _double(json['totalImpact']),
    totalImpactUsd: _double(json['totalImpactUsd']),
  );

  final String appFeeLabel;
  final double appFeePercent;
  final double appFeeUsd;
  final double fillCostPercent;
  final double fillCostUsd;
  final double gasUsd;
  final double maxSlippage;
  final double minReceived;
  final double swapImpact;
  final double swapImpactUsd;
  final double totalImpact;
  final double totalImpactUsd;
}

final class QuoteResponse {
  const QuoteResponse({
    required this.estCheckoutTimeMs,
    required this.estFeeBreakdown,
    required this.estInputUsd,
    required this.estOutputUsd,
    required this.estToTokenBaseUnit,
    required this.quoteId,
  });

  factory QuoteResponse.fromJson(Map<String, dynamic> json) => QuoteResponse(
    estCheckoutTimeMs: _int(json['estCheckoutTimeMs']),
    estFeeBreakdown: FeeBreakdown.fromJson(_map(json['estFeeBreakdown'])),
    estInputUsd: _double(json['estInputUsd']),
    estOutputUsd: _double(json['estOutputUsd']),
    estToTokenBaseUnit: _string(json['estToTokenBaseUnit']),
    quoteId: _string(json['quoteId']),
  );

  final int estCheckoutTimeMs;
  final FeeBreakdown estFeeBreakdown;
  final double estInputUsd;
  final double estOutputUsd;
  final String estToTokenBaseUnit;
  final String quoteId;
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

List<dynamic> _list(Object? value) => value is List ? value : const <dynamic>[];

String _string(Object? value) => value?.toString() ?? '';

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_string(value)) ?? 0;
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_string(value)) ?? 0;
}
