/// Deposit-wallet order signing.
///
/// Builds signatureType=3 V2 orders for the current Polymarket deposit-wallet
/// flow. The caller-provided [WalletSigner] is the controlling EOA; the order
/// maker and signer fields are the derived or provided deposit wallet, and the
/// signature is the ERC-7739 / POLY_1271 wrapped form.
library;

import '../auth/erc7739.dart';
import '../auth/eth_hex.dart';
import '../auth/wallet_signer.dart';
import '../errors/errors.dart';
import '../types/enums.dart';
import 'amounts.dart';
import 'order_intent.dart';
import 'order_signing.dart';

/// Builds, wraps, and packages a deposit-wallet V2 order.
///
/// This is the signatureType=3 counterpart to [signOrderV2]. It asks the EOA
/// wallet to approve the ERC-7739 `TypedDataSign` envelope and returns a
/// CLOB-ready [SignedOrder].
Future<SignedOrder> signDepositWalletOrderV2({
  required OrderIntent intent,
  required WalletSigner signer,
  required String depositWallet,
  String builderCode = bytes32Zero,
}) async {
  intent.validate();
  if (intent.signatureType != SignatureType.poly1271) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'deposit-wallet orders require signatureType=3',
      field: 'signatureType',
    );
  }
  if (signer.chainId != polymarketChainId) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message:
          'deposit-wallet order signing requires Polygon chainId=$polymarketChainId',
      field: 'chainId',
    );
  }
  final walletRaw = depositWallet.trim();
  if (walletRaw.isEmpty) {
    throw const ValidationException(
      code: ErrorCode.missingField,
      message: 'depositWallet is required',
      field: 'depositWallet',
    );
  }
  final wallet = normalizeAddress(walletRaw);
  final amounts = computeAmounts(intent);
  final salt = generateOrderSalt();
  final timestampMs = DateTime.now().millisecondsSinceEpoch.toString();

  final draft = OrderV2Draft(
    salt: salt,
    maker: wallet,
    signer: wallet,
    tokenId: intent.tokenId,
    makerAmount: amounts.makerAmount.toString(),
    takerAmount: amounts.takerAmount.toString(),
    side: intent.side,
    signatureType: SignatureType.poly1271,
    timestamp: timestampMs,
    metadata: bytes32Zero,
    builder: builderCode,
  );

  final signature = await wrapPoly1271Signature(
    signer: signer,
    draft: draft,
    depositWalletAddress: wallet,
    negRisk: intent.negRisk,
  );

  return SignedOrder(
    salt: draft.salt,
    maker: draft.maker,
    signer: draft.signer,
    taker: '0x0000000000000000000000000000000000000000',
    tokenId: draft.tokenId,
    makerAmount: draft.makerAmount,
    takerAmount: draft.takerAmount,
    side: draft.side,
    signatureType: draft.signatureType,
    expiration: intent.expiration,
    nonce: intent.nonce,
    feeRateBps: intent.feeRateBps,
    signature: signature,
    timestamp: int.parse(draft.timestamp),
    metadata: draft.metadata,
    builder: draft.builder,
  );
}
