// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/auth/l2.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/relayer/relayer_client.dart';
import 'package:polydart/src/relayer/relayer_errors.dart';
import 'package:polydart/src/relayer/relayer_types.dart';
import 'package:polydart/src/relayer/v2_auth.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:test/test.dart';

import '../support/relayer_test_support.dart';

RelayerClient _client(
  Future<http.Response> Function(http.BaseRequest) handler,
) => createRelayerClient(handler);

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

    test('v2 constructor requires relayer key and address', () {
      expect(
        () => RelayerClient.v2(
          apiKey: const V2APIKey(key: '', address: '0xabc'),
        ),
        throwsA(isA<AuthException>()),
      );
      expect(
        () => RelayerClient.v2(
          apiKey: const V2APIKey(key: 'relayer-key', address: '  '),
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('v2 auth headers', () {
    test(
      'sends RELAYER_API_KEY headers without POLY_BUILDER headers',
      () async {
        Map<String, String>? capturedHeaders;
        final client = RelayerClient.v2(
          apiKey: const V2APIKey(key: 'relayer-key', address: '0xowner'),
          transport: HttpTransport(
            config: const TransportConfig(
              baseUrl: defaultRelayerBaseUrl,
              retryMax: 0,
            ),
            inner: MockClient((req) async {
              capturedHeaders = req.headers;
              return http.Response(
                jsonEncode(<String, dynamic>{'nonce': '11'}),
                200,
              );
            }),
          ),
        );

        final nonce = await client.getNonce(ownerAddress: '0xowner');

        expect(nonce, '11');
        expect(capturedHeaders!['RELAYER_API_KEY'], 'relayer-key');
        expect(capturedHeaders!['RELAYER_API_KEY_ADDRESS'], '0xowner');
        expect(capturedHeaders!.containsKey('POLY_BUILDER_API_KEY'), isFalse);
        expect(capturedHeaders!.containsKey('POLY_BUILDER_SIGNATURE'), isFalse);
      },
    );
  });

  group('getNonce', () {
    test(
      'GETs /nonce with address+type query and POLY_BUILDER_* headers',
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
        expect(capturedHeaders!['POLY_BUILDER_API_KEY'], testBuilderConfig.key);
        expect(
          capturedHeaders!['POLY_BUILDER_PASSPHRASE'],
          testBuilderConfig.passphrase,
        );
        expect(capturedHeaders!['POLY_BUILDER_TIMESTAMP'], '1700000000');
        expect(capturedHeaders!['POLY_BUILDER_SIGNATURE'], isNotNull);
        expect(nonce, '7');
      },
    );

    test('accepts numeric scalar nonce response drift', () async {
      final client = _client((req) async {
        return http.Response('7', 200);
      });

      expect(await client.getNonce(ownerAddress: '0xabc'), '7');
    });

    test('accepts walletNonce aliases', () {
      expect(
        NonceResponse.fromJson(const <String, dynamic>{'walletNonce': 8}).nonce,
        '8',
      );
      expect(
        NonceResponse.fromJson(const <String, dynamic>{
          'wallet_nonce': '9',
        }).nonce,
        '9',
      );
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

    test('wraps structured relayer error responses', () async {
      final client = _client((req) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'error': 'invalid authorization',
            'code': '401',
          }),
          401,
        );
      });

      await expectLater(
        client.getNonce(ownerAddress: '0xabc'),
        throwsA(
          isA<RelayerApiException>()
              .having((e) => e.error.error, 'error', 'invalid authorization')
              .having((e) => e.error.code, 'code', 401),
        ),
      );
    });
  });

  group('isDeployed', () {
    test('DeployedResponse decodes string boolean and numeric address', () {
      final resp = DeployedResponse.fromJson(<String, dynamic>{
        'deployed': 'true',
        'address': 123,
      });

      expect(resp.deployed, isTrue);
      expect(resp.address, '123');
    });

    test('DeployedResponse accepts bool/address alias drift', () {
      final lowerCamel = DeployedResponse.fromJson(const <String, dynamic>{
        'isDeployed': '1',
        'walletAddress': '0xwallet',
      });
      final snake = DeployedResponse.fromJson(const <String, dynamic>{
        'deployed': 1,
        'proxy_address': '0xproxy',
      });
      final depositWallet = DeployedResponse.fromJson(const <String, dynamic>{
        'deposit_wallet': '0xdeposit',
      });

      expect(lowerCamel.deployed, isTrue);
      expect(lowerCamel.address, '0xwallet');
      expect(snake.deployed, isTrue);
      expect(snake.address, '0xproxy');
      expect(depositWallet.deployed, isFalse);
      expect(depositWallet.address, '0xdeposit');
    });

    test('GETs /deployed and parses the boolean', () async {
      Uri? capturedUrl;
      final client = _client((req) async {
        capturedUrl = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{'deployed': true, 'address': '0xfeed'}),
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

  group('getTransaction', () {
    test('parses object response', () async {
      final client = _client((req) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'transactionID': 'tx-object',
            'transactionHash': '0xabc',
            'state': 'STATE_CONFIRMED',
            'type': 'WALLET-CREATE',
          }),
          200,
        );
      });

      final tx = await client.getTransaction(txId: 'tx-object');

      expect(tx.transactionId, 'tx-object');
      expect(tx.transactionHash, '0xabc');
      expect(tx.parsedState, RelayerTransactionState.confirmed);
    });

    test('parses snake_case aliases and numeric scalar fields', () async {
      final client = _client((req) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'transaction_id': 'tx-snake',
            'transaction_hash': '0xabc',
            'proxy_address': '0xwallet',
            'nonce': 7,
            'value': 0,
            'state': 'STATE_MINED',
            'type': 'WALLET',
            'created_at': '2026-05-24T00:00:00Z',
            'updated_at': '2026-05-24T00:01:00Z',
          }),
          200,
        );
      });

      final tx = await client.getTransaction(txId: 'tx-snake');

      expect(tx.transactionId, 'tx-snake');
      expect(tx.transactionHash, '0xabc');
      expect(tx.proxyAddress, '0xwallet');
      expect(tx.nonce, '7');
      expect(tx.value, '0');
      expect(tx.createdAt, isNotEmpty);
      expect(tx.updatedAt, isNotEmpty);
    });

    test('parses lower-camel transactionId alias', () async {
      final client = _client((req) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'transactionId': 'tx-lower-camel',
            'transactionHash': '0xabc',
            'state': 'STATE_MINED',
            'type': 'WALLET',
          }),
          200,
        );
      });

      final tx = await client.getTransaction(txId: 'tx-lower-camel');

      expect(tx.transactionId, 'tx-lower-camel');
      expect(tx.transactionHash, '0xabc');
    });

    test('URL-encodes transaction id query value', () async {
      Uri? capturedUrl;
      final client = _client((req) async {
        capturedUrl = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'transactionID': 'tx-query',
            'state': 'STATE_MINED',
          }),
          200,
        );
      });

      await client.getTransaction(txId: 'tx-1&ignored=true');

      expect(capturedUrl!.path, '/transaction');
      expect(capturedUrl!.queryParameters['id'], 'tx-1&ignored=true');
      expect(capturedUrl!.queryParameters.containsKey('ignored'), isFalse);
    });

    test('parses first transaction from array response', () async {
      final client = _client((req) async {
        expect(req.url.path, '/transaction');
        expect(req.url.queryParameters['id'], 'tx-array');
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'transactionID': 'tx-array',
              'transactionHash': '0xdef',
              'state': 'STATE_MINED',
              'type': 'WALLET',
            },
          ]),
          200,
        );
      });

      final tx = await client.getTransaction(txId: 'tx-array');

      expect(tx.transactionId, 'tx-array');
      expect(tx.transactionHash, '0xdef');
      expect(tx.parsedState, RelayerTransactionState.mined);
    });

    test('throws explicit not-found error for empty array response', () async {
      final client = _client((req) async {
        return http.Response(jsonEncode(<Object>[]), 200);
      });

      expect(
        () => client.getTransaction(txId: 'missing-tx'),
        throwsA(
          isA<TransportException>().having(
            (e) => e.message,
            'message',
            contains('missing-tx'),
          ),
        ),
      );
    });
  });

  group('submitWalletCreate', () {
    test('POSTs /submit with WALLET-CREATE shape', () async {
      Map<String, dynamic>? capturedBody;
      final client = _client((req) async {
        capturedBody =
            jsonDecode(req is http.Request ? req.body : '')
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
        capturedBody =
            jsonDecode(req is http.Request ? req.body : '')
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
        nonce: ' 3 ',
        signature: ' 0xdeadbeef ',
        deadline: ' 1700000300 ',
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
      final params =
          capturedBody!['depositWalletParams'] as Map<String, dynamic>;
      expect(params['depositWallet'], '0xwallet');
      expect(params['deadline'], '1700000300');
      expect((params['calls'] as List).length, 1);
      expect(tx.parsedState, RelayerTransactionState.executed);
    });

    test('rejects missing nonce signature deadline and calls', () async {
      final client = _client((_) async => http.Response('', 200));
      final validCall = const DepositWalletCall(
        target: '0xtarget',
        value: '0',
        data: '0xdata',
      );

      expect(
        () => client.submitWalletBatch(
          ownerAddress: '0xowner',
          walletAddress: '0xwallet',
          nonce: ' ',
          signature: '0xsignature',
          deadline: '1700000300',
          calls: <DepositWalletCall>[validCall],
        ),
        throwsA(
          isA<ValidationException>().having((e) => e.field, 'field', 'nonce'),
        ),
      );
      expect(
        () => client.submitWalletBatch(
          ownerAddress: '0xowner',
          walletAddress: '0xwallet',
          nonce: '1',
          signature: ' ',
          deadline: '1700000300',
          calls: <DepositWalletCall>[validCall],
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.field,
            'field',
            'signature',
          ),
        ),
      );
      expect(
        () => client.submitWalletBatch(
          ownerAddress: '0xowner',
          walletAddress: '0xwallet',
          nonce: '1',
          signature: '0xsignature',
          deadline: ' ',
          calls: <DepositWalletCall>[validCall],
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.field,
            'field',
            'deadline',
          ),
        ),
      );
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
    test(
      'uses upstream default attempts when maxAttempts is non-positive',
      () async {
        var calls = 0;
        final client = _client((req) async {
          calls++;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'transactionID': 'tx-default-attempts',
              'state': 'STATE_MINED',
            }),
            200,
          );
        });

        final tx = await client.pollTransaction(
          txId: 'tx-default-attempts',
          maxAttempts: 0,
          sleep: (_) async {},
        );

        expect(tx.transactionId, 'tx-default-attempts');
        expect(calls, 1);
      },
    );

    test(
      'uses upstream default interval when interval is non-positive',
      () async {
        final states = <String>['STATE_NEW', 'STATE_MINED'];
        final sleeps = <Duration>[];
        var idx = 0;
        final client = _client((req) async {
          final state = states[idx.clamp(0, states.length - 1)];
          idx++;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'transactionID': 'tx-default-interval',
              'state': state,
            }),
            200,
          );
        });

        final tx = await client.pollTransaction(
          txId: 'tx-default-interval',
          maxAttempts: 2,
          interval: Duration.zero,
          sleep: (duration) async => sleeps.add(duration),
        );

        expect(tx.parsedState, RelayerTransactionState.mined);
        expect(sleeps, <Duration>[const Duration(seconds: 2)]);
      },
    );

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
