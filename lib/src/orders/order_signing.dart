/// Order V2 signing (Polymarket CTF Exchange v2).
///
/// Mirrors the V2 paths in `polygolem/internal/clob/orders.go`. Phase 2B-1
/// ships:
///   * V2 Order EIP-712 typed-data builder (the JSON shape wallet
///     providers expect for `eth_signTypedData_v4`).
///   * `hashOrderV2` — canonical EIP-712 digest, useful for verification
///     and as the input to ERC-7739 wrapping.
///
/// Live-mode `wrapPoly1271Signature` (the 317-byte ERC-7739 envelope)
/// lands in a follow-up commit alongside `polydart_flutter`.
library;

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../auth/eip712.dart';
import '../auth/eth_hex.dart';
import '../auth/wallet_signer.dart';
import '../errors/errors.dart';
import '../types/enums.dart';
import 'amounts.dart';
import 'order_intent.dart';

const String polymarketCtfV2DomainName = 'Polymarket CTF Exchange';
const String polymarketCtfV2DomainVersion = '2';
const int polymarketChainId = 137;

const String clobExchangeAddressV2 =
    '0xE111180000d2663C0091e4f400237545B87B996B';
const String negRiskExchangeAddressV2 =
    '0xe2222d279d744050d28e00520010520000310F59';

const String bytes32Zero =
    '0x0000000000000000000000000000000000000000000000000000000000000000';

const List<Eip712Field> orderV2Fields = <Eip712Field>[
  Eip712Field('salt', 'uint256'),
  Eip712Field('maker', 'address'),
  Eip712Field('signer', 'address'),
  Eip712Field('tokenId', 'uint256'),
  Eip712Field('makerAmount', 'uint256'),
  Eip712Field('takerAmount', 'uint256'),
  Eip712Field('side', 'uint8'),
  Eip712Field('signatureType', 'uint8'),
  Eip712Field('timestamp', 'uint256'),
  Eip712Field('metadata', 'bytes32'),
  Eip712Field('builder', 'bytes32'),
];

/// Canonical V2 Order type string used in ERC-7739 wrapping.
const String orderV2ContentsType =
    'Order(uint256 salt,address maker,address signer,uint256 tokenId,uint256 makerAmount,uint256 takerAmount,uint8 side,uint8 signatureType,uint256 timestamp,bytes32 metadata,bytes32 builder)';

/// V2 Order draft — the mutable inputs that get hashed and signed.
@immutable
final class OrderV2Draft {
  const OrderV2Draft({
    required this.salt,
    required this.maker,
    required this.signer,
    required this.tokenId,
    required this.makerAmount,
    required this.takerAmount,
    required this.side,
    required this.signatureType,
    required this.timestamp,
    this.metadata = bytes32Zero,
    this.builder = bytes32Zero,
  });

  /// Decimal stringified uint256.
  final String salt;

  final String maker;
  final String signer;

  /// Numeric token id (uint256 string).
  final String tokenId;

  /// Maker amount in 1e6 USDC fixed-point (uint256 string).
  final String makerAmount;

  /// Taker amount in 1e6 USDC fixed-point (uint256 string).
  final String takerAmount;

  final Side side;
  final SignatureType signatureType;

  /// Milliseconds since epoch (uint256 string).
  final String timestamp;

  /// 0x-prefixed 32-byte hex.
  final String metadata;

  /// 0x-prefixed 32-byte hex.
  final String builder;

  /// Returns the verifying-contract address for the given market type.
  static String verifyingContract({required bool negRisk}) =>
      negRisk ? negRiskExchangeAddressV2 : clobExchangeAddressV2;
}

/// Builds the V2 Order EIP-712 typed-data payload for
/// `eth_signTypedData_v4`.
Map<String, dynamic> buildOrderV2TypedData({
  required OrderV2Draft draft,
  bool negRisk = false,
}) {
  return <String, dynamic>{
    'types': <String, List<Map<String, String>>>{
      'EIP712Domain': <Map<String, String>>[
        {'name': 'name', 'type': 'string'},
        {'name': 'version', 'type': 'string'},
        {'name': 'chainId', 'type': 'uint256'},
        {'name': 'verifyingContract', 'type': 'address'},
      ],
      'Order': <Map<String, String>>[
        for (final f in orderV2Fields) {'name': f.name, 'type': f.type},
      ],
    },
    'primaryType': 'Order',
    'domain': <String, Object>{
      'name': polymarketCtfV2DomainName,
      'version': polymarketCtfV2DomainVersion,
      'chainId': polymarketChainId,
      'verifyingContract': OrderV2Draft.verifyingContract(negRisk: negRisk),
    },
    'message': <String, Object>{
      'salt': draft.salt,
      'maker': draft.maker,
      'signer': draft.signer,
      'tokenId': draft.tokenId,
      'makerAmount': draft.makerAmount,
      'takerAmount': draft.takerAmount,
      'side': draft.side.code,
      'signatureType': draft.signatureType.code,
      'timestamp': draft.timestamp,
      'metadata': draft.metadata,
      'builder': draft.builder,
    },
  };
}

/// Computes the EIP-712 digest the wallet would sign.
Uint8List hashOrderV2({required OrderV2Draft draft, bool negRisk = false}) {
  final domain = Eip712Domain(
    name: polymarketCtfV2DomainName,
    version: polymarketCtfV2DomainVersion,
    chainId: polymarketChainId,
    verifyingContract: OrderV2Draft.verifyingContract(negRisk: negRisk),
  );
  return hashTypedData(
    domain: domain,
    primaryType: 'Order',
    fields: orderV2Fields,
    message: <String, Object?>{
      'salt': BigInt.parse(draft.salt),
      'maker': draft.maker,
      'signer': draft.signer,
      'tokenId': BigInt.parse(draft.tokenId),
      'makerAmount': BigInt.parse(draft.makerAmount),
      'takerAmount': BigInt.parse(draft.takerAmount),
      'side': BigInt.from(draft.side.code),
      'signatureType': BigInt.from(draft.signatureType.code),
      'timestamp': BigInt.parse(draft.timestamp),
      'metadata': hexToBytes(draft.metadata),
      'builder': hexToBytes(draft.builder),
    },
  );
}

/// Computes the V2 domain separator. Useful for ERC-7739 wrapping where
/// callers need the appDomainSep input.
Uint8List orderV2DomainSeparator({bool negRisk = false}) {
  return eip712DomainSeparator(
    Eip712Domain(
      name: polymarketCtfV2DomainName,
      version: polymarketCtfV2DomainVersion,
      chainId: polymarketChainId,
      verifyingContract: OrderV2Draft.verifyingContract(negRisk: negRisk),
    ),
  );
}

/// Builds, signs, and packages an [OrderIntent] into a wire-ready
/// [SignedOrder]. Mirrors the orchestration in
/// `polygolem/internal/clob/orders.go::signCLOBOrder` for V2 / EOA
/// signature flows; POLY_1271 (deposit-wallet) consumers should still go
/// through `wrapPoly1271Signature` after this returns the raw signature.
///
/// - For [SignatureType.eoa] (default), `maker = signer = signer.address`.
/// - For other signature types, the caller must supply [intent.funder]
///   (the proxy / safe / deposit-wallet address). `signer` is always the
///   EOA. If [makerOverride] is set, it wins over the funder field.
Future<SignedOrder> signOrderV2({
  required OrderIntent intent,
  required WalletSigner signer,
  String builderCode = bytes32Zero,
  String? makerOverride,
}) async {
  intent.validate();
  final amounts = computeAmounts(intent);

  final eoa = signer.address;
  final maker =
      makerOverride ??
      (intent.signatureType == SignatureType.eoa ? eoa : intent.funder);
  if (maker.isEmpty) {
    throw const ValidationException(
      code: ErrorCode.missingField,
      message:
          'maker address is empty: pass intent.funder for non-EOA signature types',
      field: 'funder',
    );
  }

  final salt = generateOrderSalt();
  final timestampMs = DateTime.now().millisecondsSinceEpoch.toString();

  final draft = OrderV2Draft(
    salt: salt,
    maker: maker,
    signer: eoa,
    tokenId: intent.tokenId,
    makerAmount: amounts.makerAmount.toString(),
    takerAmount: amounts.takerAmount.toString(),
    side: intent.side,
    signatureType: intent.signatureType,
    timestamp: timestampMs,
    metadata: bytes32Zero,
    builder: builderCode,
  );

  final typed = buildOrderV2TypedData(draft: draft, negRisk: intent.negRisk);
  final sigBytes = await signer.signTypedData(typed);
  if (sigBytes.length != 65) {
    throw ValidationException(
      code: ErrorCode.invalidSignature,
      message:
          'wallet returned ${sigBytes.length}-byte signature (expected 65)',
    );
  }

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
    signature: bytesToHex0x(sigBytes),
    timestamp: int.parse(draft.timestamp),
    metadata: draft.metadata,
    builder: draft.builder,
  );
}

/// Computes hashStruct(Order) — the `contents` input for ERC-7739
/// wrapping.
Uint8List orderV2StructHash({required OrderV2Draft draft}) {
  return eip712HashStruct('Order', orderV2Fields, <String, Object?>{
    'salt': BigInt.parse(draft.salt),
    'maker': draft.maker,
    'signer': draft.signer,
    'tokenId': BigInt.parse(draft.tokenId),
    'makerAmount': BigInt.parse(draft.makerAmount),
    'takerAmount': BigInt.parse(draft.takerAmount),
    'side': BigInt.from(draft.side.code),
    'signatureType': BigInt.from(draft.signatureType.code),
    'timestamp': BigInt.parse(draft.timestamp),
    'metadata': hexToBytes(draft.metadata),
    'builder': hexToBytes(draft.builder),
  });
}
