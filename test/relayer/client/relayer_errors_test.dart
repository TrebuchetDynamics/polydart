import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/relayer/relayer_client.dart';
import 'package:polydart/src/relayer/relayer_errors.dart';
import 'package:polydart/src/relayer/relayer_types.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:test/test.dart';

import '../support/relayer_test_support.dart';

void main() {
  group('RelayerError', () {
    test('decodes structured relayer error response', () {
      final err = RelayerError.fromJson(const <String, dynamic>{
        'error': 'invalid authorization',
        'code': 401,
      });

      expect(err.error, 'invalid authorization');
      expect(err.code, 401);
    });

    test('defaults missing optional code to null', () {
      final err = RelayerError.fromJson(const <String, dynamic>{
        'error': 'transaction not found',
      });

      expect(err.error, 'transaction not found');
      expect(err.code, isNull);
    });
  });

  group('classifyRelayerAllowlistError', () {
    test('matches upstream allowlist rejection markers case-insensitively', () {
      const cases = <String>[
        'setApprovalForAll operator 0xabc is not in the allowed list',
        'calls to 0xabc are not permitted',
        'call blocked: call[0] blocked',
        'HTTP 400: NOT IN THE ALLOWED LIST',
      ];

      for (final message in cases) {
        final err = classifyRelayerAllowlistError(StateError(message));
        expect(err, isA<RelayerAllowlistBlockedException>());
        expect(
          err.toString(),
          allOf(contains(relayerAllowlistBlockedCode), contains(message)),
        );
      }
    });

    test('passes through unrelated errors and null', () {
      final err = StateError('HTTP 500: internal server error');

      expect(classifyRelayerAllowlistError(null), isNull);
      expect(identical(classifyRelayerAllowlistError(err), err), isTrue);
    });
  });

  test('submitWalletBatch wraps allowlist transport errors', () async {
    final client = RelayerClient(
      builderConfig: testBuilderConfig,
      transport: HttpTransport(
        config: const TransportConfig(
          baseUrl: defaultRelayerBaseUrl,
          retryMax: 0,
        ),
        inner: MockClient((_) async {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'error':
                  'call blocked: setApprovalForAll operator 0xabc is not in the allowed list',
            }),
            400,
          );
        }),
      ),
      clock: fixedRelayerClock,
    );

    await expectLater(
      client.submitWalletBatch(
        ownerAddress: '0xowner',
        walletAddress: '0xwallet',
        nonce: '1',
        signature: '0xsignature',
        deadline: '1700000300',
        calls: const <DepositWalletCall>[
          DepositWalletCall(target: '0xtarget', value: '0', data: '0xdata'),
        ],
      ),
      throwsA(isA<RelayerAllowlistBlockedException>()),
    );
  });
}
