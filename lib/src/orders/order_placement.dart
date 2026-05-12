/// High-level limit / market order placement.
///
/// Mirrors the convenience surface of `internal/clob/orders.go`'s
/// `CreateLimitOrder` and `CreateMarketOrder`. Takes simple primitives
/// (price, size, side, tokenId), resolves tick size via the client,
/// signs with the supplied [WalletSigner], and posts the result.
///
/// Lower-level callers can still drive [OrderBuilder] + [signOrderV2] +
/// [ClobWrites.createOrder] directly.
library;

import 'package:meta/meta.dart';

import '../auth/l2.dart';
import '../auth/wallet_signer.dart';
import '../clob/clob_client.dart';
import '../types/enums.dart';
import 'order_builder.dart';
import 'order_intent.dart';
import 'order_signing.dart';

/// Inputs for [createLimitOrder].
@immutable
final class CreateLimitOrderParams {
  const CreateLimitOrderParams({
    required this.tokenId,
    required this.side,
    required this.price,
    required this.size,
    this.orderType = OrderType.gtc,
    this.signatureType = SignatureType.eoa,
    this.negRisk = false,
    this.feeRateBps = 0,
    this.expiration = 0,
    this.funder = '',
    this.postOnly = false,
    this.builderCode = bytes32Zero,
  });

  final String tokenId;
  final Side side;
  final String price;
  final String size;
  final OrderType orderType;
  final SignatureType signatureType;

  /// `true` when the underlying CLOB market is neg-risk (different
  /// verifying contract). Pass the value from [ClobClient.market].
  final bool negRisk;

  final int feeRateBps;
  final int expiration;

  /// Required for non-EOA signature types: the deposit-wallet / proxy /
  /// safe address that owns the order.
  final String funder;

  final bool postOnly;

  /// 0x-prefixed 32-byte builder code from
  /// `polymarket.com/settings?tab=builder`. Defaults to all-zeros (no
  /// builder attribution).
  final String builderCode;
}

/// Inputs for [createMarketOrder]. `amount` is the USDC budget to fill;
/// the helper computes maker/taker via [OrderIntent.amountUsdc].
@immutable
final class CreateMarketOrderParams {
  const CreateMarketOrderParams({
    required this.tokenId,
    required this.side,
    required this.amount,
    this.orderType = OrderType.fok,
    this.signatureType = SignatureType.eoa,
    this.negRisk = false,
    this.feeRateBps = 0,
    this.funder = '',
    this.builderCode = bytes32Zero,
  });

  final String tokenId;
  final Side side;
  final String amount;
  final OrderType orderType;
  final SignatureType signatureType;
  final bool negRisk;
  final int feeRateBps;
  final String funder;
  final String builderCode;
}

/// End-to-end limit-order placement: looks up tick size, builds + signs
/// the V2 order, and POSTs `/order`. Returns the CLOB's
/// [OrderResponse]. Throws [ValidationException] on input errors.
Future<OrderResponse> createLimitOrder({
  required ClobClient client,
  required WalletSigner signer,
  required ApiKey apiKey,
  required CreateLimitOrderParams params,
}) async {
  final tick = await client.tickSize(params.tokenId);
  final intent =
      (OrderBuilder(tokenId: params.tokenId, side: params.side)
            ..price(params.price)
            ..size(params.size)
            ..orderType(params.orderType)
            ..signatureType(params.signatureType)
            ..tickSize(tick.tickSize)
            ..negRisk(params.negRisk)
            ..feeRateBps(params.feeRateBps)
            ..expiration(params.expiration)
            ..funder(params.funder)
            ..postOnly(params.postOnly))
          .build();

  final signed = await signOrderV2(
    intent: intent,
    signer: signer,
    builderCode: params.builderCode,
  );

  return client.writes.createOrder(
    order: signed,
    owner: apiKey.key,
    apiKey: apiKey,
    orderType: params.orderType,
    postOnly: params.postOnly,
  );
}

/// End-to-end market-order placement. `amount` is the USDC budget to
/// fill at the best available prices.
Future<OrderResponse> createMarketOrder({
  required ClobClient client,
  required WalletSigner signer,
  required ApiKey apiKey,
  required CreateMarketOrderParams params,
}) async {
  final tick = await client.tickSize(params.tokenId);
  final intent =
      (OrderBuilder(tokenId: params.tokenId, side: params.side)
            ..amountUsdc(params.amount)
            ..orderType(params.orderType)
            ..signatureType(params.signatureType)
            ..tickSize(tick.tickSize)
            ..negRisk(params.negRisk)
            ..feeRateBps(params.feeRateBps)
            ..funder(params.funder))
          .build();

  final signed = await signOrderV2(
    intent: intent,
    signer: signer,
    builderCode: params.builderCode,
  );

  return client.writes.createOrder(
    order: signed,
    owner: apiKey.key,
    apiKey: apiKey,
    orderType: params.orderType,
  );
}
