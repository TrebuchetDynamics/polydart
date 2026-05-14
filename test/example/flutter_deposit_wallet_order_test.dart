import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

import '../../example/flutter_deposit_wallet_order.dart';

void main() {
  test('mock-only deposit-wallet order uses signatureType 3', () async {
    final signer = FakeFlutterWalletSigner(
      address: '0x0000000000000000000000000000000000001234',
    );
    final smoke = FlutterDepositWalletOrderSmoke(signer: signer);

    final outcome = await smoke.run();

    expect(outcome, isA<FlutterDepositWalletOrderSmokeSuccess>());
    final success = outcome as FlutterDepositWalletOrderSmokeSuccess;
    final depositWallet = deriveDepositWallet(signer.address);
    expect(success.response.orderId, 'mock-order-1');
    expect(success.depositWallet, depositWallet);
    expect(success.readinessStatus, 'ready');
    expect(success.orderRequestHeaders['POLY_ADDRESS'], signer.address);
    expect(signer.lastTypedData?['primaryType'], 'TypedDataSign');

    final order = success.orderRequestBody['order'] as Map<String, dynamic>;
    expect(order['maker'], depositWallet);
    expect(order['signer'], depositWallet);
    expect(order['signatureType'], 3);
    expect(order['tokenId'], '12345');
  });

  test('user rejection is returned as an app-visible outcome', () async {
    final signer = FakeFlutterWalletSigner(
      address: '0x0000000000000000000000000000000000001234',
      rejectTypedData: true,
    );
    final smoke = FlutterDepositWalletOrderSmoke(signer: signer);

    final outcome = await smoke.run();

    expect(outcome, isA<FlutterDepositWalletOrderSmokeRejected>());
    final rejected = outcome as FlutterDepositWalletOrderSmokeRejected;
    expect(rejected.reason, contains('rejected'));
    expect(rejected.orderWasPosted, isFalse);
  });
}
