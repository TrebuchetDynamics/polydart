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
    this.orderType = '',
    required this.signatureType,
    required this.createdAt,
    required this.expiration,
    required this.makerAddress,
    this.associateTrades = const <String>[],
  });

  factory OrderRecord.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null) return value.toString();
      }
      return '';
    }

    final at = json['associate_trades'] ?? json['associateTrades'];
    final trades = at is List
        ? at.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    final sigTypeRaw = json['signature_type'] ?? json['signatureType'];
    final sigType = sigTypeRaw is num
        ? sigTypeRaw.toInt()
        : int.tryParse('${sigTypeRaw ?? 0}') ?? 0;
    return OrderRecord(
      id: pick(const ['id']),
      status: pick(const ['status']),
      owner: pick(const ['owner']),
      market: pick(const ['market']),
      assetId: pick(const ['asset_id', 'assetId']),
      side: pick(const ['side']),
      originalSize: pick(const ['original_size', 'originalSize']),
      sizeMatched: pick(const ['size_matched', 'sizeMatched']),
      price: pick(const ['price']),
      outcome: pick(const ['outcome']),
      type: pick(const ['type']),
      orderType: pick(const ['order_type', 'orderType']),
      signatureType: sigType,
      createdAt: pick(const ['created_at', 'createdAt']),
      expiration: pick(const ['expiration']),
      makerAddress: pick(const ['maker_address', 'makerAddress']),
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
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null) return value.toString();
      }
      return '';
    }

    return TradeRecord(
      id: pick(const ['id']),
      status: pick(const ['status']),
      market: pick(const ['market']),
      assetId: pick(const ['asset_id', 'assetId']),
      side: pick(const ['side']),
      price: pick(const ['price']),
      size: pick(const ['size']),
      feeRateBps: pick(const ['fee_rate_bps', 'feeRateBps']),
      outcome: pick(const ['outcome']),
      owner: pick(const ['owner']),
      builder: pick(const ['builder']),
      matchedAmount: pick(const ['matched_amount', 'matchedAmount']),
      transactionHash: pick(const ['transaction_hash', 'transactionHash']),
      createdAt: pick(const ['created_at', 'createdAt']),
      lastUpdated: pick(const ['last_updated', 'lastUpdated']),
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
      key: (json['key'] ?? '').toString(),
      secret: (json['secret'] ?? '').toString(),
      passphrase: (json['passphrase'] ?? '').toString(),
      createdAt: (json['created_at'] ?? json['createdAt'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? json['updatedAt'] ?? '').toString(),
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
      balance: (json['balance'] ?? '').toString(),
      allowances: allowances,
      allowance: (json['allowance'] ?? '').toString(),
    );
  }

  final String balance;
  final Map<String, String> allowances;
  final String allowance;
}
