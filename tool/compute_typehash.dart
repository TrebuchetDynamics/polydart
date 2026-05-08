// Tiny helper: prints the canonical EIP-712 type hash for the strings
// polydart cares about. Run with: `dart run tool/compute_typehash.dart`.
import 'package:polydart/src/auth/eth_hex.dart';

void main() {
  final typeHashes = <String>[
    'EIP712Domain(string name,string version,uint256 chainId)',
    'ClobAuth(address address,string timestamp,uint256 nonce,string message)',
  ];
  for (final s in typeHashes) {
    // ignore: avoid_print
    print('${bytesToHex(keccak256Utf8(s))}  $s');
  }
}
