/// Order intent and lifecycle types.
///
/// Mirrors `internal/orders/orders.go`. [OrderIntent] is what a caller
/// builds via [OrderBuilder] — high-level, validated, but not yet signed.
/// [SignedOrder] is the wire payload after signing. [LifecycleState]
/// tracks status returned by the CLOB and the relayer.
library;

import 'package:meta/meta.dart';

import '../errors/errors.dart';
import '../types/clob.dart';
import '../types/decimal.dart';
import '../types/enums.dart';

/// Lifecycle states a CLOB order can be in. Mirrors the `State*` constants
/// in polygolem.
enum LifecycleState {
  created,
  accepted,
  live,
  partial,
  matched,
  canceled,
  rejected,
  failed,
  mined,
  confirmed;

  static LifecycleState parse(String raw) {
    final v = raw.trim().toLowerCase();
    for (final s in LifecycleState.values) {
      if (s.name == v) return s;
    }
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'invalid lifecycle state: $raw',
    );
  }
}

/// User-side order intent. Build with [OrderBuilder].
@immutable
final class OrderIntent {
  const OrderIntent({
    required this.tokenId,
    required this.side,
    required this.price,
    required this.size,
    this.amountUsdc,
    this.orderType = OrderType.gtc,
    this.signatureType = SignatureType.eoa,
    required this.tickSize,
    this.negRisk = false,
    this.feeRateBps = 0,
    this.nonce = 0,
    this.expiration = 0,
    this.funder = '',
    this.postOnly = false,
  });

  final String tokenId;
  final Side side;
  final Decimal price;
  final Decimal size;
  final Decimal? amountUsdc;
  final OrderType orderType;
  final SignatureType signatureType;
  final TickSize tickSize;
  final bool negRisk;
  final int feeRateBps;
  final int nonce;

  /// Unix seconds. `0` means GTC (no expiration).
  final int expiration;

  /// Funder address (e.g. deposit wallet for sigType=3). Empty for EOA.
  final String funder;

  final bool postOnly;

  /// Validates the intent. Throws [ValidationException] on bad input.
  void validate() {
    if (tokenId.isEmpty) {
      throw const ValidationException(
        code: ErrorCode.missingField,
        message: 'token_id is required',
        field: 'token_id',
      );
    }
    final hasPrice = _hasNonZeroDecimal(price);
    final hasSize = _hasNonZeroDecimal(size);
    final hasAmountUsdc = amountUsdc != null && _hasNonZeroDecimal(amountUsdc!);
    if (hasPrice) _validatePositiveDecimal(price, 'price');
    if (hasSize) _validatePositiveDecimal(size, 'size');
    if (hasAmountUsdc) _validatePositiveDecimal(amountUsdc!, 'amount_usdc');
    if (!hasPrice && !hasAmountUsdc) {
      throw const ValidationException(
        code: ErrorCode.missingField,
        message: 'price or amount_usdc required',
      );
    }
    if (!hasSize && !hasAmountUsdc) {
      throw const ValidationException(
        code: ErrorCode.missingField,
        message: 'size or amount_usdc required',
      );
    }
    _validatePositiveTickSize(tickSize.tickSize);
    if (feeRateBps < 0) {
      throw const ValidationException(
        code: ErrorCode.invalidValue,
        message: 'fee_rate_bps must be non-negative',
        field: 'fee_rate_bps',
      );
    }
  }
}

/// Wire payload for a signed order. Mirrors `OrderData` from polygolem.
@immutable
final class SignedOrder {
  const SignedOrder({
    required this.salt,
    required this.maker,
    required this.signer,
    required this.taker,
    required this.tokenId,
    required this.makerAmount,
    required this.takerAmount,
    required this.side,
    required this.signatureType,
    required this.expiration,
    required this.nonce,
    required this.feeRateBps,
    required this.signature,
    this.timestamp,
    this.metadata,
    this.builder,
  });

  /// Salt uniquely identifying this order; stringified uint256.
  final String salt;

  final String maker;
  final String signer;
  final String taker;

  /// Numeric token id as a string (uint256).
  final String tokenId;

  /// Maker amount in 6-decimal USDC fixed-point (uint256 string).
  final String makerAmount;

  /// Taker amount in 6-decimal USDC fixed-point (uint256 string).
  final String takerAmount;

  final Side side;
  final SignatureType signatureType;
  final int expiration;
  final int nonce;
  final int feeRateBps;

  /// 0x-prefixed hex signature.
  final String signature;

  // V2-only fields. Null for V1.
  final int? timestamp;
  final String? metadata;
  final String? builder;

  /// Wire JSON shape the CLOB expects on `POST /order`.
  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{
      'salt': salt,
      'maker': maker,
      'signer': signer,
      'taker': taker,
      'tokenId': tokenId,
      'makerAmount': makerAmount,
      'takerAmount': takerAmount,
      'side': side.label,
      'signatureType': signatureType.code,
      'expiration': expiration.toString(),
      'nonce': nonce.toString(),
      'feeRateBps': feeRateBps.toString(),
      'signature': signature,
    };
    if (timestamp != null) out['timestamp'] = timestamp!.toString();
    if (metadata != null) out['metadata'] = metadata;
    if (builder != null) out['builder'] = builder;
    return out;
  }
}

/// CLOB response shape for `POST /order`. Mirrors `OrderResponse`.
@immutable
final class OrderResponse {
  const OrderResponse({
    required this.success,
    required this.orderId,
    required this.status,
    this.errorMessage,
    this.transactionHash,
    this.makingAmount,
    this.takingAmount,
    this.transactionHashes = const <String>[],
    this.tradeIds = const <String>[],
  });

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    final singleTransactionHash =
        (json['transaction_hash'] ?? json['transactionHash'])?.toString();
    return OrderResponse(
      success: json['success'] == true,
      orderId:
          (json['orderID'] ?? json['orderId'] ?? json['order_id'])
              ?.toString() ??
          '',
      status: json['status']?.toString() ?? '',
      errorMessage: (json['errorMsg'] ?? json['error_msg'])?.toString(),
      transactionHash: singleTransactionHash,
      makingAmount: (json['makingAmount'] ?? json['making_amount'])?.toString(),
      takingAmount: (json['takingAmount'] ?? json['taking_amount'])?.toString(),
      transactionHashes: _stringList(
        json['transactionsHashes'] ??
            json['transactionHashes'] ??
            json['transaction_hashes'] ??
            singleTransactionHash,
      ),
      tradeIds: _stringList(
        json['tradeIDs'] ?? json['tradeIds'] ?? json['trade_ids'],
      ),
    );
  }

  final bool success;
  final String orderId;
  final String status;
  final String? errorMessage;
  final String? transactionHash;
  final String? makingAmount;
  final String? takingAmount;
  final List<String> transactionHashes;
  final List<String> tradeIds;
}

bool _hasNonZeroDecimal(Decimal value) => !value.isZero;

void _validatePositiveDecimal(Decimal value, String field) {
  final numeric = value.toDouble();
  if (!numeric.isFinite || numeric <= 0) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: '$field must be positive',
      field: field,
    );
  }
}

void _validatePositiveTickSize(String tick) {
  final value = double.tryParse(tick);
  if (value == null || !value.isFinite || value <= 0) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'valid tick_size required',
      field: 'tick_size',
    );
  }
}

List<String> _stringList(Object? raw) {
  if (raw == null) return const <String>[];
  if (raw is List) {
    return raw.map((e) => e.toString()).toList(growable: false);
  }
  final value = raw.toString();
  if (value.isEmpty) return const <String>[];
  return <String>[value];
}
