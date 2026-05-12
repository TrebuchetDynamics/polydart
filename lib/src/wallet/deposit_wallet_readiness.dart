/// Deposit-wallet readiness orchestration.
///
/// Product-facing wrapper over the low-level CREATE2 and relayer clients.
/// Keep UI copy and credential storage in the consumer; this module returns
/// machine-readable protocol state only.
library;

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../auth/create2.dart';
import '../auth/eth_hex.dart';
import '../auth/l2.dart';
import '../clob/clob_auth_types.dart';
import '../clob/clob_client.dart';
import '../credentials/live_credentials.dart';
import '../relayer/approvals.dart' as approvals;
import '../relayer/relayer_client.dart';
import '../rpc/rpc.dart' as rpc;
import '../transport/http_transport.dart';

const List<String> _requiredApprovalLabels = <String>[
  'pusd:ctfExchangeV2',
  'ctf:ctfExchangeV2',
  'pusd:negRiskExchangeV2',
  'ctf:negRiskExchangeV2',
  'pusd:negRiskAdapterV2',
  'ctf:negRiskAdapterV2',
];

enum DepositWalletReadinessStatus {
  needsDeploy,
  needsApprovalCheck,
  needsApproval,
  needsFunding,
  ready,
  blocked,
}

enum DepositWalletApprovalKind { erc20Allowance, erc1155ApprovalForAll }

enum DepositWalletFundingConfirmationStatus {
  transactionPending,
  transactionFailed,
  needsDeploy,
  needsApprovalCheck,
  needsApproval,
  needsFunding,
  ready,
  blocked,
}

@immutable
final class DepositWalletApprovalCheck {
  const DepositWalletApprovalCheck({
    required this.label,
    required this.kind,
    required this.token,
    required this.spender,
    required this.ready,
    required this.value,
  });

  final String label;
  final DepositWalletApprovalKind kind;
  final String token;
  final String spender;
  final bool ready;
  final String value;
}

@immutable
final class DepositWalletReadiness {
  DepositWalletReadiness({
    required this.status,
    required this.ownerEoa,
    required this.depositWallet,
    required this.deployed,
    this.approvalsChecked = false,
    this.fundingChecked = false,
    this.credentialsReady = true,
    this.reason = '',
    this.clobBalance = '',
    Map<String, String> clobAllowances = const <String, String>{},
    List<DepositWalletApprovalCheck> approvalChecks =
        const <DepositWalletApprovalCheck>[],
    List<String> missingApprovals = const <String>[],
    List<String> requiredApprovals = const <String>[],
  }) : clobAllowances = Map.unmodifiable(clobAllowances),
       approvalChecks = List.unmodifiable(approvalChecks),
       missingApprovals = List.unmodifiable(missingApprovals),
       requiredApprovals = List.unmodifiable(requiredApprovals);

  final DepositWalletReadinessStatus status;
  final String ownerEoa;
  final String depositWallet;
  final bool deployed;
  final bool approvalsChecked;
  final bool fundingChecked;
  final bool credentialsReady;
  final String reason;
  final String clobBalance;
  final Map<String, String> clobAllowances;
  final List<DepositWalletApprovalCheck> approvalChecks;
  final List<String> missingApprovals;
  final List<String> requiredApprovals;
}

@immutable
final class DepositWalletFundingConfirmation {
  const DepositWalletFundingConfirmation({
    required this.status,
    required this.ownerEoa,
    required this.depositWallet,
    required this.transactionHash,
    required this.transactionConfirmed,
    required this.transactionFailed,
    required this.transactionAttempts,
    required this.readinessAttempts,
    required this.readiness,
    this.reason = '',
  });

  final DepositWalletFundingConfirmationStatus status;
  final String ownerEoa;
  final String depositWallet;
  final String? transactionHash;
  final bool transactionConfirmed;
  final bool transactionFailed;
  final int transactionAttempts;
  final int readinessAttempts;
  final DepositWalletReadiness readiness;
  final String reason;

  bool get ready => status == DepositWalletFundingConfirmationStatus.ready;
}

final class DepositWalletReadinessService {
  const DepositWalletReadinessService({required RelayerClient relayer})
    : _relayer = relayer;

  final RelayerClient _relayer;

  static Future<DepositWalletReadiness> checkWithCredentials({
    required String eoaAddress,
    required LiveCredentialReadiness credentials,
    HttpTransport? relayerTransport,
    ClobClient? clob,
    String rpcUrl = rpc.polygonRpc,
    http.Client? rpcClient,
    int chainId = 137,
  }) async {
    final owner = normalizeAddress(eoaAddress);
    final depositWallet = deriveDepositWallet(owner);
    final relayerApiKey = credentials.relayerApiKey.value;
    if (!_hasCompleteLiveCredentials(credentials) || relayerApiKey == null) {
      return DepositWalletReadiness(
        status: DepositWalletReadinessStatus.blocked,
        ownerEoa: owner,
        depositWallet: depositWallet,
        deployed: false,
        credentialsReady: false,
        reason: _credentialBlockReason(credentials),
      );
    }

    final relayer = RelayerClient.v2(
      apiKey: relayerApiKey,
      chainId: chainId,
      transport: relayerTransport,
    );
    try {
      final deployed = await DepositWalletReadinessService(
        relayer: relayer,
      ).check(owner);
      if (deployed.status != DepositWalletReadinessStatus.needsApprovalCheck ||
          clob == null) {
        return deployed;
      }
      return _checkApprovalAndFunding(
        owner: owner,
        depositWallet: deployed.depositWallet,
        clob: clob,
        clobApiKey: credentials.clobApiKey.value!,
        rpcUrl: rpcUrl,
        rpcClient: rpcClient,
      );
    } finally {
      if (relayerTransport == null) {
        relayer.close();
      }
    }
  }

  Future<DepositWalletReadiness> check(String eoaAddress) async {
    final owner = normalizeAddress(eoaAddress);
    final depositWallet = deriveDepositWallet(owner);
    final deployed = await _relayer.isDeployed(ownerAddress: owner);

    if (!deployed.deployed) {
      return DepositWalletReadiness(
        status: DepositWalletReadinessStatus.needsDeploy,
        ownerEoa: owner,
        depositWallet: depositWallet,
        deployed: false,
      );
    }

    return DepositWalletReadiness(
      status: DepositWalletReadinessStatus.needsApprovalCheck,
      ownerEoa: owner,
      depositWallet: depositWallet,
      deployed: true,
      requiredApprovals: _requiredApprovalLabels,
    );
  }
}

/// Waits for an app-submitted pUSD funding transaction, then refreshes
/// deposit-wallet readiness until CLOB collateral is usable or action is
/// still required.
///
/// The Flutter app owns wallet approval and transaction submission. This
/// helper only polls public RPC/CLOB/relayer state.
Future<DepositWalletFundingConfirmation> waitForDepositWalletFundingReadiness({
  required String eoaAddress,
  required LiveCredentialReadiness credentials,
  required ClobClient clob,
  String? transactionHash,
  HttpTransport? relayerTransport,
  String rpcUrl = rpc.polygonRpc,
  http.Client? rpcClient,
  int chainId = 137,
  int maxAttempts = 20,
  Duration pollInterval = const Duration(seconds: 3),
  Future<void> Function(Duration duration)? delay,
}) async {
  if (maxAttempts < 1) {
    throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be positive');
  }
  final owner = normalizeAddress(eoaAddress);
  final depositWallet = deriveDepositWallet(owner);
  final txHash = _normalizeOptionalTransactionHash(transactionHash);
  final wait = delay ?? Future<void>.delayed;
  var transactionAttempts = 0;
  var transactionConfirmed = txHash == null;

  Future<DepositWalletReadiness> refreshReadiness() {
    return DepositWalletReadinessService.checkWithCredentials(
      eoaAddress: owner,
      credentials: credentials,
      relayerTransport: relayerTransport,
      clob: clob,
      rpcUrl: rpcUrl,
      rpcClient: rpcClient,
      chainId: chainId,
    );
  }

  if (txHash != null) {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      transactionAttempts = attempt;
      final receipt = await rpc.transactionReceipt(
        txHash,
        rpcUrl: rpcUrl,
        client: rpcClient,
      );
      if (receipt == null) {
        if (attempt < maxAttempts) await wait(pollInterval);
        continue;
      }
      if (receipt.failed) {
        final readiness = await refreshReadiness();
        return DepositWalletFundingConfirmation(
          status: DepositWalletFundingConfirmationStatus.transactionFailed,
          ownerEoa: owner,
          depositWallet: depositWallet,
          transactionHash: txHash,
          transactionConfirmed: true,
          transactionFailed: true,
          transactionAttempts: transactionAttempts,
          readinessAttempts: 1,
          readiness: readiness,
          reason: 'Wallet funding transaction reverted.',
        );
      }
      if (receipt.succeeded) {
        transactionConfirmed = true;
        break;
      }
      if (attempt < maxAttempts) await wait(pollInterval);
    }

    if (!transactionConfirmed) {
      final readiness = await refreshReadiness();
      return DepositWalletFundingConfirmation(
        status: DepositWalletFundingConfirmationStatus.transactionPending,
        ownerEoa: owner,
        depositWallet: depositWallet,
        transactionHash: txHash,
        transactionConfirmed: false,
        transactionFailed: false,
        transactionAttempts: transactionAttempts,
        readinessAttempts: 1,
        readiness: readiness,
        reason: 'Wallet funding transaction is still pending.',
      );
    }
  }

  var readinessAttempts = 0;
  late DepositWalletReadiness readiness;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    readinessAttempts = attempt;
    readiness = await refreshReadiness();
    if (readiness.status != DepositWalletReadinessStatus.needsFunding) {
      return DepositWalletFundingConfirmation(
        status: _fundingConfirmationStatus(readiness.status),
        ownerEoa: owner,
        depositWallet: depositWallet,
        transactionHash: txHash,
        transactionConfirmed: transactionConfirmed,
        transactionFailed: false,
        transactionAttempts: transactionAttempts,
        readinessAttempts: readinessAttempts,
        readiness: readiness,
        reason: readiness.reason,
      );
    }
    if (attempt < maxAttempts) await wait(pollInterval);
  }

  return DepositWalletFundingConfirmation(
    status: DepositWalletFundingConfirmationStatus.needsFunding,
    ownerEoa: owner,
    depositWallet: depositWallet,
    transactionHash: txHash,
    transactionConfirmed: transactionConfirmed,
    transactionFailed: false,
    transactionAttempts: transactionAttempts,
    readinessAttempts: readinessAttempts,
    readiness: readiness,
    reason: 'Deposit-wallet collateral is not ready yet.',
  );
}

Future<DepositWalletReadiness> _checkApprovalAndFunding({
  required String owner,
  required String depositWallet,
  required ClobClient clob,
  required ApiKey clobApiKey,
  required String rpcUrl,
  required http.Client? rpcClient,
}) async {
  final approvalChecks = await _checkApprovals(
    depositWallet: depositWallet,
    rpcUrl: rpcUrl,
    rpcClient: rpcClient,
  );
  final missingApprovals = approvalChecks
      .where((check) => !check.ready)
      .map((check) => check.label)
      .toList(growable: false);
  final balanceAllowance = await clob.balanceAllowance(
    apiKey: clobApiKey,
    params: const BalanceAllowanceParams(
      assetType: 'COLLATERAL',
      signatureType: 3,
    ),
  );
  final balance = _parseUint(balanceAllowance.balance);

  final DepositWalletReadinessStatus status;
  if (missingApprovals.isNotEmpty) {
    status = DepositWalletReadinessStatus.needsApproval;
  } else if (balance == BigInt.zero) {
    status = DepositWalletReadinessStatus.needsFunding;
  } else {
    status = DepositWalletReadinessStatus.ready;
  }

  return DepositWalletReadiness(
    status: status,
    ownerEoa: owner,
    depositWallet: depositWallet,
    deployed: true,
    approvalsChecked: true,
    fundingChecked: true,
    requiredApprovals: _requiredApprovalLabels,
    approvalChecks: approvalChecks,
    missingApprovals: missingApprovals,
    clobBalance: balanceAllowance.balance,
    clobAllowances: balanceAllowance.allowances,
  );
}

Future<List<DepositWalletApprovalCheck>> _checkApprovals({
  required String depositWallet,
  required String rpcUrl,
  required http.Client? rpcClient,
}) async {
  final checks = <DepositWalletApprovalCheck>[];
  for (final spec in _approvalSpecs) {
    switch (spec.kind) {
      case DepositWalletApprovalKind.erc20Allowance:
        final allowance = await rpc.erc20Allowance(
          spec.token,
          depositWallet,
          spec.spender,
          rpcUrl: rpcUrl,
          client: rpcClient,
        );
        checks.add(
          DepositWalletApprovalCheck(
            label: spec.label,
            kind: spec.kind,
            token: spec.token,
            spender: spec.spender,
            ready: allowance > BigInt.zero,
            value: allowance.toString(),
          ),
        );
      case DepositWalletApprovalKind.erc1155ApprovalForAll:
        final approved = await rpc.isApprovedForAll(
          spec.token,
          depositWallet,
          spec.spender,
          rpcUrl: rpcUrl,
          client: rpcClient,
        );
        checks.add(
          DepositWalletApprovalCheck(
            label: spec.label,
            kind: spec.kind,
            token: spec.token,
            spender: spec.spender,
            ready: approved,
            value: approved.toString(),
          ),
        );
    }
  }
  return checks;
}

BigInt _parseUint(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return BigInt.zero;
  final parsed = BigInt.tryParse(value);
  if (parsed == null || parsed < BigInt.zero) {
    throw FormatException(
      'CLOB collateral balance must be a uint string: $raw',
    );
  }
  return parsed;
}

bool _hasCompleteLiveCredentials(LiveCredentialReadiness credentials) {
  return credentials.clobApiKey.isReady &&
      credentials.clobApiKey.value != null &&
      credentials.builderFeeKey.isReady &&
      credentials.builderFeeKey.value != null &&
      credentials.relayerApiKey.isReady &&
      credentials.relayerApiKey.value != null;
}

String _credentialBlockReason(LiveCredentialReadiness credentials) {
  final blocked = <String>[];
  if (!credentials.clobApiKey.isReady || credentials.clobApiKey.value == null) {
    blocked.add('CLOB API key ${_readinessReason(credentials.clobApiKey)}');
  }
  if (!credentials.builderFeeKey.isReady ||
      credentials.builderFeeKey.value == null) {
    blocked.add(
      'CLOB builder-fee key ${_readinessReason(credentials.builderFeeKey)}',
    );
  }
  if (!credentials.relayerApiKey.isReady ||
      credentials.relayerApiKey.value == null) {
    blocked.add(
      'Relayer API key ${_readinessReason(credentials.relayerApiKey)}',
    );
  }
  if (blocked.isEmpty) return 'Live credentials are not ready.';
  return 'Live credentials are not ready: ${blocked.join('; ')}.';
}

String _readinessReason<T>(CredentialReadiness<T> readiness) {
  if (readiness.reason.trim().isNotEmpty) return readiness.reason.trim();
  if (readiness.isReady && readiness.value == null) return 'has no value';
  return readiness.status.name;
}

String? _normalizeOptionalTransactionHash(String? transactionHash) {
  if (transactionHash == null) return null;
  final trimmed = transactionHash.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(
      transactionHash,
      'transactionHash',
      'must not be empty when provided',
    );
  }
  if (!_transactionHashPattern.hasMatch(trimmed)) {
    throw ArgumentError.value(
      transactionHash,
      'transactionHash',
      'invalid transaction hash',
    );
  }
  return trimmed.toLowerCase();
}

DepositWalletFundingConfirmationStatus _fundingConfirmationStatus(
  DepositWalletReadinessStatus status,
) {
  switch (status) {
    case DepositWalletReadinessStatus.needsDeploy:
      return DepositWalletFundingConfirmationStatus.needsDeploy;
    case DepositWalletReadinessStatus.needsApprovalCheck:
      return DepositWalletFundingConfirmationStatus.needsApprovalCheck;
    case DepositWalletReadinessStatus.needsApproval:
      return DepositWalletFundingConfirmationStatus.needsApproval;
    case DepositWalletReadinessStatus.needsFunding:
      return DepositWalletFundingConfirmationStatus.needsFunding;
    case DepositWalletReadinessStatus.ready:
      return DepositWalletFundingConfirmationStatus.ready;
    case DepositWalletReadinessStatus.blocked:
      return DepositWalletFundingConfirmationStatus.blocked;
  }
}

const List<_ApprovalSpec> _approvalSpecs = <_ApprovalSpec>[
  _ApprovalSpec(
    label: 'pusd:ctfExchangeV2',
    kind: DepositWalletApprovalKind.erc20Allowance,
    token: approvals.pusdAddress,
    spender: approvals.ctfExchangeV2,
  ),
  _ApprovalSpec(
    label: 'ctf:ctfExchangeV2',
    kind: DepositWalletApprovalKind.erc1155ApprovalForAll,
    token: approvals.ctfAddress,
    spender: approvals.ctfExchangeV2,
  ),
  _ApprovalSpec(
    label: 'pusd:negRiskExchangeV2',
    kind: DepositWalletApprovalKind.erc20Allowance,
    token: approvals.pusdAddress,
    spender: approvals.negRiskExchangeV2,
  ),
  _ApprovalSpec(
    label: 'ctf:negRiskExchangeV2',
    kind: DepositWalletApprovalKind.erc1155ApprovalForAll,
    token: approvals.ctfAddress,
    spender: approvals.negRiskExchangeV2,
  ),
  _ApprovalSpec(
    label: 'pusd:negRiskAdapterV2',
    kind: DepositWalletApprovalKind.erc20Allowance,
    token: approvals.pusdAddress,
    spender: approvals.negRiskAdapterV2,
  ),
  _ApprovalSpec(
    label: 'ctf:negRiskAdapterV2',
    kind: DepositWalletApprovalKind.erc1155ApprovalForAll,
    token: approvals.ctfAddress,
    spender: approvals.negRiskAdapterV2,
  ),
];

final class _ApprovalSpec {
  const _ApprovalSpec({
    required this.label,
    required this.kind,
    required this.token,
    required this.spender,
  });

  final String label;
  final DepositWalletApprovalKind kind;
  final String token;
  final String spender;
}

final RegExp _transactionHashPattern = RegExp(r'^0x[0-9a-fA-F]{64}$');
