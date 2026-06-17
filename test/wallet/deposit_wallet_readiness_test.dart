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
const _clobKey = ApiKey(
  key: 'clob-key',
  secret: 'clob-secret',
  passphrase: 'clob-pass',
);
const _relayerKey = V2APIKey(key: 'relayer-key', address: _eoa);
const _fundingTxHash =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

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

    test(
      'blocks when relayer deployed address disagrees with derivation',
      () async {
        final service = DepositWalletReadinessService(
          relayer: _relayer((req) async {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'deployed': true,
                'address': '0x0000000000000000000000000000000000000001',
              }),
              200,
            );
          }),
        );

        final readiness = await service.check(_eoa);

        expect(readiness.status, DepositWalletReadinessStatus.blocked);
        expect(readiness.deployed, isTrue);
        expect(readiness.depositWallet, _depositWallet);
        expect(readiness.reason, contains('expected $_depositWallet'));
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

    test(
      'checkWithCredentials builds a V2 relayer client from live credentials',
      () async {
        Uri? capturedUrl;
        Map<String, String>? capturedHeaders;
        final readiness =
            await DepositWalletReadinessService.checkWithCredentials(
              eoaAddress: _eoa,
              credentials: const LiveCredentialReadiness(
                clobApiKey: CredentialReadiness<ApiKey>(
                  status: LiveCredentialStatus.cached,
                  value: _clobKey,
                ),
                builderFeeKey: CredentialReadiness<ApiKey>(
                  status: LiveCredentialStatus.cached,
                  value: _clobKey,
                ),
                relayerApiKey: CredentialReadiness<V2APIKey>(
                  status: LiveCredentialStatus.cached,
                  value: _relayerKey,
                ),
              ),
              relayerTransport: HttpTransport(
                config: const TransportConfig(
                  baseUrl: defaultRelayerBaseUrl,
                  retryMax: 0,
                ),
                inner: MockClient((req) async {
                  capturedUrl = req.url;
                  capturedHeaders = req.headers;
                  return http.Response(
                    jsonEncode(<String, dynamic>{'deployed': false}),
                    200,
                  );
                }),
              ),
            );

        expect(capturedUrl!.path, '/deployed');
        expect(capturedUrl!.queryParameters['address'], _eoa.toLowerCase());
        expect(capturedHeaders!['RELAYER_API_KEY'], _relayerKey.key);
        expect(capturedHeaders!['RELAYER_API_KEY_ADDRESS'], _eoa);
        expect(capturedHeaders!.containsKey('POLY_BUILDER_API_KEY'), isFalse);
        expect(readiness.status, DepositWalletReadinessStatus.needsDeploy);
        expect(readiness.credentialsReady, isTrue);
        expect(readiness.reason, isEmpty);
      },
    );

    test(
      'checkWithCredentials returns blocked readiness when credentials are missing',
      () async {
        final readiness =
            await DepositWalletReadinessService.checkWithCredentials(
              eoaAddress: _eoa,
              credentials: const LiveCredentialReadiness(
                clobApiKey: CredentialReadiness<ApiKey>(
                  status: LiveCredentialStatus.cached,
                  value: _clobKey,
                ),
                builderFeeKey: CredentialReadiness<ApiKey>(
                  status: LiveCredentialStatus.cached,
                  value: _clobKey,
                ),
                relayerApiKey: CredentialReadiness<V2APIKey>(
                  status: LiveCredentialStatus.blocked,
                  action: LiveCredentialAction.retry,
                  reason: 'relayer unavailable',
                ),
              ),
              relayerTransport: HttpTransport(
                config: const TransportConfig(
                  baseUrl: defaultRelayerBaseUrl,
                  retryMax: 0,
                ),
                inner: MockClient((_) async => fail('HTTP should not run')),
              ),
            );

        expect(readiness.status, DepositWalletReadinessStatus.blocked);
        expect(readiness.ownerEoa, _eoa.toLowerCase());
        expect(readiness.depositWallet, _depositWallet);
        expect(readiness.deployed, isFalse);
        expect(readiness.credentialsReady, isFalse);
        expect(readiness.reason, contains('relayer unavailable'));
      },
    );

    test(
      'checkWithCredentials returns needsApproval when a required approval is missing',
      () async {
        final clobUrls = <Uri>[];

        final readiness =
            await DepositWalletReadinessService.checkWithCredentials(
              eoaAddress: _eoa,
              credentials: _readyCredentials,
              relayerTransport: _relayerTransport(deployed: true),
              clob: _clobWithBalance('1000000', capturedUrls: clobUrls),
              rpcClient: _approvalRpc(missingApprovalIndexes: <int>{3}),
              rpcUrl: 'http://rpc.test',
            );

        expect(readiness.status, DepositWalletReadinessStatus.needsApproval);
        expect(readiness.approvalsChecked, isTrue);
        expect(readiness.fundingChecked, isTrue);
        expect(readiness.missingApprovals, <String>['ctf:negRiskExchangeV2']);
        expect(readiness.approvalChecks, hasLength(6));
        expect(readiness.clobBalance, '1000000');
        expect(clobUrls.single.path, '/balance-allowance');
        expect(clobUrls.single.queryParameters['asset_type'], 'COLLATERAL');
        expect(clobUrls.single.queryParameters['signature_type'], '3');
      },
    );

    test(
      'checkWithCredentials returns needsFunding when approvals are ready but CLOB balance is zero',
      () async {
        final readiness =
            await DepositWalletReadinessService.checkWithCredentials(
              eoaAddress: _eoa,
              credentials: _readyCredentials,
              relayerTransport: _relayerTransport(deployed: true),
              clob: _clobWithBalance('0'),
              rpcClient: _approvalRpc(),
              rpcUrl: 'http://rpc.test',
            );

        expect(readiness.status, DepositWalletReadinessStatus.needsFunding);
        expect(readiness.approvalsChecked, isTrue);
        expect(readiness.fundingChecked, isTrue);
        expect(readiness.missingApprovals, isEmpty);
        expect(readiness.clobBalance, '0');
      },
    );

    test(
      'checkWithCredentials includes deposit-wallet pUSD balance from RPC',
      () async {
        final readiness =
            await DepositWalletReadinessService.checkWithCredentials(
              eoaAddress: _eoa,
              credentials: _readyCredentials,
              relayerTransport: _relayerTransport(deployed: true),
              clob: _clobWithBalance('0'),
              rpcClient: _approvalRpc(pusdBalance: BigInt.from(2500000)),
              rpcUrl: 'http://rpc.test',
            );

        expect(readiness.status, DepositWalletReadinessStatus.needsFunding);
        expect(readiness.fundingChecked, isTrue);
        expect(readiness.clobBalance, '0');
        expect(readiness.depositWalletPusdBalance, '2500000');
      },
    );

    test(
      'checkWithCredentials returns ready when deployed, approved, and funded',
      () async {
        final readiness =
            await DepositWalletReadinessService.checkWithCredentials(
              eoaAddress: _eoa,
              credentials: _readyCredentials,
              relayerTransport: _relayerTransport(deployed: true),
              clob: _clobWithBalance('2500000'),
              rpcClient: _approvalRpc(),
              rpcUrl: 'http://rpc.test',
            );

        expect(readiness.status, DepositWalletReadinessStatus.ready);
        expect(readiness.deployed, isTrue);
        expect(readiness.approvalsChecked, isTrue);
        expect(readiness.fundingChecked, isTrue);
        expect(readiness.missingApprovals, isEmpty);
        expect(readiness.clobBalance, '2500000');
        expect(readiness.depositWalletPusdBalance, '1');
      },
    );

    test(
      'waitForFundingReadiness waits for a wallet tx receipt before refreshing CLOB collateral',
      () async {
        final delays = <Duration>[];

        final confirmation = await waitForDepositWalletFundingReadiness(
          eoaAddress: _eoa,
          credentials: _readyCredentials,
          transactionHash: _fundingTxHash,
          relayerTransport: _relayerTransport(deployed: true),
          clob: _clobWithBalances(<String>['0', '2500000']),
          rpcClient: _receiptThenApprovalRpc(
            receiptResults: <Map<String, dynamic>?>[
              null,
              <String, dynamic>{
                'transactionHash': _fundingTxHash,
                'status': '0x1',
              },
            ],
          ),
          rpcUrl: 'http://rpc.test',
          pollInterval: const Duration(milliseconds: 10),
          maxAttempts: 4,
          delay: (duration) async => delays.add(duration),
        );

        expect(
          confirmation.status,
          DepositWalletFundingConfirmationStatus.ready,
        );
        expect(confirmation.transactionConfirmed, isTrue);
        expect(
          confirmation.readiness.status,
          DepositWalletReadinessStatus.ready,
        );
        expect(confirmation.readiness.clobBalance, '2500000');
        expect(confirmation.readinessAttempts, 2);
        expect(delays, hasLength(2));
      },
    );

    test(
      'checkWithCredentials blocked reason names every incomplete credential',
      () async {
        final readiness =
            await DepositWalletReadinessService.checkWithCredentials(
              eoaAddress: _eoa,
              credentials: const LiveCredentialReadiness(
                clobApiKey: CredentialReadiness<ApiKey>(
                  status: LiveCredentialStatus.userRejected,
                ),
                builderFeeKey: CredentialReadiness<ApiKey>(
                  status: LiveCredentialStatus.blocked,
                  reason: 'builder fee unavailable',
                ),
                relayerApiKey: CredentialReadiness<V2APIKey>(
                  status: LiveCredentialStatus.cached,
                ),
              ),
              relayerTransport: HttpTransport(
                config: const TransportConfig(
                  baseUrl: defaultRelayerBaseUrl,
                  retryMax: 0,
                ),
                inner: MockClient((_) async => fail('HTTP should not run')),
              ),
            );

        expect(readiness.status, DepositWalletReadinessStatus.blocked);
        expect(readiness.credentialsReady, isFalse);
        expect(readiness.reason, contains('CLOB API key userRejected'));
        expect(
          readiness.reason,
          contains('CLOB builder-fee key builder fee unavailable'),
        );
        expect(readiness.reason, contains('Relayer API key has no value'));
      },
    );

    test(
      'waitForFundingReadiness reports a still-pending wallet transaction after max attempts',
      () async {
        final delays = <Duration>[];

        final confirmation = await waitForDepositWalletFundingReadiness(
          eoaAddress: _eoa,
          credentials: _readyCredentials,
          transactionHash: _fundingTxHash,
          relayerTransport: _relayerTransport(deployed: true),
          clob: _clobWithBalance('0'),
          rpcClient: _receiptThenApprovalRpc(
            receiptResults: <Map<String, dynamic>?>[null, null],
          ),
          rpcUrl: 'http://rpc.test',
          pollInterval: const Duration(milliseconds: 5),
          maxAttempts: 2,
          delay: (duration) async => delays.add(duration),
        );

        expect(
          confirmation.status,
          DepositWalletFundingConfirmationStatus.transactionPending,
        );
        expect(confirmation.transactionConfirmed, isFalse);
        expect(confirmation.transactionFailed, isFalse);
        expect(confirmation.transactionAttempts, 2);
        expect(confirmation.readinessAttempts, 1);
        expect(
          confirmation.readiness.status,
          DepositWalletReadinessStatus.needsFunding,
        );
        expect(delays, <Duration>[const Duration(milliseconds: 5)]);
      },
    );

    test(
      'waitForFundingReadiness reports a reverted wallet transaction separately from pending',
      () async {
        final confirmation = await waitForDepositWalletFundingReadiness(
          eoaAddress: _eoa,
          credentials: _readyCredentials,
          transactionHash: _fundingTxHash,
          relayerTransport: _relayerTransport(deployed: true),
          clob: _clobWithBalance('0'),
          rpcClient: _receiptThenApprovalRpc(
            receiptResults: <Map<String, dynamic>?>[
              <String, dynamic>{
                'transactionHash': _fundingTxHash,
                'status': '0x0',
              },
            ],
          ),
          rpcUrl: 'http://rpc.test',
          pollInterval: Duration.zero,
          maxAttempts: 2,
          delay: (_) async {},
        );

        expect(
          confirmation.status,
          DepositWalletFundingConfirmationStatus.transactionFailed,
        );
        expect(confirmation.transactionConfirmed, isTrue);
        expect(confirmation.transactionFailed, isTrue);
        expect(confirmation.transactionAttempts, 1);
        expect(
          confirmation.readiness.status,
          DepositWalletReadinessStatus.needsFunding,
        );
      },
    );

    test(
      'waitForFundingReadiness maps refreshed readiness states to confirmation states',
      () async {
        final cases =
            <
              ({
                String name,
                HttpTransport relayerTransport,
                ClobClient clob,
                http.Client? rpcClient,
                DepositWalletFundingConfirmationStatus want,
                DepositWalletReadinessStatus readiness,
              })
            >[
              (
                name: 'needs deploy',
                relayerTransport: _relayerTransport(deployed: false),
                clob: _clobWithBalance('0'),
                rpcClient: _approvalRpc(),
                want: DepositWalletFundingConfirmationStatus.needsDeploy,
                readiness: DepositWalletReadinessStatus.needsDeploy,
              ),
              (
                name: 'needs approval',
                relayerTransport: _relayerTransport(deployed: true),
                clob: _clobWithBalance('1000000'),
                rpcClient: _approvalRpc(missingApprovalIndexes: <int>{0}),
                want: DepositWalletFundingConfirmationStatus.needsApproval,
                readiness: DepositWalletReadinessStatus.needsApproval,
              ),
              (
                name: 'blocked credentials',
                relayerTransport: _relayerTransport(deployed: true),
                clob: _clobWithBalance('1000000'),
                rpcClient: _approvalRpc(),
                want: DepositWalletFundingConfirmationStatus.blocked,
                readiness: DepositWalletReadinessStatus.blocked,
              ),
            ];

        for (final tc in cases) {
          final credentials = tc.name == 'blocked credentials'
              ? const LiveCredentialReadiness(
                  clobApiKey: CredentialReadiness<ApiKey>(
                    status: LiveCredentialStatus.blocked,
                    reason: 'clob unavailable',
                  ),
                  builderFeeKey: CredentialReadiness<ApiKey>(
                    status: LiveCredentialStatus.cached,
                    value: _clobKey,
                  ),
                  relayerApiKey: CredentialReadiness<V2APIKey>(
                    status: LiveCredentialStatus.cached,
                    value: _relayerKey,
                  ),
                )
              : _readyCredentials;
          final confirmation = await waitForDepositWalletFundingReadiness(
            eoaAddress: _eoa,
            credentials: credentials,
            relayerTransport: tc.relayerTransport,
            clob: tc.clob,
            rpcClient: tc.rpcClient,
            rpcUrl: 'http://rpc.test',
            pollInterval: Duration.zero,
            maxAttempts: 1,
            delay: (_) async {},
          );

          expect(confirmation.status, tc.want, reason: tc.name);
          expect(confirmation.readiness.status, tc.readiness, reason: tc.name);
          expect(confirmation.transactionHash, isNull, reason: tc.name);
          expect(confirmation.transactionConfirmed, isTrue, reason: tc.name);
        }
      },
    );
  });
}

const LiveCredentialReadiness _readyCredentials = LiveCredentialReadiness(
  clobApiKey: CredentialReadiness<ApiKey>(
    status: LiveCredentialStatus.cached,
    value: _clobKey,
  ),
  builderFeeKey: CredentialReadiness<ApiKey>(
    status: LiveCredentialStatus.cached,
    value: _clobKey,
  ),
  relayerApiKey: CredentialReadiness<V2APIKey>(
    status: LiveCredentialStatus.cached,
    value: _relayerKey,
  ),
);

HttpTransport _relayerTransport({required bool deployed}) {
  return HttpTransport(
    config: const TransportConfig(baseUrl: defaultRelayerBaseUrl, retryMax: 0),
    inner: MockClient((req) async {
      expect(req.url.path, '/deployed');
      return http.Response(
        jsonEncode(<String, dynamic>{'deployed': deployed}),
        200,
      );
    }),
  );
}

ClobClient _clobWithBalance(String balance, {List<Uri>? capturedUrls}) {
  return _clobWithBalances(<String>[balance], capturedUrls: capturedUrls);
}

ClobClient _clobWithBalances(List<String> balances, {List<Uri>? capturedUrls}) {
  var index = 0;
  return ClobClient(
    transport: HttpTransport(
      config: const TransportConfig(
        baseUrl: ClobClient.defaultBaseUrl,
        retryMax: 0,
      ),
      inner: MockClient((req) async {
        capturedUrls?.add(req.url);
        final balance =
            balances[index < balances.length ? index : balances.length - 1];
        index++;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'balance': balance,
            'allowances': <String, String>{'0xCtfExchangeV2': '999999999'},
          }),
          200,
        );
      }),
    ),
  );
}

http.Client _receiptThenApprovalRpc({
  required List<Map<String, dynamic>?> receiptResults,
}) {
  var receiptIndex = 0;
  return MockClient((req) async {
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    final method = body['method'] as String;
    if (method == 'eth_getTransactionReceipt') {
      final result =
          receiptResults[receiptIndex < receiptResults.length
              ? receiptIndex
              : receiptResults.length - 1];
      receiptIndex++;
      return http.Response(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': 1,
          'result': result,
        }),
        200,
      );
    }

    expect(method, 'eth_call');
    final params = body['params'] as List<dynamic>;
    final call = params[0] as Map<String, dynamic>;
    final input = (call['input'] as String).toLowerCase();
    final isAllowance = input.startsWith('0xdd62ed3e');
    final isApprovalForAll = input.startsWith('0xe985e9c5');
    final isBalanceOf = input.startsWith('0x70a08231');
    expect(isAllowance || isApprovalForAll || isBalanceOf, isTrue);
    return _rpcResult(_word(1));
  });
}

http.Client _approvalRpc({
  Set<int> missingApprovalIndexes = const <int>{},
  BigInt? pusdBalance,
}) {
  var callIndex = 0;
  return MockClient((req) async {
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body['method'], 'eth_call');
    final params = body['params'] as List<dynamic>;
    final call = params[0] as Map<String, dynamic>;
    final input = (call['input'] as String).toLowerCase();
    final isAllowance = input.startsWith('0xdd62ed3e');
    final isApprovalForAll = input.startsWith('0xe985e9c5');
    final isBalanceOf = input.startsWith('0x70a08231');
    expect(isAllowance || isApprovalForAll || isBalanceOf, isTrue);

    if (isBalanceOf) {
      return _rpcResult(_wordBigInt(pusdBalance ?? BigInt.one));
    }
    final ready = !missingApprovalIndexes.contains(callIndex);
    callIndex++;
    return _rpcResult(_word(ready ? 1 : 0));
  });
}

http.Response _rpcResult(String result) {
  return http.Response(
    jsonEncode(<String, Object>{'jsonrpc': '2.0', 'id': 1, 'result': result}),
    200,
  );
}

String _word(int value) => _wordBigInt(BigInt.from(value));

String _wordBigInt(BigInt value) {
  return '0x${value.toRadixString(16).padLeft(64, '0')}';
}
