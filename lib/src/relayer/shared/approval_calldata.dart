/// Shared ERC-20 approval calldata helpers.

library;

const String erc20ApproveSelector = '095ea7b3';
const String maxUint256Hex =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

String strip0x(String s) {
  final t = s.trim();
  if (t.startsWith('0x') || t.startsWith('0X')) return t.substring(2);
  return t;
}

bool sameHexAddress(String a, String b) {
  return strip0x(a).toLowerCase() == strip0x(b).toLowerCase();
}
