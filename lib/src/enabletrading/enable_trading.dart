/// Wallet-mediated planning helpers for the Polymarket "Enable Trading" flow.
///
/// This module builds the typed-data envelopes and approval calls a consumer
/// app can present through its wallet provider. It performs no network I/O and
/// does not submit approvals.
library;

import '../auth/clob_auth.dart' as clob;
import '../auth/eth_hex.dart';
import '../auth/wallet_signer.dart';
import '../contracts/contracts.dart' as contracts;
import '../errors/errors.dart';
import '../relayer/relayer_types.dart';
import '../wallet/deposit_wallet_signing.dart' as wallet;

/// Polygon mainnet chain id used by Polymarket.
const int polygonChainId = contracts.PolygonChainID;

/// CLOB L1 auth control message used by Polymarket.
const String clobAuthControlMessage =
    'This message attests that I control the given wallet';

const String _approveSelector = '095ea7b3';
const String _maxUint256 =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

/// Builds the ClobAuth EIP-712 typed-data payload for wallet signing.
Map<String, dynamic> buildEnableTradingClobAuthTypedData({
  required String address,
  required int timestamp,
  int nonce = 0,
  int chainId = polygonChainId,
}) {
  _requirePolygon(chainId);
  if (address.trim().isEmpty) {
    throw const ValidationException(
      code: ErrorCode.missingField,
      message: 'ClobAuth address is required',
      field: 'address',
    );
  }
  return clob.buildClobAuthTypedData(
    address: address.trim(),
    chainId: chainId,
    timestamp: timestamp,
    nonce: nonce,
    message: clobAuthControlMessage,
  );
}

/// Asks [signer] to sign the Enable Trading ClobAuth typed-data payload.
Future<String> signEnableTradingClobAuthTypedData({
  required WalletSigner signer,
  required int timestamp,
  int nonce = 0,
}) async {
  _requirePolygon(signer.chainId);
  final typedData = buildEnableTradingClobAuthTypedData(
    address: signer.address,
    timestamp: timestamp,
    nonce: nonce,
    chainId: signer.chainId,
  );
  final signature = await signer.signTypedData(typedData);
  _requireSignatureLength(signature.length);
  return bytesToHex0x(signature);
}

/// Builds the two observed wallet UI ERC-20 approvals for Enable Trading.
///
/// The calls approve max `pUSD -> CTF` and max `USDC.e -> CollateralOnramp`
/// from the user's deposit wallet. They are only call plans; callers decide
/// whether and how to request wallet approval.
List<DepositWalletCall> buildEnableTradingApprovalCalls() {
  return const <DepositWalletCall>[
    DepositWalletCall(
      target: contracts.PUSD,
      value: '0',
      data:
          '0x$_approveSelector'
          '0000000000000000000000004d97dcd97ec945f40cf65f87097ace5ea0476045'
          '$_maxUint256',
    ),
    DepositWalletCall(
      target: contracts.USDCE,
      value: '0',
      data:
          '0x$_approveSelector'
          '00000000000000000000000093070a847efef7f70739046a929d47a521f5b8ee'
          '$_maxUint256',
    ),
  ];
}

/// Validates that [calls] exactly match the Enable Trading approval plan.
void validateEnableTradingApprovalCalls(List<DepositWalletCall> calls) {
  if (calls.length != 2) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'expected 2 approval calls, got ${calls.length}',
      field: 'calls',
    );
  }
  _validateApprovalCall(
    calls[0],
    index: 0,
    target: contracts.PUSD,
    spender: contracts.CTF,
  );
  _validateApprovalCall(
    calls[1],
    index: 1,
    target: contracts.USDCE,
    spender: contracts.CollateralOnramp,
  );
}

/// Builds DepositWallet.Batch typed data for the Enable Trading approvals.
Map<String, dynamic> buildEnableTradingApprovalBatchTypedData({
  required String depositWallet,
  required String nonce,
  required String deadline,
  required List<DepositWalletCall> calls,
  int chainId = polygonChainId,
}) {
  _requirePolygon(chainId);
  if (depositWallet.trim().isEmpty) {
    throw const ValidationException(
      code: ErrorCode.missingField,
      message: 'deposit wallet is required',
      field: 'depositWallet',
    );
  }
  if (nonce.trim().isEmpty) {
    throw const ValidationException(
      code: ErrorCode.missingField,
      message: 'wallet nonce is required',
      field: 'nonce',
    );
  }
  if (deadline.trim().isEmpty) {
    throw const ValidationException(
      code: ErrorCode.missingField,
      message: 'approval deadline is required',
      field: 'deadline',
    );
  }
  validateEnableTradingApprovalCalls(calls);
  return wallet.buildWalletBatchTypedData(
    walletAddress: depositWallet.trim(),
    nonce: nonce.trim(),
    deadline: deadline.trim(),
    calls: calls.map((c) => c.toBatchCall()).toList(growable: false),
    chainId: chainId,
  );
}

/// Asks [signer] to sign the Enable Trading DepositWallet.Batch payload.
Future<String> signEnableTradingApprovalBatchTypedData({
  required WalletSigner signer,
  required String depositWallet,
  required String nonce,
  required String deadline,
  required List<DepositWalletCall> calls,
}) async {
  _requirePolygon(signer.chainId);
  final typedData = buildEnableTradingApprovalBatchTypedData(
    depositWallet: depositWallet,
    nonce: nonce,
    deadline: deadline,
    calls: calls,
    chainId: signer.chainId,
  );
  final signature = await signer.signTypedData(typedData);
  _requireSignatureLength(signature.length);
  return bytesToHex0x(signature);
}

void _requirePolygon(int chainId) {
  if (chainId != polygonChainId) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'chainId must be $polygonChainId, got $chainId',
      field: 'chainId',
    );
  }
}

void _requireSignatureLength(int length) {
  if (length != 65) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'wallet returned $length-byte signature (expected 65)',
    );
  }
}

void _validateApprovalCall(
  DepositWalletCall call, {
  required int index,
  required String target,
  required String spender,
}) {
  if (!_sameHexAddress(call.target, target)) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'approval call $index target is not allowed',
      field: 'calls[$index].target',
    );
  }
  if (call.value.trim() != '0') {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'approval call $index value must be 0',
      field: 'calls[$index].value',
    );
  }
  _validateApproveCalldata(call.data, spender, index);
}

void _validateApproveCalldata(String data, String spender, int index) {
  final clean = _strip0x(data.trim()).toLowerCase();
  if (clean.length != 8 + 64 + 64) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'approval call $index calldata has invalid length',
      field: 'calls[$index].data',
    );
  }
  if (!clean.startsWith(_approveSelector)) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'approval call $index calldata is not ERC20 approve',
      field: 'calls[$index].data',
    );
  }
  final spenderWord = clean.substring(8, 8 + 64);
  final actualSpender = '0x${spenderWord.substring(24)}';
  if (!_sameHexAddress(actualSpender, spender)) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'approval call $index spender is not allowed',
      field: 'calls[$index].data',
    );
  }
  if (clean.substring(8 + 64) != _maxUint256) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'approval call $index amount must be max uint256',
      field: 'calls[$index].data',
    );
  }
}

bool _sameHexAddress(String a, String b) =>
    _strip0x(a).toLowerCase() == _strip0x(b).toLowerCase();

String _strip0x(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
    return trimmed.substring(2);
  }
  return trimmed;
}
