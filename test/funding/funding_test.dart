import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/contracts/contracts.dart' as contracts;
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/funding/funding.dart';
import 'package:polydart/src/relayer/relayer_types.dart';
import 'package:test/test.dart';

const String _recipient = '0x1234567890abcdef1234567890abcdef12345678';
const String _depositWallet = '0x21999a074344610057c9b2B362332388a44502D4';
const String _ownerEoa = '0x2c7536E3605D9C16a7a3D7b1898e529396a65c23';

void main() {
  group('EOA pUSD funding route planning', () {
    test(
      'builds an EOA wallet transaction to transfer pUSD to the deposit wallet',
      () {
        final plan = buildEoaPusdTransferPlan(
          ownerEoa: _ownerEoa,
          depositWallet: _depositWallet,
          amountBaseUnits: BigInt.from(2500000),
        );

        expect(plan.fromAddress, _ownerEoa.toLowerCase());
        expect(plan.depositWallet, _depositWallet.toLowerCase());
        expect(plan.tokenAddress, contracts.PUSD);
        expect(plan.value, '0x0');
        expect(plan.chainId, contracts.PolygonChainID);

        final data = plan.data.toLowerCase();
        expect(data, startsWith('0x$pusdTransferSelector'));
        expect(
          data.substring(10, 74),
          '000000000000000000000000${_depositWallet.substring(2).toLowerCase()}',
        );
        expect(
          BigInt.parse(data.substring(74), radix: 16),
          BigInt.from(2500000),
        );

        expect(plan.toJson(), <String, dynamic>{
          'from': _ownerEoa.toLowerCase(),
          'to': contracts.PUSD,
          'value': '0x0',
          'data': plan.data,
          'chainId': '0x89',
        });
      },
    );

    test(
      'reads EOA pUSD balance and plans the requested transfer amount',
      () async {
        final capturedBodies = <Map<String, dynamic>>[];

        final route = await planEoaPusdFundingRoute(
          ownerEoa: _ownerEoa,
          depositWallet: _depositWallet,
          requestedAmountBaseUnits: BigInt.from(1000000),
          rpcUrl: 'http://rpc.test',
          rpcClient: _balanceRpc(
            BigInt.from(2500000),
            capturedBodies: capturedBodies,
          ),
        );

        expect(route.status, PusdFundingRouteStatus.ready);
        expect(route.eoaPusdBalance, BigInt.from(2500000));
        expect(route.transferAmountBaseUnits, BigInt.from(1000000));
        expect(route.canTransfer, isTrue);
        expect(route.fullyFunded, isTrue);
        expect(route.transfer!.amountBaseUnits, BigInt.from(1000000));
        final call =
            (capturedBodies.single['params'] as List<dynamic>).first
                as Map<String, dynamic>;
        expect(call['to'], contracts.PUSD.toLowerCase());
        expect(
          (call['input'] as String).toLowerCase(),
          startsWith('0x70a08231'),
        );
      },
    );

    test(
      'plans a partial transfer when EOA balance is below the request',
      () async {
        final route = await planEoaPusdFundingRoute(
          ownerEoa: _ownerEoa,
          depositWallet: _depositWallet,
          requestedAmountBaseUnits: BigInt.from(1000000),
          rpcUrl: 'http://rpc.test',
          rpcClient: _balanceRpc(BigInt.from(700000)),
        );

        expect(route.status, PusdFundingRouteStatus.partial);
        expect(route.fullyFunded, isFalse);
        expect(route.canTransfer, isTrue);
        expect(route.transferAmountBaseUnits, BigInt.from(700000));
        expect(route.transfer!.amountBaseUnits, BigInt.from(700000));
      },
    );

    test('does not build a transaction when EOA has no pUSD', () async {
      final route = await planEoaPusdFundingRoute(
        ownerEoa: _ownerEoa,
        depositWallet: _depositWallet,
        requestedAmountBaseUnits: BigInt.from(1000000),
        rpcUrl: 'http://rpc.test',
        rpcClient: _balanceRpc(BigInt.zero),
      );

      expect(route.status, PusdFundingRouteStatus.unavailable);
      expect(route.canTransfer, isFalse);
      expect(route.transferAmountBaseUnits, BigInt.zero);
      expect(route.transfer, isNull);
    });
  });

  group('pUSD transfer call planning', () {
    test('builds a wallet-mediated ERC-20 transfer call in base units', () {
      final amount = BigInt.parse('123456789012345678901234567890');

      final plan = buildPusdTransferCallPlan(
        toAddress: _recipient.toUpperCase(),
        amountBaseUnits: amount,
      );

      expect(plan.toAddress, _recipient);
      expect(plan.amountBaseUnits, amount);
      expect(plan.amountBaseUnitsString, amount.toString());
      expect(plan.call, isA<DepositWalletCall>());
      expect(plan.call.target, contracts.PUSD);
      expect(plan.call.value, '0');

      final data = plan.call.data.toLowerCase();
      expect(data, startsWith('0x$pusdTransferSelector'));
      expect(data.length, 2 + 8 + 64 + 64);
      expect(
        data.substring(10, 74),
        '000000000000000000000000${_recipient.substring(2)}',
      );
      expect(BigInt.parse(data.substring(74), radix: 16), amount);
    });

    test('builds the raw DepositWalletCall helper from the same plan', () {
      final call = buildPusdTransferCall(
        toAddress: _recipient,
        amountBaseUnits: BigInt.from(2500000),
      );

      expect(call.target, contracts.PUSD);
      expect(call.value, '0');
      expect(call.data, endsWith('0' * 58 + '2625a0'));
    });

    test('rejects empty recipient and non-positive amount', () {
      expect(
        () => buildPusdTransferCallPlan(
          toAddress: '',
          amountBaseUnits: BigInt.one,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => buildPusdTransferCallPlan(
          toAddress: '   ',
          amountBaseUnits: BigInt.one,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => buildPusdTransferCallPlan(
          toAddress: _recipient,
          amountBaseUnits: BigInt.zero,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => buildPusdTransferCallPlan(
          toAddress: _recipient,
          amountBaseUnits: BigInt.from(-1),
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('pUSD transfer batch typed data', () {
    test('uses the existing DepositWallet.Batch typed-data helper', () {
      final plan = buildPusdTransferCallPlan(
        toAddress: _recipient,
        amountBaseUnits: BigInt.from(1000000),
      );

      final typed = buildPusdTransferBatchTypedData(
        depositWallet: _depositWallet,
        nonce: '7',
        deadline: '1778373936',
        transfer: plan,
      );

      expect(typed['primaryType'], 'Batch');
      expect(typed['domain']['name'], 'DepositWallet');
      expect(typed['domain']['version'], '1');
      expect(typed['domain']['chainId'], contracts.PolygonChainID);
      expect(typed['domain']['verifyingContract'], _depositWallet);
      expect(typed['message']['wallet'], _depositWallet);
      expect(typed['message']['nonce'], '7');
      expect(typed['message']['deadline'], '1778373936');
      expect(typed['message']['calls'], <Map<String, dynamic>>[
        plan.call.toJson(),
      ]);
    });
  });

  test('new public surface exposes no raw private-key parameter', () {
    final source = File('lib/src/funding/funding.dart').readAsStringSync();

    expect(source, isNot(contains('privateKey')));
    expect(source, isNot(contains('OwnerPrivateKey')));
  });
}

http.Client _balanceRpc(
  BigInt balance, {
  List<Map<String, dynamic>>? capturedBodies,
}) {
  return MockClient((req) async {
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    capturedBodies?.add(body);
    expect(body['method'], 'eth_call');
    final params = body['params'] as List<dynamic>;
    expect(params.last, 'latest');
    return http.Response(
      jsonEncode(<String, Object>{
        'jsonrpc': '2.0',
        'id': 1,
        'result': '0x${balance.toRadixString(16).padLeft(64, '0')}',
      }),
      200,
    );
  });
}
