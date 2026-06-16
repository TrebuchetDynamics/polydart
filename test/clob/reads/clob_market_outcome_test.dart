// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/types/clob.dart';
import 'package:test/test.dart';

import '../support/clob_test_client.dart';

/// Serves a single JSON [body] from a loopback HTTP server, standing in for
/// the Gamma API in fallback tests (the analogue of Go's httptest.Server).
Future<HttpServer> _startGamma(
  Object? body, {
  void Function(HttpRequest)? onRequest,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    onRequest?.call(req);
    req.response
      ..statusCode = 200
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await req.response.close();
  });
  return server;
}

String _gammaUrl(HttpServer s) => 'http://127.0.0.1:${s.port}';

void main() {
  group('marketOutcome', () {
    test('throws ValidationException on blank condition id', () async {
      final client = clobTestClient((req) async {
        fail('no request expected, got ${req.url}');
      });
      await expectLater(
        client.marketOutcome('   '),
        throwsA(isA<ValidationException>()),
      );
    });

    test('resolves from CLOB when closed with a single winner', () async {
      Uri? captured;
      final client = clobTestClient((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'condition_id': 'cond-1',
            'closed': true,
            'tokens': [
              <String, dynamic>{'token_id': 'yes', 'winner': true},
              <String, dynamic>{'token_id': 'no', 'winner': false},
            ],
          }),
          200,
        );
      });

      final outcome = await client.marketOutcome('cond-1');

      expect(captured!.path, '/markets/cond-1');
      expect(outcome.status, ClobMarketOutcomeStatus.resolved);
      expect(outcome.conditionId, 'cond-1');
      expect(outcome.winningTokenId, 'yes');
      expect(outcome.closed, isTrue);
      expect(outcome.source, 'clob:/markets/cond-1');
    });

    test('trims the condition id before querying', () async {
      Uri? captured;
      final client = clobTestClient((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'closed': false,
            'tokens': <Map<String, dynamic>>[],
          }),
          200,
        );
      });

      final outcome = await client.marketOutcome('  cond-1  ');

      expect(captured!.path, '/markets/cond-1');
      expect(outcome.conditionId, 'cond-1');
    });

    test('is unresolved when CLOB knows the market but it is open', () async {
      final client = clobTestClient((req) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'condition_id': 'cond-1',
            'closed': false,
            'tokens': [
              <String, dynamic>{'token_id': 'yes', 'winner': false},
            ],
          }),
          200,
        );
      });

      final outcome = await client.marketOutcome('cond-1');

      expect(outcome.status, ClobMarketOutcomeStatus.unresolved);
      expect(outcome.winningTokenId, isEmpty);
      expect(outcome.closed, isFalse);
      expect(outcome.source, 'clob:/markets/cond-1:not_closed_or_no_winner');
    });

    test('is unresolved when closed with more than one winner', () async {
      final client = clobTestClient((req) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'closed': true,
            'tokens': [
              <String, dynamic>{'token_id': 'yes', 'winner': true},
              <String, dynamic>{'token_id': 'no', 'winner': true},
            ],
          }),
          200,
        );
      });

      final outcome = await client.marketOutcome('cond-1');

      expect(outcome.status, ClobMarketOutcomeStatus.unresolved);
      expect(outcome.winningTokenId, isEmpty);
      expect(outcome.closed, isTrue);
      expect(outcome.source, 'clob:/markets/cond-1:not_closed_or_no_winner');
    });

    test('falls back to Gamma when CLOB 404s', () async {
      Uri? gammaUri;
      final gamma = await _startGamma([
        <String, dynamic>{'conditionId': 'cond-1', 'closed': true},
      ], onRequest: (req) => gammaUri = req.uri);
      addTearDown(() => gamma.close(force: true));

      final client = clobTestClient((req) async {
        return http.Response('not found', 404);
      });

      final outcome = await client.marketOutcome(
        'cond-1',
        gammaBaseUrl: _gammaUrl(gamma),
      );

      expect(gammaUri!.path, '/markets');
      expect(gammaUri!.queryParameters['condition_ids'], 'cond-1');
      expect(outcome.status, ClobMarketOutcomeStatus.unresolved);
      expect(outcome.conditionId, 'cond-1');
      expect(outcome.closed, isTrue);
      expect(outcome.source, 'gamma:closed_condition_id=cond-1');
    });

    test('rethrows the CLOB error when Gamma finds no closed market', () async {
      final gamma = await _startGamma(<Object>[]);
      addTearDown(() => gamma.close(force: true));

      final client = clobTestClient((req) async {
        return http.Response('not found', 404);
      });

      await expectLater(
        client.marketOutcome('cond-1', gammaBaseUrl: _gammaUrl(gamma)),
        throwsA(isA<TransportException>()),
      );
    });

    test('rethrows the CLOB error when no Gamma URL is given', () async {
      final client = clobTestClient((req) async {
        return http.Response('not found', 404);
      });

      await expectLater(
        client.marketOutcome('cond-1'),
        throwsA(isA<TransportException>()),
      );
    });
  });
}
