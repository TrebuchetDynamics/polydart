/// Read-only settlement helpers for redeemable Polymarket CTF positions.
///
/// This module finds Data API positions marked redeemable, builds deposit
/// wallet calls for adapter redemption, and checks settlement readiness. It
/// does not sign, submit, approve, or relay transactions.
library;

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../contracts/contracts.dart' as contracts;
import '../ctf/ctf.dart' as ctf;
import '../dataapi/dataapi_client.dart';
import '../dataapi/dataapi_types.dart';
import '../relayer/relayer_types.dart';
import '../rpc/rpc.dart' as rpc;

/// Caps the number of redeem calls per planned deposit-wallet batch.
const int defaultBatchLimit = 10;

const String settlementStatusReady = 'ready';
const String settlementStatusDepositWalletNotDeployed =
    'deposit_wallet_not_deployed';
const String settlementStatusMissingRelayerCredentials =
    'missing_relayer_credentials';
const String settlementStatusMissingAdapterApproval =
    'missing_adapter_approval';
const String settlementStatusDataApiUnavailable = 'data_api_unavailable';
const String settlementStatusRpcError = 'rpc_error';

const String _addressZero = '0x0000000000000000000000000000000000000000';

/// Minimal position fields needed to plan a redeem call.
@immutable
final class RedeemablePosition {
  const RedeemablePosition({
    required this.tokenId,
    required this.conditionId,
    required this.size,
    required this.outcome,
    this.negativeRisk = false,
    this.endDate = '',
    this.title = '',
    this.slug = '',
  });

  final String tokenId;
  final String conditionId;
  final double size;
  final String outcome;
  final bool negativeRisk;
  final String endDate;
  final String title;
  final String slug;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'tokenID': tokenId,
    'conditionID': conditionId,
    'size': size,
    'outcome': outcome,
    'negativeRisk': negativeRisk,
    'endDate': endDate,
    'title': title,
    'slug': slug,
  };
}

/// Summary shape for callers that later submit planned redeem batches.
///
/// Polydart intentionally does not expose private-key redeem submission in
/// this read-only settlement slice.
@immutable
final class RedeemResult {
  const RedeemResult({
    required this.transactionId,
    required this.state,
    required this.wallet,
    required this.nonce,
    required this.deadline,
    required this.callCount,
    required this.redeemed,
  });

  final String transactionId;
  final String state;
  final String wallet;
  final String nonce;
  final String deadline;
  final int callCount;
  final List<RedeemablePosition> redeemed;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'transactionID': transactionId,
    'state': state,
    'wallet': wallet,
    'nonce': nonce,
    'deadline': deadline,
    'callCount': callCount,
    'redeemed': redeemed.map((p) => p.toJson()).toList(growable: false),
  };
}

/// Read seam for user-scoped settlement positions.
abstract interface class SettlementDataReader {
  Future<List<Position>> currentPositions(String owner);
}

/// Adapter that lets [DataApiClient] satisfy [SettlementDataReader].
final class DataApiSettlementReader implements SettlementDataReader {
  const DataApiSettlementReader(this.client);

  final DataApiClient client;

  @override
  Future<List<Position>> currentPositions(String owner) {
    return client.currentPositions(owner);
  }
}

/// Returns Data API current positions where `redeemable=true`.
Future<List<RedeemablePosition>> findRedeemable(
  SettlementDataReader reader,
  String owner,
) async {
  final rows = await reader.currentPositions(owner);
  return <RedeemablePosition>[
    for (final p in rows)
      if (p.redeemable) _redeemableFromPosition(p),
  ];
}

/// Builds a deposit-wallet call for
/// `redeemPositions(address(0), bytes32(0), conditionId, [])`.
DepositWalletCall buildRedeemCall(RedeemablePosition position) {
  if (position.conditionId.trim().isEmpty) {
    throw ArgumentError.value(
      position.conditionId,
      'position.conditionId',
      'condition ID is required',
    );
  }

  return DepositWalletCall(
    target: contracts.redeemAdapterFor(position.negativeRisk),
    value: '0',
    data: ctf.redeemPositionsData(
      collateralToken: _addressZero,
      parentCollectionId: ctf.bytes32Zero,
      conditionId: position.conditionId,
      indexSets: const <BigInt>[],
    ),
  );
}

/// Collapses duplicate condition IDs, preserving first occurrence.
///
/// Empty condition IDs are skipped because no redeem calldata can be built.
List<RedeemablePosition> dedupeRedeemPositionsByCondition(
  Iterable<RedeemablePosition> positions,
) {
  final seen = <String>{};
  final out = <RedeemablePosition>[];
  for (final position in positions) {
    final conditionId = position.conditionId.trim();
    if (conditionId.isEmpty || seen.contains(conditionId)) {
      continue;
    }
    seen.add(conditionId);
    out.add(position);
  }
  return List<RedeemablePosition>.unmodifiable(out);
}

/// Dedupes positions by condition and splits them into planned batch chunks.
List<List<RedeemablePosition>> chunkRedeemPositionsByCondition(
  Iterable<RedeemablePosition> positions, {
  int limit = defaultBatchLimit,
}) {
  final effectiveLimit = limit > 0 ? limit : defaultBatchLimit;
  final deduped = dedupeRedeemPositionsByCondition(positions);
  final chunks = <List<RedeemablePosition>>[];
  for (var i = 0; i < deduped.length; i += effectiveLimit) {
    final end = i + effectiveLimit > deduped.length
        ? deduped.length
        : i + effectiveLimit;
    chunks.add(List<RedeemablePosition>.unmodifiable(deduped.sublist(i, end)));
  }
  return List<List<RedeemablePosition>>.unmodifiable(chunks);
}

/// One required adapter approval status.
@immutable
final class SettlementAdapterApproval {
  const SettlementAdapterApproval({
    required this.adapter,
    required this.approved,
  });

  final String adapter;
  final bool approved;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'adapter': adapter,
    'approved': approved,
  };
}

/// Read-only settlement readiness result.
@immutable
final class SettlementReadiness {
  const SettlementReadiness({
    required this.ready,
    required this.status,
    required this.depositWallet,
    required this.depositWalletDeployed,
    required this.relayerConfigured,
    required this.requiredAdapters,
    required this.adapterApprovals,
    required this.missingApprovals,
    this.owner = '',
    this.redeemableCount = 0,
    this.redeemablePositions = const <RedeemablePosition>[],
    this.reason = '',
    this.nextAction = '',
  });

  final bool ready;
  final String status;
  final String owner;
  final String depositWallet;
  final bool depositWalletDeployed;
  final bool relayerConfigured;
  final List<String> requiredAdapters;
  final List<SettlementAdapterApproval> adapterApprovals;
  final List<String> missingApprovals;
  final int redeemableCount;
  final List<RedeemablePosition> redeemablePositions;
  final String reason;
  final String nextAction;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'ready': ready,
    'status': status,
    if (owner.isNotEmpty) 'owner': owner,
    'depositWallet': depositWallet,
    'depositWalletDeployed': depositWalletDeployed,
    'relayerConfigured': relayerConfigured,
    'requiredAdapters': requiredAdapters,
    'adapterApprovals': adapterApprovals
        .map((a) => a.toJson())
        .toList(growable: false),
    if (missingApprovals.isNotEmpty) 'missingApprovals': missingApprovals,
    'redeemableCount': redeemableCount,
    if (redeemablePositions.isNotEmpty)
      'redeemablePositions': redeemablePositions
          .map((p) => p.toJson())
          .toList(growable: false),
    if (reason.isNotEmpty) 'reason': reason,
    if (nextAction.isNotEmpty) 'nextAction': nextAction,
  };
}

/// Returns the V2 collateral adapters required for settlement readiness.
List<String> requiredSettlementAdapters() {
  return const <String>[
    contracts.CtfCollateralAdapter,
    contracts.NegRiskCtfCollateralAdapter,
  ];
}

/// Checks settlement readiness without signing or submitting anything.
///
/// [reader] is optional; when omitted, redeemable position discovery is skipped.
Future<SettlementReadiness> checkReadiness({
  required String depositWallet,
  String owner = '',
  SettlementDataReader? reader,
  bool relayerConfigured = false,
  String rpcUrl = rpc.polygonRpc,
  http.Client? httpClient,
}) async {
  final wallet = depositWallet.trim();
  if (wallet.isEmpty) {
    throw ArgumentError.value(depositWallet, 'depositWallet', 'is required');
  }

  final requiredAdapters = requiredSettlementAdapters();

  bool deployed;
  try {
    deployed = await rpc.hasCode(wallet, rpcUrl: rpcUrl, client: httpClient);
  } catch (e) {
    return _readiness(
      status: settlementStatusRpcError,
      owner: owner,
      depositWallet: wallet,
      relayerConfigured: relayerConfigured,
      requiredAdapters: requiredAdapters,
      reason: 'RPC code check failed: $e',
      nextAction: 'Check the Polygon RPC URL and retry.',
    );
  }

  if (!deployed) {
    return _readiness(
      status: settlementStatusDepositWalletNotDeployed,
      owner: owner,
      depositWallet: wallet,
      depositWalletDeployed: false,
      relayerConfigured: relayerConfigured,
      requiredAdapters: requiredAdapters,
      reason: 'Deposit wallet has no bytecode on Polygon.',
      nextAction: 'Deploy the deposit wallet before planning settlement.',
    );
  }

  var redeemablePositions = const <RedeemablePosition>[];
  if (reader != null) {
    try {
      redeemablePositions = await findRedeemable(
        reader,
        _settlementPositionOwner(owner: owner, depositWallet: wallet),
      );
    } catch (e) {
      return _readiness(
        status: settlementStatusDataApiUnavailable,
        owner: owner,
        depositWallet: wallet,
        depositWalletDeployed: true,
        relayerConfigured: relayerConfigured,
        requiredAdapters: requiredAdapters,
        reason: 'Data API position lookup failed: $e',
        nextAction: 'Restore Data API access before checking settlement.',
      );
    }
  }

  final approvals = <SettlementAdapterApproval>[];
  final missingApprovals = <String>[];
  for (final adapter in requiredAdapters) {
    final approved = await _approvedForAll(
      wallet,
      adapter,
      rpcUrl: rpcUrl,
      httpClient: httpClient,
    );
    if (approved == null) {
      return _readiness(
        status: settlementStatusRpcError,
        owner: owner,
        depositWallet: wallet,
        depositWalletDeployed: true,
        relayerConfigured: relayerConfigured,
        requiredAdapters: requiredAdapters,
        redeemablePositions: redeemablePositions,
        reason: 'RPC approval check failed.',
        nextAction: 'Check the Polygon RPC URL and retry.',
      );
    }
    approvals.add(
      SettlementAdapterApproval(adapter: adapter, approved: approved),
    );
    if (!approved) {
      missingApprovals.add(adapter);
    }
  }

  if (!relayerConfigured) {
    return _readiness(
      status: settlementStatusMissingRelayerCredentials,
      owner: owner,
      depositWallet: wallet,
      depositWalletDeployed: true,
      relayerConfigured: false,
      requiredAdapters: requiredAdapters,
      adapterApprovals: approvals,
      missingApprovals: missingApprovals,
      redeemablePositions: redeemablePositions,
      reason: 'Relayer credentials are not configured.',
      nextAction: 'Configure relayer credentials before live settlement.',
    );
  }

  if (missingApprovals.isNotEmpty) {
    return _readiness(
      status: settlementStatusMissingAdapterApproval,
      owner: owner,
      depositWallet: wallet,
      depositWalletDeployed: true,
      relayerConfigured: true,
      requiredAdapters: requiredAdapters,
      adapterApprovals: approvals,
      missingApprovals: missingApprovals,
      redeemablePositions: redeemablePositions,
      reason: 'Deposit wallet is missing required adapter approval.',
      nextAction: 'Approve the required adapters before live settlement.',
    );
  }

  return _readiness(
    ready: true,
    status: settlementStatusReady,
    owner: owner,
    depositWallet: wallet,
    depositWalletDeployed: true,
    relayerConfigured: true,
    requiredAdapters: requiredAdapters,
    adapterApprovals: approvals,
    redeemablePositions: redeemablePositions,
  );
}

String _settlementPositionOwner({
  required String owner,
  required String depositWallet,
}) {
  final trimmedOwner = owner.trim();
  return trimmedOwner.isNotEmpty ? trimmedOwner : depositWallet;
}

RedeemablePosition _redeemableFromPosition(Position p) {
  return RedeemablePosition(
    tokenId: p.tokenId,
    conditionId: p.conditionId,
    size: p.size,
    outcome: p.outcome,
    negativeRisk: p.negativeRisk,
    endDate: p.endDate,
    title: p.title,
    slug: p.slug,
  );
}

Future<bool?> _approvedForAll(
  String wallet,
  String adapter, {
  required String rpcUrl,
  required http.Client? httpClient,
}) async {
  try {
    return await rpc.isApprovedForAll(
      contracts.CTF,
      wallet,
      adapter,
      rpcUrl: rpcUrl,
      client: httpClient,
    );
  } catch (_) {
    return null;
  }
}

SettlementReadiness _readiness({
  bool ready = false,
  required String status,
  String owner = '',
  required String depositWallet,
  bool depositWalletDeployed = false,
  required bool relayerConfigured,
  required List<String> requiredAdapters,
  List<SettlementAdapterApproval> adapterApprovals =
      const <SettlementAdapterApproval>[],
  List<String> missingApprovals = const <String>[],
  List<RedeemablePosition> redeemablePositions = const <RedeemablePosition>[],
  String reason = '',
  String nextAction = '',
}) {
  return SettlementReadiness(
    ready: ready,
    status: status,
    owner: owner.trim(),
    depositWallet: depositWallet,
    depositWalletDeployed: depositWalletDeployed,
    relayerConfigured: relayerConfigured,
    requiredAdapters: List<String>.unmodifiable(requiredAdapters),
    adapterApprovals: List<SettlementAdapterApproval>.unmodifiable(
      adapterApprovals,
    ),
    missingApprovals: List<String>.unmodifiable(missingApprovals),
    redeemableCount: redeemablePositions.length,
    redeemablePositions: List<RedeemablePosition>.unmodifiable(
      redeemablePositions,
    ),
    reason: reason,
    nextAction: nextAction,
  );
}
