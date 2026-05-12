/// Deposit-wallet readiness orchestration.
///
/// Product-facing wrapper over the low-level CREATE2 and relayer clients.
/// Keep UI copy and credential storage in the consumer; this module returns
/// machine-readable protocol state only.
library;

import 'package:meta/meta.dart';

import '../auth/create2.dart';
import '../auth/eth_hex.dart';
import '../credentials/live_credentials.dart';
import '../relayer/relayer_client.dart';
import '../transport/http_transport.dart';

const List<String> _requiredApprovalLabels = <String>[
  'pusd:ctfExchangeV2',
  'ctf:ctfExchangeV2',
  'pusd:negRiskExchangeV2',
  'ctf:negRiskExchangeV2',
  'pusd:negRiskAdapterV2',
  'ctf:negRiskAdapterV2',
];

enum DepositWalletReadinessStatus { needsDeploy, needsApprovalCheck, blocked }

@immutable
final class DepositWalletReadiness {
  DepositWalletReadiness({
    required this.status,
    required this.ownerEoa,
    required this.depositWallet,
    required this.deployed,
    this.approvalsChecked = false,
    this.credentialsReady = true,
    this.reason = '',
    List<String> requiredApprovals = const <String>[],
  }) : requiredApprovals = List.unmodifiable(requiredApprovals);

  final DepositWalletReadinessStatus status;
  final String ownerEoa;
  final String depositWallet;
  final bool deployed;
  final bool approvalsChecked;
  final bool credentialsReady;
  final String reason;
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
      return DepositWalletReadinessService(relayer: relayer).check(owner);
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
