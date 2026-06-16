import 'dart:typed_data';

import 'package:polydart/src/orders/order_signing.dart';
import 'package:polydart/src/types/enums.dart';

import '../../support/auth_test_fixtures.dart';

OrderV2Draft canonicalPoly1271OrderDraft() => const OrderV2Draft(
  salt: '1',
  // For sigType=poly1271, both maker and signer are the deposit wallet,
  // matching `buildSignedOrderPayload` in polygolem orders.go.
  maker: canonicalDepositWallet,
  signer: canonicalDepositWallet,
  tokenId: '12345',
  makerAmount: '5500000',
  takerAmount: '10000000',
  side: Side.buy,
  signatureType: SignatureType.poly1271,
  timestamp: '1700000000000',
);

Uint8List deterministicInnerSignature65() =>
    Uint8List.fromList(List<int>.generate(65, (i) => 0xa0 + (i % 16)));
