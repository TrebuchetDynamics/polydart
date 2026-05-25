/// DepositWallet.Batch EIP-712 signing.
///
/// Mirrors `internal/relayer/signing.go::SignWalletBatch`. A deposit
/// wallet executes a list of `Call(target, value, data)` entries on
/// behalf of its owner once a relayer submits the signed batch on-chain.
/// The on-chain contract validates this signature via EIP-712.
///
/// This module is pure compute — no I/O. The relayer-proxy HTTP client
/// that ferries the signed batch to a user-deployed proxy lands later in
/// `lib/src/relayer/` (Phase 3).
library;

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../auth/eip712.dart';
import '../auth/eth_hex.dart';
import '../auth/wallet_signer.dart';
import '../errors/errors.dart';

/// EIP-712 domain name for the deposit-wallet schema.
const String depositWalletDomainName = 'DepositWallet';

/// EIP-712 domain version for the deposit-wallet schema.
const String depositWalletDomainVersion = '1';

const int _polygonChainId = 137;

/// Canonical encodeType for `Call`. Used in hashStruct(Call).
const String walletBatchCallTypeString =
    'Call(address target,uint256 value,bytes data)';

/// Canonical encodeType for `Batch`. Per EIP-712, dependent struct types
/// are appended in alphabetical order — only `Call` here.
const String walletBatchTypeString =
    'Batch(address wallet,uint256 nonce,uint256 deadline,Call[] calls)$walletBatchCallTypeString';

/// One call within a [WalletBatch].
@immutable
final class WalletBatchCall {
  const WalletBatchCall({
    required this.target,
    required this.value,
    required this.data,
  });

  /// 0x-prefixed contract address being called.
  final String target;

  /// Value (wei) to send with the call. uint256-stringified.
  final String value;

  /// Calldata as 0x-prefixed hex (`'0x'` for empty).
  final String data;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'target': target,
    'value': value,
    'data': data,
  };
}

/// Computes `keccak256(walletBatchCallTypeString)`.
Uint8List walletBatchCallTypeHash() => keccak256Utf8(walletBatchCallTypeString);

/// Computes `keccak256(walletBatchTypeString)`.
Uint8List walletBatchTypeHash() => keccak256Utf8(walletBatchTypeString);

/// Computes `hashStruct(Call)` for one call.
Uint8List hashWalletBatchCall(WalletBatchCall call) {
  final target = hexToBytes(_strip0x(call.target));
  if (target.length != 20) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'Call.target must be a 20-byte address (got ${target.length})',
      field: 'target',
    );
  }
  final valueBig = BigInt.tryParse(call.value);
  if (valueBig == null) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'Call.value must be a uint256 string (got ${call.value})',
      field: 'value',
    );
  }
  final dataBytes = hexToBytes(call.data);
  return keccak256Bytes(
    concatBytes([
      walletBatchCallTypeHash(),
      leftPadBytes(target, length: 32),
      uint256BigEndian(valueBig),
      keccak256Bytes(dataBytes),
    ]),
  );
}

/// Computes `hashStruct(Batch)`.
Uint8List hashWalletBatchStruct({
  required String walletAddress,
  required String nonce,
  required String deadline,
  required List<WalletBatchCall> calls,
}) {
  if (calls.isEmpty) {
    throw const ValidationException(
      code: ErrorCode.missingField,
      message: 'at least one Call is required',
      field: 'calls',
    );
  }
  final wallet = hexToBytes(_strip0x(walletAddress));
  if (wallet.length != 20) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'walletAddress must be a 20-byte address (got ${wallet.length})',
      field: 'walletAddress',
    );
  }
  final nonceBig = BigInt.tryParse(nonce);
  if (nonceBig == null) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'nonce must be a uint256 string (got $nonce)',
      field: 'nonce',
    );
  }
  final deadlineBig = BigInt.tryParse(deadline);
  if (deadlineBig == null) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'deadline must be a uint256 string (got $deadline)',
      field: 'deadline',
    );
  }
  // Array hash: keccak256(concat(hashStruct(call_i)…))
  final callsHash = keccak256Bytes(
    concatBytes(calls.map(hashWalletBatchCall).toList(growable: false)),
  );
  return keccak256Bytes(
    concatBytes([
      walletBatchTypeHash(),
      leftPadBytes(wallet, length: 32),
      uint256BigEndian(nonceBig),
      uint256BigEndian(deadlineBig),
      callsHash,
    ]),
  );
}

/// Computes the final EIP-712 digest a wallet would sign for the batch.
Uint8List hashWalletBatchTypedData({
  required String walletAddress,
  required String nonce,
  required String deadline,
  required List<WalletBatchCall> calls,
  int chainId = _polygonChainId,
}) {
  final domain = Eip712Domain(
    name: depositWalletDomainName,
    version: depositWalletDomainVersion,
    chainId: chainId,
    verifyingContract: walletAddress,
  );
  final structHash = hashWalletBatchStruct(
    walletAddress: walletAddress,
    nonce: nonce,
    deadline: deadline,
    calls: calls,
  );
  return keccak256Bytes(
    concatBytes([
      Uint8List.fromList(<int>[0x19, 0x01]),
      eip712DomainSeparator(domain),
      structHash,
    ]),
  );
}

/// Builds the typed-data Map a wallet provider can sign via
/// `eth_signTypedData_v4`. The resulting EIP-712 digest equals
/// [hashWalletBatchTypedData].
Map<String, dynamic> buildWalletBatchTypedData({
  required String walletAddress,
  required String nonce,
  required String deadline,
  required List<WalletBatchCall> calls,
  int chainId = _polygonChainId,
}) {
  return <String, dynamic>{
    'types': <String, List<Map<String, String>>>{
      'EIP712Domain': <Map<String, String>>[
        {'name': 'name', 'type': 'string'},
        {'name': 'version', 'type': 'string'},
        {'name': 'chainId', 'type': 'uint256'},
        {'name': 'verifyingContract', 'type': 'address'},
      ],
      'Call': <Map<String, String>>[
        {'name': 'target', 'type': 'address'},
        {'name': 'value', 'type': 'uint256'},
        {'name': 'data', 'type': 'bytes'},
      ],
      'Batch': <Map<String, String>>[
        {'name': 'wallet', 'type': 'address'},
        {'name': 'nonce', 'type': 'uint256'},
        {'name': 'deadline', 'type': 'uint256'},
        {'name': 'calls', 'type': 'Call[]'},
      ],
    },
    'primaryType': 'Batch',
    'domain': <String, Object>{
      'name': depositWalletDomainName,
      'version': depositWalletDomainVersion,
      'chainId': chainId,
      'verifyingContract': walletAddress,
    },
    'message': <String, Object>{
      'wallet': walletAddress,
      'nonce': nonce,
      'deadline': deadline,
      'calls': calls.map((c) => c.toJson()).toList(growable: false),
    },
  };
}

const int minWalletBatchDeadlineSeconds = 1800;

/// Returns a deadline string (Unix seconds) for a wallet batch.
///
/// Matches Polygolem `BuildDeadline`: default to now + 30 minutes and clamp
/// shorter caller-provided windows to the relayer-safe minimum.
String defaultBatchDeadline({
  int secondsFromNow = minWalletBatchDeadlineSeconds,
  DateTime? now,
}) {
  final base = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
  final delta = secondsFromNow < minWalletBatchDeadlineSeconds
      ? minWalletBatchDeadlineSeconds
      : secondsFromNow;
  return (base + delta).toString();
}

/// Signs a deposit-wallet batch via [signer]. Returns the 0x-prefixed
/// 65-byte ECDSA signature ready for relayer submission.
Future<String> signWalletBatch({
  required WalletSigner signer,
  required String walletAddress,
  required String nonce,
  required String deadline,
  required List<WalletBatchCall> calls,
}) async {
  if (calls.isEmpty) {
    throw const ValidationException(
      code: ErrorCode.missingField,
      message: 'at least one Call is required',
      field: 'calls',
    );
  }
  if (signer.chainId != _polygonChainId) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'deposit-wallet batch signing requires Polygon chainId=137',
      field: 'chainId',
    );
  }
  final typed = buildWalletBatchTypedData(
    walletAddress: walletAddress,
    nonce: nonce,
    deadline: deadline,
    calls: calls,
    chainId: _polygonChainId,
  );
  final sig = await signer.signTypedData(typed);
  if (sig.length != 65) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'wallet returned ${sig.length}-byte signature (expected 65)',
    );
  }
  return bytesToHex0x(sig);
}

String _strip0x(String s) {
  if (s.startsWith('0x') || s.startsWith('0X')) return s.substring(2);
  return s;
}
