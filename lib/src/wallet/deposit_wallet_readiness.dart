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
