import 'dart:io';

import 'package:polydart/src/contracts/contracts.dart' as contracts;
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/funding/funding.dart';
import 'package:polydart/src/relayer/relayer_types.dart';
import 'package:test/test.dart';

const String _recipient = '0x1234567890abcdef1234567890abcdef12345678';
const String _depositWallet = '0x21999a074344610057c9b2B362332388a44502D4';

void main() {
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
