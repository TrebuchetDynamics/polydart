// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/auth/l2.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/relayer/relayer_client.dart';
import 'package:polydart/src/relayer/relayer_types.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:test/test.dart';

const _builder = BuilderConfig(
  key: 'aaaaaaaa-bbbb-cccc-dddd-eeeeffff0001',
  // 32 bytes of zeros, base64-encoded.
  secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  passphrase: 'pass',
);

RelayerClient _client(Future<http.Response> Function(http.BaseRequest) handler) {
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
  group('constructor', () {
    test('throws when builder credentials are incomplete', () {
      expect(
        () => RelayerClient(
          builderConfig: const BuilderConfig(
            key: '',
            secret: '',
            passphrase: '',
          ),
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('getNonce', () {
    test('GETs /nonce with address+type query and POLY_BUILDER_* headers',
        () async {
      Uri? capturedUrl;
      Map<String, String>? capturedHeaders;
      final client = _client((req) async {
        capturedUrl = req.url;
        capturedHeaders = req.headers;
        return http.Response(
          jsonEncode(<String, dynamic>{'nonce': '7'}),
          200,
        );
      });

      final nonce = await client.getNonce(
        ownerAddress: '0xb72dbe5d44c1b549351bef276ba48a1cca5df662',
      );

      expect(capturedUrl!.path, '/nonce');
      expect(
        capturedUrl!.queryParameters['address'],
        '0xb72dbe5d44c1b549351bef276ba48a1cca5df662',
      );
      expect(capturedUrl!.queryParameters['type'], 'WALLET');
      expect(capturedHeaders!['POLY_BUILDER_API_KEY'], _builder.key);
      expect(capturedHeaders!['POLY_BUILDER_PASSPHRASE'], _builder.passphrase);
      expect(capturedHeaders!['POLY_BUILDER_TIMESTAMP'], '1700000000');
      expect(capturedHeaders!['POLY_BUILDER_SIGNATURE'], isNotNull);
      expect(nonce, '7');
    });

    test('throws when relayer returns empty nonce', () async {
      final client = _client((req) async {
        return http.Response(jsonEncode(<String, dynamic>{'nonce': '  '}), 200);
      });
      expect(
        () => client.getNonce(ownerAddress: '0xabc'),
        throwsA(isA<TransportException>()),
      );
    });
  });

  group('isDeployed', () {
    test('GETs /deployed and parses the boolean', () async {
      Uri? capturedUrl;
      final client = _client((req) async {
        capturedUrl = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'deployed': true,
            'address': '0xfeed',
          }),
          200,
        );
      });

      final resp = await client.isDeployed(ownerAddress: '0xowner');
      expect(capturedUrl!.path, '/deployed');
      expect(capturedUrl!.queryParameters['address'], '0xowner');
      expect(resp.deployed, isTrue);
      expect(resp.address, '0xfeed');
    });
  });

  group('submitWalletCreate', () {
    test('POSTs /submit with WALLET-CREATE shape', () async {
      Map<String, dynamic>? capturedBody;
      final client = _client((req) async {
        capturedBody = jsonDecode(req is http.Request ? req.body : '')
            as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'transactionID': 'tx-1',
            'state': 'STATE_NEW',
            'type': 'WALLET-CREATE',
            'proxyAddress': '0xWallet',
          }),
          200,
        );
      });

      final tx = await client.submitWalletCreate(ownerAddress: '0xowner');
      expect(capturedBody!['type'], 'WALLET-CREATE');
      expect(capturedBody!['from'], '0xowner');
      expect(capturedBody!['to'], depositWalletFactoryAddr);
      expect(tx.transactionId, 'tx-1');
      expect(tx.parsedState, RelayerTransactionState.newState);
      expect(tx.proxyAddress, '0xWallet');
    });
  });

  group('submitWalletBatch', () {
    test('POSTs /submit with WALLET shape and nested params', () async {
      Map<String, dynamic>? capturedBody;
      final client = _client((req) async {
        capturedBody = jsonDecode(req is http.Request ? req.body : '')
            as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'transactionID': 'tx-2',
            'state': 'STATE_EXECUTED',
          }),
          200,
        );
      });

      final tx = await client.submitWalletBatch(
        ownerAddress: '0xowner',
        walletAddress: '0xwallet',
        nonce: '3',
        signature: '0xdeadbeef',
        deadline: '1700000300',
        calls: <DepositWalletCall>[
          const DepositWalletCall(
            target: '0xtoken',
            value: '0',
            data: '0xabcd',
          ),
        ],
      );

      expect(capturedBody!['type'], 'WALLET');
      expect(capturedBody!['nonce'], '3');
      expect(capturedBody!['signature'], '0xdeadbeef');
      final params = capturedBody!['depositWalletParams'] as Map<String, dynamic>;
      expect(params['depositWallet'], '0xwallet');
      expect(params['deadline'], '1700000300');
      expect((params['calls'] as List).length, 1);
      expect(tx.parsedState, RelayerTransactionState.executed);
    });

    test('rejects empty calls list', () async {
      final client = _client((_) async => http.Response('', 200));
      expect(
        () => client.submitWalletBatch(
          ownerAddress: '0xowner',
          walletAddress: '0xwallet',
          nonce: '1',
          signature: '0x',
          deadline: '0',
          calls: const <DepositWalletCall>[],
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('pollTransaction', () {
    test('returns when state reaches STATE_MINED', () async {
      final states = <String>['STATE_NEW', 'STATE_EXECUTED', 'STATE_MINED'];
      var idx = 0;
      final client = _client((req) async {
        final state = states[idx.clamp(0, states.length - 1)];
        idx++;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'transactionID': 'tx-9',
            'state': state,
          }),
          200,
        );
      });

      final tx = await client.pollTransaction(
        txId: 'tx-9',
        maxAttempts: 5,
        interval: const Duration(milliseconds: 1),
        sleep: (_) async {}, // skip the wait
      );
      expect(tx.parsedState, RelayerTransactionState.mined);
    });

    test('throws on terminal failure state', () async {
      final client = _client((req) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'transactionID': 'tx-9',
            'state': 'STATE_FAILED',
          }),
          200,
        );
      });
      expect(
        () => client.pollTransaction(
          txId: 'tx-9',
          maxAttempts: 1,
          sleep: (_) async {},
        ),
        throwsA(isA<TransportException>()),
      );
    });

    test('throws on timeout when max attempts exhausted', () async {
      final client = _client((req) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'transactionID': 'tx-9',
            'state': 'STATE_NEW',
          }),
          200,
        );
      });
      expect(
        () => client.pollTransaction(
          txId: 'tx-9',
          maxAttempts: 2,
          interval: const Duration(milliseconds: 1),
          sleep: (_) async {},
        ),
        throwsA(isA<TransportException>()),
      );
    });
  });
}
