/// Types returned by the authenticated CLOB read endpoints.
///
/// Mirrors the order/trade record + balance/allowance shapes in
/// `internal/clob/orders.go` and `internal/clob/client.go`.
library;

import 'package:meta/meta.dart';

/// One row of `GET /data/orders` (or `GET /data/order/:id`).
@immutable
final class OrderRecord {
  const OrderRecord({
    required this.id,
    required this.status,
    required this.owner,
    required this.market,
    required this.assetId,
    required this.side,
    required this.originalSize,
    required this.sizeMatched,
    required this.price,
    required this.outcome,
    required this.type,
    required this.signatureType,
    required this.createdAt,
    required this.expiration,
    required this.makerAddress,
    this.associateTrades = const <String>[],
  });

  factory OrderRecord.fromJson(Map<String, dynamic> json) {
    String pick(String k) => (json[k] ?? '').toString();
    final at = json['associate_trades'];
    final trades = at is List
        ? at.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    final sigTypeRaw = json['signature_type'];
    final sigType = sigTypeRaw is num
        ? sigTypeRaw.toInt()
        : int.tryParse('${sigTypeRaw ?? 0}') ?? 0;
    return OrderRecord(
      id: pick('id'),
      status: pick('status'),
      owner: pick('owner'),
      market: pick('market'),
      assetId: pick('asset_id'),
      side: pick('side'),
      originalSize: pick('original_size'),
      sizeMatched: pick('size_matched'),
      price: pick('price'),
      outcome: pick('outcome'),
      type: pick('type'),
      signatureType: sigType,
      createdAt: pick('created_at'),
      expiration: pick('expiration'),
      makerAddress: pick('maker_address'),
      associateTrades: trades,
    );
  }

  final String id;
  final String status;
  final String owner;
  final String market;
  final String assetId;
  final String side;
  final String originalSize;
  final String sizeMatched;
  final String price;
  final String outcome;
  final String type;
  final int signatureType;
  final String createdAt;
  final String expiration;
  final String makerAddress;
  final List<String> associateTrades;
}

/// One row of `GET /data/trades`.
@immutable
final class TradeRecord {
  const TradeRecord({
    required this.id,
    required this.status,
    required this.market,
    required this.assetId,
    required this.side,
    required this.price,
    required this.size,
    required this.feeRateBps,
    required this.outcome,
    required this.owner,
    required this.builder,
    required this.matchedAmount,
    required this.transactionHash,
    required this.createdAt,
    required this.lastUpdated,
  });

  factory TradeRecord.fromJson(Map<String, dynamic> json) {
    String pick(String k) => (json[k] ?? '').toString();
    return TradeRecord(
      id: pick('id'),
      status: pick('status'),
      market: pick('market'),
      assetId: pick('asset_id'),
      side: pick('side'),
      price: pick('price'),
      size: pick('size'),
      feeRateBps: pick('fee_rate_bps'),
      outcome: pick('outcome'),
      owner: pick('owner'),
      builder: pick('builder'),
      matchedAmount: pick('matched_amount'),
      transactionHash: pick('transaction_hash'),
      createdAt: pick('created_at'),
      lastUpdated: pick('last_updated'),
    );
  }

  final String id;
  final String status;
  final String market;
  final String assetId;
  final String side;
  final String price;
  final String size;
  final String feeRateBps;
  final String outcome;
  final String owner;
  final String builder;
  final String matchedAmount;
  final String transactionHash;
  final String createdAt;
  final String lastUpdated;
}

/// Query parameters for `GET /balance-allowance`.
@immutable
final class BalanceAllowanceParams {
  const BalanceAllowanceParams({
    this.asset = '',
    this.assetType = '',
    this.tokenId = '',
    this.signatureType = 0,
  });

  /// Concrete token contract for COLLATERAL queries (rarely needed).
  final String asset;

  /// `COLLATERAL` for pUSD/USDC.e or `CONDITIONAL` for outcome tokens.
  final String assetType;

  /// Token id when [assetType] is `CONDITIONAL`.
  final String tokenId;

  /// Polymarket signature scheme (`0` EOA, `1` POLY_PROXY, `2` POLY_GNOSIS_SAFE,
  /// `3` POLY_1271 deposit wallet).
  final int signatureType;

  Map<String, String> toQuery() {
    final out = <String, String>{};
    if (asset.isNotEmpty) out['asset'] = asset;
    if (assetType.isNotEmpty) out['asset_type'] = assetType;
    if (tokenId.isNotEmpty) out['token_id'] = tokenId;
    out['signature_type'] = signatureType.toString();
    return out;
  }
}

/// Authenticated CLOB collateral or token balance + allowances.
@immutable
final class BalanceAllowanceResponse {
  const BalanceAllowanceResponse({
    this.balance = '',
    this.allowances = const <String, String>{},
    this.allowance = '',
  });

  factory BalanceAllowanceResponse.fromJson(Map<String, dynamic> json) {
    final allowancesRaw = json['allowances'];
    final allowances = <String, String>{};
    if (allowancesRaw is Map) {
      allowancesRaw.forEach((k, v) => allowances[k.toString()] = v.toString());
    }
    return BalanceAllowanceResponse(
      balance: (json['balance'] ?? '').toString(),
      allowances: allowances,
      allowance: (json['allowance'] ?? '').toString(),
    );
  }

  final String balance;
  final Map<String, String> allowances;
  final String allowance;
}
