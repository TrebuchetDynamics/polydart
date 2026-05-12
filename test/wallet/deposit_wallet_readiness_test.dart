import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

const _builder = BuilderConfig(
  key: 'aaaaaaaa-bbbb-cccc-dddd-eeeeffff0001',
  secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  passphrase: 'pass',
);

// Parity vector: polygolem commit dca956a, matching
// internal/clob/orders_test.go's canonical EOA/deposit-wallet pair.
const _eoa = '0x2c7536E3605D9C16a7a3D7b1898e529396a65c23';
const _depositWallet = '0xfd5041047be8c192c725a66228f141196fa3cf9c';

RelayerClient _relayer(
  Future<http.Response> Function(http.BaseRequest) handler,
) {
  return RelayerClient(
    builderConfig: _builder,
    transport: HttpTransport(
      config: const TransportConfig(
        baseUrl: defaultRelayerBaseUrl,
        retryMax: 0,
      ),
      inner: MockClient(handler),
    ),
    clock: () => DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
  );
}

void main() {
  group('DepositWalletReadinessService.check', () {
    test(
      'returns needsDeploy for an EOA whose deposit wallet is derived but not deployed',
      () async {
        Uri? capturedUrl;
        final service = DepositWalletReadinessService(
          relayer: _relayer((req) async {
            capturedUrl = req.url;
            return http.Response(
              jsonEncode(<String, dynamic>{'deployed': false}),
              200,
            );
          }),
        );

        final readiness = await service.check(_eoa);

        expect(capturedUrl!.path, '/deployed');
        expect(capturedUrl!.queryParameters['address'], _eoa.toLowerCase());
        expect(readiness.status, DepositWalletReadinessStatus.needsDeploy);
        expect(readiness.ownerEoa, _eoa.toLowerCase());
        expect(readiness.depositWallet, _depositWallet);
        expect(readiness.deployed, isFalse);
      },
    );

    test(
      'returns needsApprovalCheck for a deployed wallet before approval checks run',
      () async {
        final service = DepositWalletReadinessService(
          relayer: _relayer((req) async {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'deployed': true,
                'address': _depositWallet,
              }),
              200,
            );
          }),
        );

        final readiness = await service.check(_eoa);

        expect(
          readiness.status,
          DepositWalletReadinessStatus.needsApprovalCheck,
        );
        expect(readiness.ownerEoa, _eoa.toLowerCase());
        expect(readiness.depositWallet, _depositWallet);
        expect(readiness.deployed, isTrue);
        expect(readiness.approvalsChecked, isFalse);
        expect(readiness.requiredApprovals, <String>[
          'pusd:ctfExchangeV2',
          'ctf:ctfExchangeV2',
          'pusd:negRiskExchangeV2',
          'ctf:negRiskExchangeV2',
          'pusd:negRiskAdapterV2',
          'ctf:negRiskAdapterV2',
        ]);
      },
    );

    test('defensively copies requiredApprovals', () {
      final mutable = <String>['pusd:ctfExchangeV2'];

      final readiness = DepositWalletReadiness(
        status: DepositWalletReadinessStatus.needsApprovalCheck,
        ownerEoa: _eoa.toLowerCase(),
        depositWallet: _depositWallet,
        deployed: true,
        requiredApprovals: mutable,
      );

      mutable.add('ctf:ctfExchangeV2');

      expect(readiness.requiredApprovals, <String>['pusd:ctfExchangeV2']);
      expect(
        () => readiness.requiredApprovals.add('ctf:ctfExchangeV2'),
        throwsUnsupportedError,
      );
    });
  });
}
