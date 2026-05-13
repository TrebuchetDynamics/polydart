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

import '../auth/create2.dart';
import '../auth/l2.dart';
import '../auth/wallet_signer.dart';
import '../bookreader/bookreader.dart';
import '../clob/clob_client.dart';
import '../clob/clob_writes.dart';
import '../errors/errors.dart';
import '../types/enums.dart';
import 'deposit_wallet_order_signing.dart';
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

/// Inputs for [createDepositWalletLimitOrder].
///
/// This is intentionally separate from [CreateLimitOrderParams] so callers do
/// not choose a signature type or funder manually. The helper derives the
/// deposit wallet from the EOA [WalletSigner].
@immutable
final class CreateDepositWalletLimitOrderParams {
  const CreateDepositWalletLimitOrderParams({
    required this.tokenId,
    required this.side,
    required this.price,
    required this.size,
    this.orderType = OrderType.gtc,
    this.negRisk = false,
    this.feeRateBps = 0,
    this.expiration = 0,
    this.postOnly = false,
    this.builderCode = bytes32Zero,
  });

  final String tokenId;
  final Side side;
  final String price;
  final String size;
  final OrderType orderType;
  final bool negRisk;
  final int feeRateBps;
  final int expiration;
  final bool postOnly;
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
    this.price = '',
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

  /// Optional price cap/fill price. When omitted, [createMarketOrder] walks
  /// the current book and uses the opposing level needed to fill [amount].
  final String price;

  final OrderType orderType;
  final SignatureType signatureType;
  final bool negRisk;
  final int feeRateBps;
  final String funder;
  final String builderCode;
}

/// Inputs for [createDepositWalletMarketOrder].
///
/// This mirrors [CreateMarketOrderParams] but pins signatureType/funder to the
/// EOA-derived deposit wallet so callers cannot accidentally sign a live
/// deposit-wallet order as a plain EOA order.
@immutable
final class CreateDepositWalletMarketOrderParams {
  const CreateDepositWalletMarketOrderParams({
    required this.tokenId,
    required this.side,
    required this.amount,
    this.price = '',
    this.orderType = OrderType.fok,
    this.negRisk = false,
    this.feeRateBps = 0,
    this.builderCode = bytes32Zero,
  });

  final String tokenId;
  final Side side;
  final String amount;
  final String price;
  final OrderType orderType;
  final bool negRisk;
  final int feeRateBps;
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

  final signed = intent.signatureType == SignatureType.poly1271
      ? await signDepositWalletOrderV2(
          intent: intent,
          signer: signer,
          depositWallet: intent.funder,
          builderCode: params.builderCode,
        )
      : await signOrderV2(
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
    polyAddress: signer.address,
  );
}

/// End-to-end deposit-wallet limit-order placement.
///
/// The EOA [signer] approves the ERC-7739 envelope. The order body uses
/// signatureType=3 with `maker == signer == depositWallet`, while CLOB HMAC
/// authentication remains bound to the EOA address.
Future<OrderResponse> createDepositWalletLimitOrder({
  required ClobClient client,
  required WalletSigner signer,
  required ApiKey apiKey,
  required CreateDepositWalletLimitOrderParams params,
}) {
  final depositWallet = deriveDepositWallet(signer.address);
  return createLimitOrder(
    client: client,
    signer: signer,
    apiKey: apiKey,
    params: CreateLimitOrderParams(
      tokenId: params.tokenId,
      side: params.side,
      price: params.price,
      size: params.size,
      orderType: params.orderType,
      signatureType: SignatureType.poly1271,
      negRisk: params.negRisk,
      feeRateBps: params.feeRateBps,
      expiration: params.expiration,
      funder: depositWallet,
      postOnly: params.postOnly,
      builderCode: params.builderCode,
    ),
  );
}

/// End-to-end deposit-wallet batch limit-order placement.
///
/// Each order is built and signed independently through [signer]. The CLOB
/// HTTP auth address stays EOA-bound while every signed order body uses
/// `maker == signer == depositWallet` and `signatureType=3`.
Future<BatchOrderResponse> createDepositWalletLimitOrders({
  required ClobClient client,
  required WalletSigner signer,
  required ApiKey apiKey,
  required List<CreateDepositWalletLimitOrderParams> orders,
}) async {
  if (orders.isEmpty) {
    throw const ValidationException(
      code: ErrorCode.missingField,
      message: 'orders must not be empty',
      field: 'orders',
    );
  }
  if (orders.length > maxBatchPostSize) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'orders exceeds maxBatchPostSize',
      field: 'orders',
    );
  }

  final depositWallet = deriveDepositWallet(signer.address);
  final requests = <CreateOrderRequest>[];
  for (final params in orders) {
    final tick = await client.tickSize(params.tokenId);
    final intent =
        (OrderBuilder(tokenId: params.tokenId, side: params.side)
              ..price(params.price)
              ..size(params.size)
              ..orderType(params.orderType)
              ..signatureType(SignatureType.poly1271)
              ..tickSize(tick.tickSize)
              ..negRisk(params.negRisk)
              ..feeRateBps(params.feeRateBps)
              ..expiration(params.expiration)
              ..funder(depositWallet)
              ..postOnly(params.postOnly))
            .build();

    final signed = await signDepositWalletOrderV2(
      intent: intent,
      signer: signer,
      depositWallet: depositWallet,
      builderCode: params.builderCode,
    );
    requests.add(
      CreateOrderRequest(
        order: signed,
        owner: apiKey.key,
        orderType: params.orderType,
        postOnly: params.postOnly,
      ),
    );
  }

  return client.writes.createOrders(
    requests: requests,
    apiKey: apiKey,
    polyAddress: signer.address,
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
  if (params.side != Side.buy) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'market-order amount is currently supported for BUY only',
      field: 'side',
    );
  }
  final tick = await client.tickSize(params.tokenId);
  final price = params.price.trim().isEmpty
      ? await _marketOrderPrice(
          client: client,
          tokenId: params.tokenId,
          side: params.side,
          amount: params.amount,
          orderType: params.orderType,
        )
      : params.price;
  final intent =
      (OrderBuilder(tokenId: params.tokenId, side: params.side)
            ..price(price)
            ..amountUsdc(params.amount)
            ..orderType(params.orderType)
            ..signatureType(params.signatureType)
            ..tickSize(tick.tickSize)
            ..negRisk(params.negRisk)
            ..feeRateBps(params.feeRateBps)
            ..funder(params.funder))
          .build();

  final signed = intent.signatureType == SignatureType.poly1271
      ? await signDepositWalletOrderV2(
          intent: intent,
          signer: signer,
          depositWallet: intent.funder,
          builderCode: params.builderCode,
        )
      : await signOrderV2(
          intent: intent,
          signer: signer,
          builderCode: params.builderCode,
        );

  return client.writes.createOrder(
    order: signed,
    owner: apiKey.key,
    apiKey: apiKey,
    orderType: params.orderType,
    polyAddress: signer.address,
  );
}

/// End-to-end deposit-wallet market-order placement.
///
/// The EOA [signer] approves the ERC-7739 envelope. The order body uses
/// signatureType=3 with `maker == signer == depositWallet`, while CLOB HMAC
/// authentication remains bound to the EOA address.
Future<OrderResponse> createDepositWalletMarketOrder({
  required ClobClient client,
  required WalletSigner signer,
  required ApiKey apiKey,
  required CreateDepositWalletMarketOrderParams params,
}) {
  final depositWallet = deriveDepositWallet(signer.address);
  return createMarketOrder(
    client: client,
    signer: signer,
    apiKey: apiKey,
    params: CreateMarketOrderParams(
      tokenId: params.tokenId,
      side: params.side,
      amount: params.amount,
      price: params.price,
      orderType: params.orderType,
      signatureType: SignatureType.poly1271,
      negRisk: params.negRisk,
      feeRateBps: params.feeRateBps,
      funder: depositWallet,
      builderCode: params.builderCode,
    ),
  );
}

Future<String> _marketOrderPrice({
  required ClobClient client,
  required String tokenId,
  required Side side,
  required String amount,
  required OrderType orderType,
}) async {
  final amountValue = double.parse(amount);
  if (amountValue <= 0) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'amount must be positive',
      field: 'amount',
    );
  }

  final book = BookReader(await client.orderBook(tokenId));
  final levels = side == Side.buy ? book.asks : book.bids;
  if (levels.isEmpty) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'no opposing orders',
    );
  }

  var notional = 0.0;
  for (final level in levels) {
    final price = double.parse(level.price);
    final size = double.parse(level.size);
    notional += price * size;
    if (notional >= amountValue) {
      return level.price;
    }
  }

  if (orderType == OrderType.fok) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'insufficient liquidity to fill order',
    );
  }
  return levels.first.price;
}
