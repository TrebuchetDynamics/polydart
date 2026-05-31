/// Types returned by the authenticated CLOB read endpoints.
///
/// Mirrors the order/trade record + balance/allowance shapes in
/// `internal/clob/orders.go` and `internal/clob/client.go`.
library;

import 'package:meta/meta.dart';

import 'shared/clob_json.dart';

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
    this.orderType = '',
    required this.signatureType,
    required this.createdAt,
    required this.expiration,
    required this.makerAddress,
    this.associateTrades = const <String>[],
  });

  factory OrderRecord.fromJson(Map<String, dynamic> json) {
    final at = json['associate_trades'] ?? json['associateTrades'];
    final trades = at is List
        ? at.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    final sigTypeRaw = json['signature_type'] ?? json['signatureType'];
    final sigType = clobInt(sigTypeRaw);
    return OrderRecord(
      id: clobStringOf(json, const ['id']),
      status: clobStringOf(json, const ['status']),
      owner: clobStringOf(json, const ['owner']),
      market: clobStringOf(json, const ['market']),
      assetId: clobStringOf(json, const ['asset_id', 'assetId']),
      side: clobStringOf(json, const ['side']),
      originalSize: clobStringOf(json, const ['original_size', 'originalSize']),
      sizeMatched: clobStringOf(json, const ['size_matched', 'sizeMatched']),
      price: clobStringOf(json, const ['price']),
      outcome: clobStringOf(json, const ['outcome']),
      type: clobStringOf(json, const ['type']),
      orderType: clobStringOf(json, const ['order_type', 'orderType']),
      signatureType: sigType,
      createdAt: clobStringOf(json, const ['created_at', 'createdAt']),
      expiration: clobStringOf(json, const ['expiration']),
      makerAddress: clobStringOf(json, const ['maker_address', 'makerAddress']),
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
  final String orderType;
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
    return TradeRecord(
      id: clobStringOf(json, const ['id']),
      status: clobStringOf(json, const ['status']),
      market: clobStringOf(json, const ['market']),
      assetId: clobStringOf(json, const ['asset_id', 'assetId']),
      side: clobStringOf(json, const ['side']),
      price: clobStringOf(json, const ['price']),
      size: clobStringOf(json, const ['size']),
      feeRateBps: clobStringOf(json, const ['fee_rate_bps', 'feeRateBps']),
      outcome: clobStringOf(json, const ['outcome']),
      owner: clobStringOf(json, const ['owner']),
      builder: clobStringOf(json, const ['builder']),
      matchedAmount: clobStringOf(json, const [
        'matched_amount',
        'matchedAmount',
      ]),
      transactionHash: clobStringOf(json, const [
        'transaction_hash',
        'transactionHash',
      ]),
      createdAt: clobStringOf(json, const ['created_at', 'createdAt']),
      lastUpdated: clobStringOf(json, const ['last_updated', 'lastUpdated']),
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
    this.signatureType = 3,
  });

  /// Concrete token contract for COLLATERAL queries (rarely needed).
  final String asset;

  /// `COLLATERAL` for pUSD/USDC.e or `CONDITIONAL` for outcome tokens.
  final String assetType;

  /// Token id when [assetType] is `CONDITIONAL`.
  final String tokenId;

  /// Retained for source compatibility. Polymarket V2 balance-allowance reads
  /// are pinned to `3` (`POLY_1271` deposit wallet), matching Polygolem.
  final int signatureType;

  Map<String, String> toQuery() {
    final out = <String, String>{};
    if (asset.isNotEmpty) out['asset'] = asset;
    if (assetType.isNotEmpty) out['asset_type'] = assetType.toUpperCase();
    if (tokenId.isNotEmpty) out['token_id'] = tokenId;
    out['signature_type'] = '3';
    return out;
  }
}

/// One row from `GET /auth/builder-api-keys`. Loosely typed upstream — every
/// field except `key` is best-effort.
@immutable
final class BuilderFeeKeyRecord {
  const BuilderFeeKeyRecord({
    required this.key,
    this.secret = '',
    this.passphrase = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory BuilderFeeKeyRecord.fromJson(Map<String, dynamic> json) {
    return BuilderFeeKeyRecord(
      key: clobStringOf(json, const ['key']),
      secret: clobStringOf(json, const ['secret']),
      passphrase: clobStringOf(json, const ['passphrase']),
      createdAt: clobStringOf(json, const ['created_at', 'createdAt']),
      updatedAt: clobStringOf(json, const ['updated_at', 'updatedAt']),
    );
  }

  final String key;
  final String secret;
  final String passphrase;
  final String createdAt;
  final String updatedAt;
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
      balance: clobStringOf(json, const ['balance']),
      allowances: allowances,
      allowance: clobStringOf(json, const ['allowance']),
    );
  }

  final String balance;
  final Map<String, String> allowances;
  final String allowance;
}
