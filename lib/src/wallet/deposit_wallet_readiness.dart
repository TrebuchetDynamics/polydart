/// Deposit-wallet readiness orchestration.
///
/// Product-facing wrapper over the low-level CREATE2 and relayer clients.
/// Keep UI copy and credential storage in the consumer; this module returns
/// machine-readable protocol state only.
library;

import 'package:meta/meta.dart';

import '../auth/create2.dart';
import '../auth/eth_hex.dart';
import '../relayer/relayer_client.dart';

const List<String> _requiredApprovalLabels = <String>[
  'pusd:ctfExchangeV2',
  'ctf:ctfExchangeV2',
  'pusd:negRiskExchangeV2',
  'ctf:negRiskExchangeV2',
  'pusd:negRiskAdapterV2',
  'ctf:negRiskAdapterV2',
];

enum DepositWalletReadinessStatus { needsDeploy, needsApprovalCheck }

@immutable
final class DepositWalletReadiness {
  DepositWalletReadiness({
    required this.status,
    required this.ownerEoa,
    required this.depositWallet,
    required this.deployed,
    this.approvalsChecked = false,
    List<String> requiredApprovals = const <String>[],
  }) : requiredApprovals = List.unmodifiable(requiredApprovals);

  final DepositWalletReadinessStatus status;
  final String ownerEoa;
  final String depositWallet;
  final bool deployed;
  final bool approvalsChecked;
  final List<String> requiredApprovals;
}

final class DepositWalletReadinessService {
  const DepositWalletReadinessService({required RelayerClient relayer})
    : _relayer = relayer;

  final RelayerClient _relayer;

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
