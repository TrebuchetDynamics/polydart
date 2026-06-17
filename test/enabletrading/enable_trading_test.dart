import 'dart:io';
import 'dart:typed_data';

import 'package:polydart/src/auth/eth_hex.dart';
import 'package:polydart/src/auth/wallet_signer.dart';
import 'package:polydart/src/enabletrading/enable_trading.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/relayer/relayer_types.dart';
import 'package:polydart/src/signers/signers.dart';
import 'package:test/test.dart';

const _eoa = '0x2c7536E3605D9C16a7a3D7b1898e529396a65c23';
const _depositWallet = '0x21999a074344610057c9b2B362332388a44502D4';
const _privateKey =
    '0x4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318';
const _maxUint256 =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

void main() {
  group('Enable Trading ClobAuth typed data', () {
    test('matches the Polygolem wallet-provider shape', () {
      final typed = buildEnableTradingClobAuthTypedData(
        address: _eoa.toLowerCase(),
        timestamp: 1778372101,
      );

      expect(polygonChainId, 137);
      expect(
        clobAuthControlMessage,
        'This message attests that I control the given wallet',
      );
      expect(typed['primaryType'], 'ClobAuth');
      expect(typed['domain']['name'], 'ClobAuthDomain');
      expect(typed['domain']['version'], '1');
      expect(typed['domain']['chainId'], 137);
      expect(typed['message']['address'], _eoa.toLowerCase());
      expect(typed['message']['timestamp'], '1778372101');
      expect(typed['message']['nonce'], 0);
      expect(typed['message']['message'], clobAuthControlMessage);
      expect(typed['types']['ClobAuth'], <Map<String, String>>[
        {'name': 'address', 'type': 'address'},
        {'name': 'timestamp', 'type': 'string'},
        {'name': 'nonce', 'type': 'uint256'},
        {'name': 'message', 'type': 'string'},
      ]);
    });

    test('rejects non-Polygon chain ids', () {
      expect(
        () => buildEnableTradingClobAuthTypedData(
          address: _eoa,
          timestamp: 1778372101,
          chainId: 1,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('optional signing helper uses WalletSigner only', () async {
      final signer = _StubSigner(
        signature: Uint8List.fromList(
          List<int>.generate(65, (i) => i == 64 ? 27 : 0xab),
        ),
      );

      final signature = await signEnableTradingClobAuthTypedData(
        signer: signer,
        timestamp: 1778372101,
      );

      expect(signature, '0x${'ab' * 64}1b');
      expect(signer.lastTypedData!['primaryType'], 'ClobAuth');
      expect(signer.lastTypedData!['message']['address'], signer.address);
    });

    test('normalizes compact wallet signature v for ClobAuth helper', () async {
      final signer = _StubSigner(
        signature: Uint8List.fromList(
          List<int>.generate(65, (i) => i == 64 ? 0 : i),
        ),
      );

      final signature = await signEnableTradingClobAuthTypedData(
        signer: signer,
        timestamp: 1778372101,
      );

      expect(signature.substring(signature.length - 2), '1b');
    });

    test(
      'supports explicit private-key EOA signers for headless flows',
      () async {
        final signer = LocalEoaSigner(privateKeyHex: _privateKey, chainId: 137);

        final signature = await signEnableTradingClobAuthTypedData(
          signer: signer,
          timestamp: 1778372101,
        );

        expect(signer.address, _eoa);
        _expectEthereumSignature(signature);
      },
    );
  });

  group('Enable Trading approval calls', () {
    test('match the two observed UI ERC20 approve calls', () {
      final calls = buildEnableTradingApprovalCalls();

      expect(calls, hasLength(2));
      _expectApproveCall(
        calls[0],
        target: '0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB',
        spender: '0x4D97DCd97eC945f40cF65F87097ACe5EA0476045',
      );
      _expectApproveCall(
        calls[1],
        target: '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174',
        spender: '0x93070a847efEf7F70739046A929D47a521F5B8ee',
      );
    });

    test(
      'validation fails closed on count, target, value, selector, spender, amount',
      () {
        final valid = buildEnableTradingApprovalCalls();

        expect(
          () => validateEnableTradingApprovalCalls(valid),
          returnsNormally,
        );
        expect(
          () => validateEnableTradingApprovalCalls(valid.take(1).toList()),
          throwsA(isA<ValidationException>()),
        );
        expect(
          () => validateEnableTradingApprovalCalls(<DepositWalletCall>[
            const DepositWalletCall(
              target: '0x0000000000000000000000000000000000000001',
              value: '0',
              data:
                  '0x095ea7b30000000000000000000000004d97dcd97ec945f40cf65f87097ace5ea0476045$_maxUint256',
            ),
            valid[1],
          ]),
          throwsA(isA<ValidationException>()),
        );
        expect(
          () => validateEnableTradingApprovalCalls(<DepositWalletCall>[
            DepositWalletCall(
              target: valid[0].target,
              value: '1',
              data: valid[0].data,
            ),
            valid[1],
          ]),
          throwsA(isA<ValidationException>()),
        );
        expect(
          () => validateEnableTradingApprovalCalls(<DepositWalletCall>[
            DepositWalletCall(
              target: valid[0].target,
              value: '0',
              data: valid[0].data.replaceFirst('095ea7b3', 'deadbeef'),
            ),
            valid[1],
          ]),
          throwsA(isA<ValidationException>()),
        );
        expect(
          () => validateEnableTradingApprovalCalls(<DepositWalletCall>[
            DepositWalletCall(
              target: valid[0].target,
              value: '0',
              data: valid[0].data.replaceFirst(
                '4d97dcd97ec945f40cf65f87097ace5ea0476045',
                '0000000000000000000000000000000000000001',
              ),
            ),
            valid[1],
          ]),
          throwsA(isA<ValidationException>()),
        );
        expect(
          () => validateEnableTradingApprovalCalls(<DepositWalletCall>[
            DepositWalletCall(
              target: valid[0].target,
              value: '0',
              data: valid[0].data.replaceFirst(_maxUint256, '0' * 64),
            ),
            valid[1],
          ]),
          throwsA(isA<ValidationException>()),
        );
      },
    );
  });

  group('Enable Trading approval batch typed data', () {
    test('matches the DepositWallet.Batch wallet-provider shape', () {
      final calls = buildEnableTradingApprovalCalls();
      final typed = buildEnableTradingApprovalBatchTypedData(
        depositWallet: _depositWallet,
        nonce: '6',
        deadline: '1778373936',
        calls: calls,
      );

      expect(typed['primaryType'], 'Batch');
      expect(typed['domain']['name'], 'DepositWallet');
      expect(typed['domain']['version'], '1');
      expect(typed['domain']['chainId'], 137);
      expect(typed['domain']['verifyingContract'], _depositWallet);
      expect(typed['message']['wallet'], _depositWallet);
      expect(typed['message']['nonce'], '6');
      expect(typed['message']['deadline'], '1778373936');
      expect(typed['message']['calls'], calls.map((c) => c.toJson()).toList());
      expect(typed['types']['Batch'], <Map<String, String>>[
        {'name': 'wallet', 'type': 'address'},
        {'name': 'nonce', 'type': 'uint256'},
        {'name': 'deadline', 'type': 'uint256'},
        {'name': 'calls', 'type': 'Call[]'},
      ]);
    });

    test('rejects wrong chain or invalid approval calls before building', () {
      expect(
        () => buildEnableTradingApprovalBatchTypedData(
          depositWallet: _depositWallet,
          nonce: '6',
          deadline: '1778373936',
          calls: buildEnableTradingApprovalCalls(),
          chainId: 1,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => buildEnableTradingApprovalBatchTypedData(
          depositWallet: _depositWallet,
          nonce: '6',
          deadline: '1778373936',
          calls: const <DepositWalletCall>[],
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('optional signing helper uses WalletSigner only', () async {
      final signer = _StubSigner(
        signature: Uint8List.fromList(
          List<int>.generate(65, (i) => i == 64 ? 27 : i),
        ),
      );

      final signature = await signEnableTradingApprovalBatchTypedData(
        signer: signer,
        depositWallet: _depositWallet,
        nonce: '6',
        deadline: '1778373936',
        calls: buildEnableTradingApprovalCalls(),
      );

      expect(
        signature,
        '0x${bytesToHex(Uint8List.fromList(List<int>.generate(65, (i) => i == 64 ? 27 : i)))}',
      );
      expect(signer.lastTypedData!['primaryType'], 'Batch');
      expect(signer.lastTypedData!['domain']['chainId'], 137);
    });

    test(
      'supports explicit private-key EOA signers for approval batches',
      () async {
        final signer = LocalEoaSigner(privateKeyHex: _privateKey, chainId: 137);

        final signature = await signEnableTradingApprovalBatchTypedData(
          signer: signer,
          depositWallet: _depositWallet,
          nonce: '6',
          deadline: '1778373936',
          calls: buildEnableTradingApprovalCalls(),
        );

        expect(signer.address, _eoa);
        _expectEthereumSignature(signature);
      },
    );
  });

  test('new public surface exposes no raw private-key parameter', () {
    final source = File(
      'lib/src/enabletrading/enable_trading.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('privateKey')));
    expect(source, isNot(contains('OwnerPrivateKey')));
  });
}

void _expectEthereumSignature(String signature) {
  expect(signature, startsWith('0x'));
  expect(signature.length, 2 + 65 * 2);
  expect(signature.substring(signature.length - 2), isIn(<String>['1b', '1c']));
}

void _expectApproveCall(
  DepositWalletCall call, {
  required String target,
  required String spender,
}) {
  expect(call.target, target);
  expect(call.value, '0');
  final data = call.data.toLowerCase();
  expect(data, startsWith('0x095ea7b3'));
  expect(data, contains(spender.toLowerCase().replaceFirst('0x', '')));
  expect(data, endsWith(_maxUint256));
  expect(data.length, 2 + 8 + 64 + 64);
}

class _StubSigner implements WalletSigner {
  _StubSigner({required this.signature});

  final Uint8List signature;
  Map<String, dynamic>? lastTypedData;

  @override
  String get address => _eoa;

  @override
  int get chainId => polygonChainId;

  @override
  Future<Uint8List> signTypedData(Map<String, dynamic> typedData) async {
    lastTypedData = typedData;
    return signature;
  }

  @override
  Future<Uint8List> personalSign(Uint8List message) async => signature;
}
