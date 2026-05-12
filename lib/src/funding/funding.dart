/// Wallet-mediated pUSD funding call planners.
///
/// This module builds local transaction/call plans and can read balances via
/// RPC. It performs no signing, relayer submission, or live transfer execution.
library;

import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;

import '../auth/eth_hex.dart'
    show bytesToHex, hexToBytes, leftPadBytes, uint256BigEndian;
import '../contracts/contracts.dart' as contracts;
import '../errors/errors.dart';
import '../relayer/relayer_types.dart';
import '../rpc/rpc.dart' as rpc;
import '../wallet/deposit_wallet_signing.dart' as wallet;

/// Polygon mainnet chain id used by the pUSD funding helpers.
const int polygonChainId = contracts.PolygonChainID;

/// ERC-20 selector for `transfer(address,uint256)`.
const String pusdTransferSelector = 'a9059cbb';

final BigInt _maxUint256 = (BigInt.one << 256) - BigInt.one;

enum PusdFundingRouteStatus { unavailable, partial, ready }

/// EOA wallet transaction request for pUSD funding.
///
/// This is a direct ERC-20 `transfer(depositWallet, amount)` from the EOA to
/// the pUSD contract. It is a local plan only; the Flutter app owns user
/// approval and transaction submission through its wallet provider.
@immutable
final class EoaPusdTransferPlan {
  const EoaPusdTransferPlan._({
    required this.fromAddress,
    required this.depositWallet,
    required this.amountBaseUnits,
    required this.chainId,
    required this.data,
  });

  /// Lowercase 0x-prefixed EOA address.
  final String fromAddress;

  /// Lowercase 0x-prefixed deposit-wallet recipient.
  final String depositWallet;

  /// Raw pUSD base-unit amount.
  final BigInt amountBaseUnits;

  /// Chain id where the transaction must be sent.
  final int chainId;

  /// ERC-20 transfer calldata.
  final String data;

  /// pUSD contract address targeted by the wallet transaction.
  String get tokenAddress => contracts.PUSD;

  /// Native token value. pUSD funding sends no POL with the call.
  String get value => '0x0';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'from': fromAddress,
    'to': tokenAddress,
    'value': value,
    'data': data,
    'chainId': _quantityHex(chainId),
  };
}

/// RPC-backed funding route from EOA-held pUSD into a deposit wallet.
@immutable
final class PusdFundingRoutePlan {
  const PusdFundingRoutePlan._({
    required this.ownerEoa,
    required this.depositWallet,
    required this.eoaPusdBalance,
    required this.requestedAmountBaseUnits,
    required this.transferAmountBaseUnits,
    required this.status,
    required this.transfer,
  });

  final String ownerEoa;
  final String depositWallet;
  final BigInt eoaPusdBalance;
  final BigInt requestedAmountBaseUnits;
  final BigInt transferAmountBaseUnits;
  final PusdFundingRouteStatus status;
  final EoaPusdTransferPlan? transfer;

  bool get canTransfer => transfer != null;

  bool get fullyFunded => status == PusdFundingRouteStatus.ready;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'ownerEoa': ownerEoa,
    'depositWallet': depositWallet,
    'eoaPusdBalance': eoaPusdBalance.toString(),
    'requestedAmountBaseUnits': requestedAmountBaseUnits.toString(),
    'transferAmountBaseUnits': transferAmountBaseUnits.toString(),
    'status': status.name,
    'transfer': transfer?.toJson(),
  };
}

/// A deposit-wallet batch pUSD transfer plan.
///
/// [amountBaseUnits] is the raw ERC-20 base-unit amount and is never converted
/// through decimal floating-point math.
@immutable
final class PusdTransferCallPlan {
  const PusdTransferCallPlan._({
    required this.toAddress,
    required this.amountBaseUnits,
    required this.call,
  });

  /// Lowercase 0x-prefixed recipient address.
  final String toAddress;

  /// Raw pUSD base-unit amount.
  final BigInt amountBaseUnits;

  /// Deposit-wallet call that transfers pUSD when submitted by a batch flow.
  final DepositWalletCall call;

  /// pUSD contract address targeted by [call].
  String get tokenAddress => contracts.PUSD;

  /// Decimal string form of [amountBaseUnits], suitable for JSON surfaces.
  String get amountBaseUnitsString => amountBaseUnits.toString();

  Map<String, dynamic> toJson() => <String, dynamic>{
    'tokenAddress': tokenAddress,
    'toAddress': toAddress,
    'amountBaseUnits': amountBaseUnitsString,
    'call': call.toJson(),
  };
}

/// Builds a pUSD transfer call plan for deposit-wallet batch submission.
PusdTransferCallPlan buildPusdTransferCallPlan({
  required String toAddress,
  required BigInt amountBaseUnits,
}) {
  final recipient = _requireHexAddress(toAddress, 'toAddress');
  _requirePositiveUint256(amountBaseUnits, 'amountBaseUnits');

  final call = DepositWalletCall(
    target: contracts.PUSD,
    value: '0',
    data: _erc20TransferData(
      toAddress: recipient,
      amountBaseUnits: amountBaseUnits,
    ),
  );

  return PusdTransferCallPlan._(
    toAddress: recipient,
    amountBaseUnits: amountBaseUnits,
    call: call,
  );
}

/// Builds the direct EOA wallet transaction that funds a deposit wallet with
/// pUSD.
EoaPusdTransferPlan buildEoaPusdTransferPlan({
  required String ownerEoa,
  required String depositWallet,
  required BigInt amountBaseUnits,
  int chainId = polygonChainId,
}) {
  _requirePolygon(chainId);
  final owner = _requireHexAddress(ownerEoa, 'ownerEoa');
  final wallet = _requireHexAddress(depositWallet, 'depositWallet');
  _requirePositiveUint256(amountBaseUnits, 'amountBaseUnits');

  return EoaPusdTransferPlan._(
    fromAddress: owner,
    depositWallet: wallet,
    amountBaseUnits: amountBaseUnits,
    chainId: chainId,
    data: _erc20TransferData(
      toAddress: wallet,
      amountBaseUnits: amountBaseUnits,
    ),
  );
}

/// Reads EOA pUSD and plans the available transfer into the deposit wallet.
///
/// If the EOA balance is lower than [requestedAmountBaseUnits], the returned
/// route is `partial` and transfers only the available amount. If the balance
/// is zero, no transaction is produced.
Future<PusdFundingRoutePlan> planEoaPusdFundingRoute({
  required String ownerEoa,
  required String depositWallet,
  required BigInt requestedAmountBaseUnits,
  String rpcUrl = rpc.polygonRpc,
  http.Client? rpcClient,
}) async {
  final owner = _requireHexAddress(ownerEoa, 'ownerEoa');
  final wallet = _requireHexAddress(depositWallet, 'depositWallet');
  _requirePositiveUint256(requestedAmountBaseUnits, 'requestedAmountBaseUnits');

  final balance = await rpc.erc20BalanceOf(
    contracts.PUSD,
    owner,
    rpcUrl: rpcUrl,
    client: rpcClient,
  );

  final transferAmount = balance < requestedAmountBaseUnits
      ? balance
      : requestedAmountBaseUnits;
  if (transferAmount == BigInt.zero) {
    return PusdFundingRoutePlan._(
      ownerEoa: owner,
      depositWallet: wallet,
      eoaPusdBalance: balance,
      requestedAmountBaseUnits: requestedAmountBaseUnits,
      transferAmountBaseUnits: BigInt.zero,
      status: PusdFundingRouteStatus.unavailable,
      transfer: null,
    );
  }

  final status = transferAmount == requestedAmountBaseUnits
      ? PusdFundingRouteStatus.ready
      : PusdFundingRouteStatus.partial;
  return PusdFundingRoutePlan._(
    ownerEoa: owner,
    depositWallet: wallet,
    eoaPusdBalance: balance,
    requestedAmountBaseUnits: requestedAmountBaseUnits,
    transferAmountBaseUnits: transferAmount,
    status: status,
    transfer: buildEoaPusdTransferPlan(
      ownerEoa: owner,
      depositWallet: wallet,
      amountBaseUnits: transferAmount,
    ),
  );
}

/// Builds only the [DepositWalletCall] from [buildPusdTransferCallPlan].
DepositWalletCall buildPusdTransferCall({
  required String toAddress,
  required BigInt amountBaseUnits,
}) {
  return buildPusdTransferCallPlan(
    toAddress: toAddress,
    amountBaseUnits: amountBaseUnits,
  ).call;
}

/// Builds DepositWallet.Batch typed data for a planned pUSD transfer.
///
/// The returned map is intended for wallet-provider signing flows and is
/// produced by the existing deposit-wallet batch helper.
Map<String, dynamic> buildPusdTransferBatchTypedData({
  required String depositWallet,
  required String nonce,
  required String deadline,
  required PusdTransferCallPlan transfer,
  int chainId = polygonChainId,
}) {
  _requirePolygon(chainId);
  final walletAddress = _requireNonEmpty(
    depositWallet,
    'depositWallet',
    'deposit wallet is required',
  );
  final walletNonce = _requireNonEmpty(
    nonce,
    'nonce',
    'wallet nonce is required',
  );
  final walletDeadline = _requireNonEmpty(
    deadline,
    'deadline',
    'transfer deadline is required',
  );

  return wallet.buildWalletBatchTypedData(
    walletAddress: walletAddress,
    nonce: walletNonce,
    deadline: walletDeadline,
    calls: <wallet.WalletBatchCall>[transfer.call.toBatchCall()],
    chainId: chainId,
  );
}

String _erc20TransferData({
  required String toAddress,
  required BigInt amountBaseUnits,
}) {
  final recipient = bytesToHex(
    leftPadBytes(hexToBytes(_strip0x(toAddress)), length: 32),
  );
  final amount = bytesToHex(uint256BigEndian(amountBaseUnits));
  return '0x$pusdTransferSelector$recipient$amount';
}

String _quantityHex(int value) {
  if (value < 0) {
    throw const ValidationException(
      code: ErrorCode.invalidValue,
      message: 'quantity must be non-negative',
    );
  }
  return '0x${value.toRadixString(16)}';
}

String _requireHexAddress(String address, String field) {
  final trimmed = address.trim();
  if (trimmed.isEmpty) {
    throw ValidationException(
      code: ErrorCode.missingField,
      message: '$field is required',
      field: field,
    );
  }
  final clean = _strip0x(trimmed);
  if (clean.length != 40 || !_hexAddressPattern.hasMatch(clean)) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: '$field must be a 20-byte hex address',
      field: field,
    );
  }
  return '0x${clean.toLowerCase()}';
}

void _requirePositiveUint256(BigInt value, String field) {
  if (value <= BigInt.zero) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: '$field must be positive',
      field: field,
    );
  }
  if (value > _maxUint256) {
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: '$field exceeds uint256',
      field: field,
    );
  }
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

String _requireNonEmpty(String value, String field, String message) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ValidationException(
      code: ErrorCode.missingField,
      message: message,
      field: field,
    );
  }
  return trimmed;
}

String _strip0x(String value) {
  if (value.startsWith('0x') || value.startsWith('0X')) {
    return value.substring(2);
  }
  return value;
}

final RegExp _hexAddressPattern = RegExp(r'^[0-9a-fA-F]{40}$');
