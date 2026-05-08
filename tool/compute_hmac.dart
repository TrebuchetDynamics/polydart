// Computes a polydart HMAC for a known input. Used to lock parity
// fixtures matching polygolem.
import 'package:polydart/src/auth/l2.dart';

void main() {
  // ignore: avoid_print
  print(
    signHmac(
      secret: 'c2VjcmV0',
      timestamp: 1700000000,
      method: 'GET',
      path: '/book',
    ),
  );
}
