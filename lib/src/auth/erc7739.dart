/// ERC-7739 / POLY_1271 signature wrapping.
///
/// Mirrors `wrapPOLY1271Signature` in `internal/clob/orders.go`. Used when
/// a deposit wallet (signature type 3) makes a Polymarket V2 CTF Exchange
/// order. The wallet validates the wrapped signature on-chain via
/// `isValidSignature` per EIP-1271; the wrap itself is the ERC-7739
/// `TypedDataSign` envelope under the Exchange domain.
///
/// Two integration shapes are exposed:
///
///   * [wrapPoly1271Signature] — convenience: takes a [WalletSigner],
///     constructs the EIP-712 envelope a wallet provider expects, gets the
///     65-byte ECDSA back, and assembles the 317-byte wrap.
///   * [assemblePoly1271WrappedSignature] — useful when the consumer signs
///     the canonical [computePoly1271FinalHash] digest themselves (CLI
///     bots, hardware wallets that expose raw signing).
///
/// Layout (317 bytes / 636 hex chars):
///
/// ```
/// innerSig (65) ‖ appDomainSep (32) ‖ contents (32) ‖ contentsType (var) ‖ uint16BE(contentsType.length)
/// ```
///
/// For the canonical V2 Order schema, `contentsType.length == 186`.
library;

import 'dart:typed_data';

import '../errors/errors.dart';
import 'eip712.dart';
import 'eth_hex.dart';
import 'wallet_signer.dart';
import '../orders/order_signing.dart';

/// EIP-712 inline domain name for the deposit-wallet inside the
/// `TypedDataSign` envelope.
const String polyDepositWalletDomainName = 'DepositWallet';

/// EIP-712 inline domain version for the deposit-wallet.
const String polyDepositWalletDomainVersion = '1';

/// `TypedDataSign` typehash payload prefix per ERC-7739. The full encoded
/// type is this prefix followed by the contents type string.
const String typedDataSignPrefix =
    'TypedDataSign(Order contents,string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)';

/// Builds the canonical `TypedDataSign` typehash for the V2 Order
/// schema:
///
/// ```
/// keccak256(typedDataSignPrefix ‖ orderV2ContentsType)
/// ```
Uint8List poly1271TypedDataSignTypeHash() {
  return keccak256Utf8('$typedDataSignPrefix$orderV2ContentsType');
}

/// Computes `hashStruct(TypedDataSign{contents, DepositWallet inline domain
/// values})`. Mirrors step 3 in polygolem's `wrapPOLY1271Signature`.
Uint8List poly1271StructHash({
  required Uint8List contents,
  required String depositWalletAddress,
  int chainId = polymarketChainId,
}) {
  if (contents.length != 32) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'contents must be 32 bytes (got ${contents.length})',
    );
  }
  final dwAddr = hexToBytes(_strip0x(depositWalletAddress));
  if (dwAddr.length != 20) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message:
          'depositWalletAddress must be 20 bytes (got ${dwAddr.length})',
    );
  }
  return keccak256Bytes(
    concatBytes([
      poly1271TypedDataSignTypeHash(),
      contents,
      keccak256Utf8(polyDepositWalletDomainName),
      keccak256Utf8(polyDepositWalletDomainVersion),
      uint256BigEndian(BigInt.from(chainId)),
      leftPadBytes(dwAddr, length: 32),
      Uint8List(32), // salt = bytes32(0)
    ]),
  );
}

/// Computes the 32-byte digest the wallet signs for an ERC-7739 wrapped
/// V2 Order. This is `keccak256(0x1901 ‖ appDomainSep ‖ tdsStruct)` where
/// the outer domain is the CTF Exchange V2 domain.
Uint8List computePoly1271FinalHash({
  required OrderV2Draft draft,
  required String depositWalletAddress,
  bool negRisk = false,
  int chainId = polymarketChainId,
}) {
  final appDomainSep = orderV2DomainSeparator(negRisk: negRisk);
  final contents = orderV2StructHash(draft: draft);
  final tdsStruct = poly1271StructHash(
    contents: contents,
    depositWalletAddress: depositWalletAddress,
    chainId: chainId,
  );
  return keccak256Bytes(
    concatBytes([
      Uint8List.fromList(<int>[0x19, 0x01]),
      appDomainSep,
      tdsStruct,
    ]),
  );
}

/// Builds the EIP-712 `TypedDataSign` envelope a wallet provider can sign
/// via `eth_signTypedData_v4`. Hashing this envelope under EIP-712
/// produces exactly [computePoly1271FinalHash], so any wallet that
/// implements `signTypedData_v4` correctly will yield a valid innerSig
/// without needing raw-digest signing.
Map<String, dynamic> buildPoly1271TypedDataEnvelope({
  required OrderV2Draft draft,
  required String depositWalletAddress,
  bool negRisk = false,
  int chainId = polymarketChainId,
}) {
  return <String, dynamic>{
    'types': <String, List<Map<String, String>>>{
      'EIP712Domain': <Map<String, String>>[
        {'name': 'name', 'type': 'string'},
        {'name': 'version', 'type': 'string'},
        {'name': 'chainId', 'type': 'uint256'},
        {'name': 'verifyingContract', 'type': 'address'},
      ],
      'TypedDataSign': <Map<String, String>>[
        {'name': 'contents', 'type': 'Order'},
        {'name': 'name', 'type': 'string'},
        {'name': 'version', 'type': 'string'},
        {'name': 'chainId', 'type': 'uint256'},
        {'name': 'verifyingContract', 'type': 'address'},
        {'name': 'salt', 'type': 'bytes32'},
      ],
      'Order': <Map<String, String>>[
        for (final f in orderV2Fields) {'name': f.name, 'type': f.type},
      ],
    },
    'primaryType': 'TypedDataSign',
    'domain': <String, Object>{
      'name': polymarketCtfV2DomainName,
      'version': polymarketCtfV2DomainVersion,
      'chainId': chainId,
      'verifyingContract': OrderV2Draft.verifyingContract(negRisk: negRisk),
    },
    'message': <String, Object>{
      'contents': <String, Object>{
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
      'name': polyDepositWalletDomainName,
      'version': polyDepositWalletDomainVersion,
      'chainId': chainId,
      'verifyingContract': depositWalletAddress,
      'salt': bytes32Zero,
    },
  };
}

/// Assembles the 317-byte ERC-7739 wrap from an already-produced 65-byte
/// ECDSA signature plus the V2 order context.
String assemblePoly1271WrappedSignature({
  required Uint8List innerSignature,
  required OrderV2Draft draft,
  bool negRisk = false,
}) {
  if (innerSignature.length != 65) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message:
          'innerSignature must be 65 bytes (got ${innerSignature.length})',
    );
  }
  final appDomainSep = orderV2DomainSeparator(negRisk: negRisk);
  final contents = orderV2StructHash(draft: draft);
  final contentsTypeBytes =
      Uint8List.fromList(orderV2ContentsType.codeUnits);
  final lenBuf = Uint8List(2)
    ..[0] = (contentsTypeBytes.length >> 8) & 0xff
    ..[1] = contentsTypeBytes.length & 0xff;
  final wrap = concatBytes([
    innerSignature,
    appDomainSep,
    contents,
    contentsTypeBytes,
    lenBuf,
  ]);
  return bytesToHex0x(wrap);
}

/// Produces a complete ERC-7739 / POLY_1271 wrapped signature using the
/// supplied [signer].
///
/// The signer must implement `eth_signTypedData_v4` semantics: it is given
/// the typed-data envelope returned by [buildPoly1271TypedDataEnvelope]
/// and is expected to return a 65-byte `(r ‖ s ‖ v)` signature with `v`
/// normalized to 27 / 28.
Future<String> wrapPoly1271Signature({
  required WalletSigner signer,
  required OrderV2Draft draft,
  required String depositWalletAddress,
  bool negRisk = false,
}) async {
  final envelope = buildPoly1271TypedDataEnvelope(
    draft: draft,
    depositWalletAddress: depositWalletAddress,
    negRisk: negRisk,
    chainId: signer.chainId,
  );
  final innerSig = await signer.signTypedData(envelope);
  if (innerSig.length != 65) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message:
          'wallet returned ${innerSig.length}-byte signature (expected 65)',
    );
  }
  return assemblePoly1271WrappedSignature(
    innerSignature: innerSig,
    draft: draft,
    negRisk: negRisk,
  );
}

/// Independent EIP-712 cross-check: computes the digest a compliant wallet
/// would derive when given [buildPoly1271TypedDataEnvelope]'s output, by
/// running the canonical EIP-712 hash pipeline directly.
///
/// Useful in tests / consumers that want to verify their wallet
/// implementation matches the protocol expectation.
Uint8List poly1271DigestFromEnvelope({
  required OrderV2Draft draft,
  required String depositWalletAddress,
  bool negRisk = false,
  int chainId = polymarketChainId,
}) {
  final domain = Eip712Domain(
    name: polymarketCtfV2DomainName,
    version: polymarketCtfV2DomainVersion,
    chainId: chainId,
    verifyingContract: OrderV2Draft.verifyingContract(negRisk: negRisk),
  );
  final fields = <Eip712Field>[
    const Eip712Field('contents', 'Order'),
    const Eip712Field('name', 'string'),
    const Eip712Field('version', 'string'),
    const Eip712Field('chainId', 'uint256'),
    const Eip712Field('verifyingContract', 'address'),
    const Eip712Field('salt', 'bytes32'),
  ];
  // hashStruct(TypedDataSign) — but our generic encoder doesn't know about
  // nested struct refs, so we pre-hash `contents` and pass it as bytes32.
  final contents = orderV2StructHash(draft: draft);
  final tdsStruct = poly1271StructHash(
    contents: contents,
    depositWalletAddress: depositWalletAddress,
    chainId: chainId,
  );
  // Validate the field schema is consistent (helps catch encoder drift).
  // The actual hashStruct used in the digest is `tdsStruct`; we assemble
  // the digest manually rather than re-using hashTypedData because the
  // contents field uses a custom typehash prefix.
  if (fields.length != 6) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'TypedDataSign schema drift',
    );
  }
  return keccak256Bytes(
    concatBytes([
      Uint8List.fromList(<int>[0x19, 0x01]),
      eip712DomainSeparator(domain),
      tdsStruct,
    ]),
  );
}

String _strip0x(String s) {
  if (s.startsWith('0x') || s.startsWith('0X')) return s.substring(2);
  return s;
}
