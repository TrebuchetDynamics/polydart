/// Conditional Token Framework helpers.
///
/// Mirrors the stable public helpers in `polygolem/pkg/ctf`. These functions
/// only encode calldata and compute ids; they do not submit transactions.
library;

import '../auth/eth_hex.dart';
import '../errors/errors.dart';

const String conditionalTokensAddress =
    '0x4D97DCd97eC945f40cF65F87097ACe5EA0476045';
const String negRiskAdapterAddress =
    '0xd91E80cF2E7be2e162c6513ceD06f1dD0dA35296';
const String usdcAddress = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';
const String bytes32Zero =
    '0x0000000000000000000000000000000000000000000000000000000000000000';

/// ABI-encoded calldata for
/// `splitPosition(address,bytes32,bytes32,uint256[],uint256)`.
String splitPositionData({
  required String collateralToken,
  required String parentCollectionId,
  required String conditionId,
  required List<BigInt> partition,
  required BigInt amount,
}) {
  return _encodeCall(
    'splitPosition(address,bytes32,bytes32,uint256[],uint256)',
    staticWords: <String>[
      _abiAddress(collateralToken),
      _abiBytes32(parentCollectionId),
      _abiBytes32(conditionId),
      _abiUint(BigInt.from(32 * 5)),
      _abiUint(amount),
    ],
    dynamicWords: _abiUintArray(partition),
  );
}

/// ABI-encoded calldata for
/// `mergePositions(address,bytes32,bytes32,uint256[],uint256)`.
String mergePositionsData({
  required String collateralToken,
  required String parentCollectionId,
  required String conditionId,
  required List<BigInt> partition,
  required BigInt amount,
}) {
  return _encodeCall(
    'mergePositions(address,bytes32,bytes32,uint256[],uint256)',
    staticWords: <String>[
      _abiAddress(collateralToken),
      _abiBytes32(parentCollectionId),
      _abiBytes32(conditionId),
      _abiUint(BigInt.from(32 * 5)),
      _abiUint(amount),
    ],
    dynamicWords: _abiUintArray(partition),
  );
}

/// ABI-encoded calldata for
/// `redeemPositions(address,bytes32,bytes32,uint256[])`.
String redeemPositionsData({
  required String collateralToken,
  required String parentCollectionId,
  required String conditionId,
  required List<BigInt> indexSets,
}) {
  return _encodeCall(
    'redeemPositions(address,bytes32,bytes32,uint256[])',
    staticWords: <String>[
      _abiAddress(collateralToken),
      _abiBytes32(parentCollectionId),
      _abiBytes32(conditionId),
      _abiUint(BigInt.from(32 * 4)),
    ],
    dynamicWords: _abiUintArray(indexSets),
  );
}

/// Calculates the CTF position id from collateral token and collection id.
String positionId(String collateralToken, String collectionId) {
  return bytesToHex0x(
    keccak256Bytes([
      ...hexToBytes(normalizeAddress(collateralToken)),
      ...hexToBytes(_bytes32(collectionId)),
    ]),
  );
}

/// Calculates the CTF collection id from parent collection id, condition id,
/// and index set.
String collectionId(
  String parentCollectionId,
  String conditionId,
  BigInt indexSet,
) {
  return bytesToHex0x(
    keccak256Bytes([
      ...hexToBytes(_bytes32(parentCollectionId)),
      ...hexToBytes(_bytes32(conditionId)),
      ..._minimalUintBytes(indexSet),
    ]),
  );
}

String _encodeCall(
  String signature, {
  required List<String> staticWords,
  required List<String> dynamicWords,
}) {
  final selector = bytesToHex(keccak256Utf8(signature).sublist(0, 4));
  return '0x$selector${staticWords.join()}${dynamicWords.join()}';
}

String _abiAddress(String address) {
  return bytesToHex(leftPadBytes(hexToBytes(normalizeAddress(address))));
}

String _abiBytes32(String value) => _strip0x(_bytes32(value));

String _abiUint(BigInt value) => bytesToHex(uint256BigEndian(value));

List<String> _abiUintArray(List<BigInt> values) {
  return <String>[
    _abiUint(BigInt.from(values.length)),
    for (final value in values) _abiUint(value),
  ];
}

String _bytes32(String value) {
  final clean = _strip0x(value);
  if (clean.length > 64) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'bytes32 value is too long',
    );
  }
  hexToBytes(clean);
  return '0x${clean.toLowerCase().padLeft(64, '0')}';
}

List<int> _minimalUintBytes(BigInt value) {
  if (value.isNegative) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'uint256 cannot be negative',
    );
  }
  if (value == BigInt.zero) return const <int>[];
  final out = <int>[];
  var n = value;
  while (n > BigInt.zero) {
    out.add((n & BigInt.from(0xff)).toInt());
    n = n >> 8;
  }
  return out.reversed.toList(growable: false);
}

String _strip0x(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
    return trimmed.substring(2);
  }
  return trimmed;
}
