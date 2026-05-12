/// V2 approval batch builder.
///
/// Mirrors `internal/relayer/approvals.go`. Returns the six wallet calls
/// (pUSD `approve` + CTF `setApprovalForAll` for each of the three V2
/// spenders) that a deposit wallet must execute before trading.
library;

import 'relayer_types.dart';

const String pusdAddress = '0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB';
const String ctfAddress = '0x4D97DCd97eC945f40cF65F87097ACe5EA0476045';
const String ctfExchangeV2 = '0xE111180000d2663C0091e4f400237545B87B996B';
const String negRiskExchangeV2 = '0xe2222d279d744050d28e00520010520000310F59';
const String negRiskAdapterV2 = '0xd91E80cF2E7be2e162c6513ceD06f1dD0dA35296';

const String _erc20ApproveSelector = '095ea7b3';
const String _erc1155SetApprovalForAllSelector = 'a22cb465';
const String _maxUint256 =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

const List<String> _v2Spenders = <String>[
  ctfExchangeV2,
  negRiskExchangeV2,
  negRiskAdapterV2,
];

String _strip0x(String s) {
  final t = s.trim();
  if (t.startsWith('0x') || t.startsWith('0X')) return t.substring(2);
  return t;
}

String _pad32(String hex) {
  final t = _strip0x(hex).toLowerCase();
  return '0' * (64 - t.length) + t;
}

String _checksum(String addr) {
  // Polygolem uses common.HexToAddress(...).Hex() which returns the EIP-55
  // checksummed form. Polydart consumers don't reuse target addresses for
  // signature recovery, so the lowercase 0x… form is wire-equivalent. To
  // mirror the Go output byte-for-byte, we keep the source casing.
  return '0x${_strip0x(addr)}';
}

/// Returns the six approval calls a deposit wallet must execute to permit
/// trading on the V2 exchanges. Order matches polygolem:
/// `(pUSD→spender, CTF→spender)` for each spender in
/// `[CTF V2, NegRisk V2, NegRisk Adapter]`.
List<DepositWalletCall> buildApprovalCalls() {
  final calls = <DepositWalletCall>[];
  for (final spender in _v2Spenders) {
    calls.add(_buildApproveCall(pusdAddress, spender));
    calls.add(_buildCtfApprovalCall(spender));
  }
  return calls;
}

DepositWalletCall _buildApproveCall(String token, String spender) {
  final data = '0x$_erc20ApproveSelector${_pad32(spender)}$_maxUint256';
  return DepositWalletCall(target: _checksum(token), value: '0', data: data);
}

DepositWalletCall _buildCtfApprovalCall(String operator) {
  final data =
      '0x$_erc1155SetApprovalForAllSelector${_pad32(operator)}'
      '0000000000000000000000000000000000000000000000000000000000000001';
  return DepositWalletCall(
    target: _checksum(ctfAddress),
    value: '0',
    data: data,
  );
}
