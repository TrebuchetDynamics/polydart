import 'dart:typed_data';

import 'package:test/test.dart';

import '../../example/flutter_wallet_signer.dart';

void main() {
  test('builds signer from Reown eip155 session chain id', () async {
    var walletRequestCalls = 0;
    String? requestedMethod;
    final signer = buildFlutterWalletSignerFromEip155Chain(
      address: '0x0000000000000000000000000000000000001234',
      eip155ChainId: 'eip155:137',
      walletRequest: (method, params) async {
        walletRequestCalls++;
        requestedMethod = method;
        return '0x${'00' * 64}1b';
      },
    );

    final signature = await signer.personalSign(Uint8List.fromList(<int>[1]));

    expect(signer.chainId, 137);
    expect(signature.length, 65);
    expect(requestedMethod, 'personal_sign');
    expect(walletRequestCalls, 1);
  });

  test('Reown eip155 session chain rejects non-Polygon before wallet RPC', () {
    var walletRequestCalls = 0;

    expect(
      () => buildFlutterWalletSignerFromEip155Chain(
        address: '0x0000000000000000000000000000000000001234',
        eip155ChainId: 'eip155:1',
        walletRequest: (method, params) async {
          walletRequestCalls++;
          return '0x${'00' * 64}1b';
        },
      ),
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
