import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/transport/circuit_breaker.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/rate_limit.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:test/test.dart';

import '../shared/transport_test_harness.dart';

void main() {
  const config = TransportConfig(
    baseUrl: 'https://example.test',
    retryMax: 2,
    retryDelay: Duration(milliseconds: 1),
  );

  group('GET success path', () {
    test('decodes a JSON map', () async {
      final calls = <Uri>[];
      final transport = HttpTransport(
        config: config,
        inner: MockClient((req) async {
          calls.add(req.url);
          return http.Response('{"ok": true}', 200);
        }),
      );
      final body = await transport.getJson('/health');
      expect(body, {'ok': true});
      expect(calls.single.toString(), 'https://example.test/health');
    });

    test('appends query params (skipping empty values)', () async {
      Uri? captured;
      final transport = HttpTransport(
        config: config,
        inner: MockClient((req) async {
          captured = req.url;
          return http.Response('{}', 200);
        }),
      );
      await transport.getJson(
        '/markets',
        query: {'limit': '5', 'tag': '', 'q': 'btc 5m'},
      );
      expect(captured!.queryParameters['limit'], '5');
      expect(captured!.queryParameters.containsKey('tag'), isFalse);
      expect(captured!.queryParameters['q'], 'btc 5m');
    });

    test('decodes a JSON list', () async {
      final transport = HttpTransport(
        config: config,
        inner: MockClient((req) async => http.Response('[1,2,3]', 200)),
      );
      final list = await transport.getJsonList('/list');
      expect(list, [1, 2, 3]);
    });
  });

  group('retry behavior', () {
    test('GET retries on 5xx then succeeds', () async {
      var attempts = 0;
      final transport = HttpTransport(
        config: config,
        inner: MockClient((req) async {
          attempts++;
          if (attempts < 3) {
            return http.Response('boom', 503);
          }
          return http.Response('{"ok": true}', 200);
        }),
      );
      final body = await transport.getJson('/x');
      expect(body, {'ok': true});
      expect(attempts, 3);
    });

    test('GET retries on 429 then succeeds', () async {
      var attempts = 0;
      final transport = HttpTransport(
        config: config,
        inner: MockClient((req) async {
          attempts++;
          if (attempts == 1) return http.Response('slow down', 429);
          return http.Response('{"ok": true}', 200);
        }),
      );
      final body = await transport.getJson('/y');
      expect(body, {'ok': true});
      expect(attempts, 2);
    });

    test('GET fails after exhausting retries', () async {
      var attempts = 0;
      final transport = HttpTransport(
        config: config,
        inner: MockClient((req) async {
          attempts++;
          return http.Response('still down', 502);
        }),
      );
      await expectLater(
        transport.getJson('/z'),
        throwsA(
          isA<TransportException>().having(
            (e) => e.httpStatus,
            'httpStatus',
            502,
          ),
        ),
      );
      expect(attempts, 3); // retryMax 2 + initial = 3
    });

    test('POST does not retry on 5xx', () async {
      var attempts = 0;
      final transport = HttpTransport(
        config: config,
        inner: MockClient((req) async {
          attempts++;
          return http.Response('nope', 503);
        }),
      );
      await expectLater(
        transport.postJson('/p', {'k': 'v'}),
        throwsA(isA<TransportException>()),
      );
      expect(attempts, 1);
    });

    test('GET does not retry on 4xx', () async {
      var attempts = 0;
      final transport = HttpTransport(
        config: config,
        inner: MockClient((req) async {
          attempts++;
          return http.Response('not found', 404);
        }),
      );
      await expectLater(
        transport.getJson('/q'),
        throwsA(isA<TransportException>()),
      );
      expect(attempts, 1);
    });

    test('4xx TransportException preserves response body', () async {
      final transport = HttpTransport(
        config: config,
        inner: MockClient((req) async {
          return http.Response('{"error":"market not found"}', 404);
        }),
      );

      await expectLater(
        transport.getJson('/missing'),
        throwsA(
          isA<TransportException>()
              .having((e) => e.httpStatus, 'httpStatus', 404)
              .having(
                (e) => e.responseBody,
                'responseBody',
                '{"error":"market not found"}',
              ),
        ),
      );
    });
  });

  group('timeout', () {
    test('surface as TransportException with timeout code', () async {
      final transport = HttpTransport(
        config: const TransportConfig(
          baseUrl: 'https://slow.test',
          timeout: Duration(milliseconds: 5),
          retryMax: 0,
        ),
        inner: MockClient((req) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        transport.getJson('/x'),
        throwsA(
          isA<TransportException>().having(
            (e) => e.code,
            'code',
            ErrorCode.timeout,
          ),
        ),
      );
    });
  });

  group('headers', () {
    test('default User-Agent behavior follows the compilation target', () {
      const isBrowser = bool.fromEnvironment('dart.library.js_interop');

      expect(config.sendUserAgentHeader, !isBrowser);
    });

    test('can omit User-Agent for browser-compatible CORS requests', () async {
      Map<String, String>? captured;
      final transport = HttpTransport(
        config: const TransportConfig(
          baseUrl: 'https://example.test',
          sendUserAgentHeader: false,
        ),
        inner: MockClient((req) async {
          captured = Map.of(req.headers);
          return http.Response('{}', 200);
        }),
      );

      await transport.getJson('/h');

      expect(captured!.containsKey('User-Agent'), isFalse);
      expect(captured!['Accept'], 'application/json');
    });

    test('caller headers and defaults are sent', () async {
      Map<String, String>? captured;
      final transport = HttpTransport(
        config: config,
        inner: MockClient((req) async {
          captured = Map.of(req.headers);
          return http.Response('{}', 200);
        }),
      );
      await transport.getJson('/h', headers: {'X-Custom': 'yes'});
      expect(captured!['User-Agent'], 'polydart/0.1');
      expect(captured!['Accept'], 'application/json');
      expect(captured!['X-Custom'], 'yes');
    });

    test('circuit breaker short-circuits once tripped', () async {
      final cb = CircuitBreaker(
        config: const CircuitBreakerConfig(maxFailures: 1),
      );
      final transport = HttpTransport(
        config: config,
        circuitBreaker: cb,
        inner: MockClient((req) async => http.Response('boom', 503)),
      );
      // First call surfaces the upstream 503 (and trips the breaker).
      await expectLater(
        transport.getJson('/x'),
        throwsA(
          isA<TransportException>().having(
            (e) => e.httpStatus,
            'httpStatus',
            503,
          ),
        ),
      );
      expect(cb.state, CircuitState.open);
      // Second call is short-circuited with circuitOpen.
      await expectLater(
        transport.getJson('/x'),
        throwsA(
          isA<TransportException>().having(
            (e) => e.code,
            'code',
            ErrorCode.circuitOpen,
          ),
        ),
      );
    });

    test('rate limiter gates outbound calls', () async {
      final clock = FakeClock();
      final rl = RateLimiter(requestsPerSecond: 1000, now: clock.call);
      // pre-drain
      drainRateLimiter(rl);
      final transport = HttpTransport(
        config: config,
        rateLimiter: rl,
        inner: MockClient((req) async => http.Response('{"ok": true}', 200)),
      );
      // Advance the clock to refill before each call.
      clock.advance(const Duration(seconds: 1));
      await transport.getJson('/x');
    });

    test('POST sets content-type and serializes body', () async {
      String? capturedBody;
      String? capturedContentType;
      final transport = HttpTransport(
        config: config,
        inner: MockClient((req) async {
          capturedBody = req.body;
          capturedContentType = req.headers['content-type'];
          return http.Response('{"echo": true}', 200);
        }),
      );
      await transport.postJson('/echo', {'a': 1, 'b': 'x'});
      expect(capturedContentType, contains('application/json'));
      expect(jsonDecode(capturedBody!), {'a': 1, 'b': 'x'});
    });
  });
}
