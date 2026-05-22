import 'dart:typed_data';

import 'package:test/test.dart';

import '../../example/flutter_wallet_signer.dart';

void main() {
  test('signTypedData blocks wallet request on non-Polygon chain', () async {
    var walletRequestCalls = 0;
    final signer = FlutterWalletSignerAdapter(
      address: '0x0000000000000000000000000000000000001234',
      chainId: 1,
      walletRequest: (method, params) async {
        walletRequestCalls++;
        return '0x${'00' * 64}1b';
      },
    );

    expect(
      () => signer.signTypedData(const <String, dynamic>{
        'types': <String, dynamic>{},
        'primaryType': 'TypedDataSign',
        'domain': <String, dynamic>{},
        'message': <String, dynamic>{},
      }),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('Polymarket signing expects Polygon mainnet'),
        ),
      ),
    );
    expect(walletRequestCalls, 0);
  });

  test('personalSign blocks wallet request on non-Polygon chain', () async {
    var walletRequestCalls = 0;
    final signer = FlutterWalletSignerAdapter(
      address: '0x0000000000000000000000000000000000001234',
      chainId: 1,
      walletRequest: (method, params) async {
        walletRequestCalls++;
        return '0x${'00' * 64}1b';
      },
    );

    expect(
      () => signer.personalSign(Uint8List.fromList(<int>[1, 2, 3])),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('Polymarket signing expects Polygon mainnet'),
        ),
      ),
    );
    expect(walletRequestCalls, 0);
  });
}
