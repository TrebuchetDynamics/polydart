import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

const _deadline = Duration(milliseconds: 40);
const _outerBound = Duration(milliseconds: 500);
const _config = TransportConfig(
  baseUrl: 'https://example.test',
  timeout: _deadline,
  retryMax: 0,
);
final _timeoutError = isA<TransportException>().having(
  (e) => e.code,
  'code',
  ErrorCode.timeout,
);

void main() {
  group('complete attempt deadline', () {
    test('delayed body times out and stops its producer', () async {
      var canceled = false;
      var emitted = false;
      Timer? producer;
      late final StreamController<List<int>> body;
      body = StreamController<List<int>>(
        onListen: () {
          producer = Timer(const Duration(milliseconds: 200), () {
            emitted = true;
            body.add(utf8.encode('{"late":true}'));
            unawaited(body.close());
          });
        },
        onCancel: () {
          canceled = true;
          producer?.cancel();
        },
      );
      addTearDown(() {
        producer?.cancel();
        unawaited(body.close());
      });
      final transport = HttpTransport(
        config: _config,
        inner: _StreamClient(
          (_) async => http.StreamedResponse(body.stream, 200),
        ),
      );
      addTearDown(transport.close);
      final elapsed = Stopwatch()..start();
      await expectLater(
        transport.getJson('/slow').timeout(_outerBound),
        throwsA(_timeoutError),
      );
      expect(elapsed.elapsed, lessThan(_outerBound));
      expect(canceled, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 220));
      expect(emitted, isFalse);
    });

    test('never-ending body is canceled and client remains reusable', () async {
      var canceled = false;
      final body = StreamController<List<int>>(
        onCancel: () {
          canceled = true;
        },
      );
      addTearDown(() {
        unawaited(body.close());
      });
      var calls = 0;
      final client = _StreamClient((_) async {
        calls++;
        return calls == 1
            ? http.StreamedResponse(body.stream, 200)
            : http.StreamedResponse(
                Stream.value(utf8.encode('{"ok":true}')),
                200,
              );
      });
      final transport = HttpTransport(config: _config, inner: client);
      addTearDown(transport.close);
      final elapsed = Stopwatch()..start();
      await expectLater(
        transport.getJson('/never').timeout(_outerBound),
        throwsA(_timeoutError),
      );
      expect(elapsed.elapsed, lessThan(_outerBound));
      expect(canceled, isTrue);
      expect(client.closed, isFalse);
      expect(await transport.getJson('/next'), {'ok': true});
      expect(calls, 2);
    });

    test(
      'slow headers time out and late body is canceled without reading',
      () async {
        final headers = Completer<http.StreamedResponse>();
        var canceled = false;
        var delivered = 0;
        final body = StreamController<List<int>>(
          onCancel: () {
            canceled = true;
          },
        );
        addTearDown(() {
          unawaited(body.close());
        });
        final transport = HttpTransport(
          config: _config,
          inner: _StreamClient((_) => headers.future),
        );
        addTearDown(transport.close);
        final elapsed = Stopwatch()..start();
        await expectLater(
          transport.getJson('/headers').timeout(_outerBound),
          throwsA(_timeoutError),
        );
        expect(elapsed.elapsed, lessThan(_outerBound));
        headers.complete(
          http.StreamedResponse(
            body.stream.map((chunk) {
              delivered++;
              return chunk;
            }),
            200,
          ),
        );
        body.add(utf8.encode('{"late":true}'));
        await Future<void>.delayed(Duration.zero);
        expect(canceled, isTrue);
        expect(delivered, 0);
      },
    );

    test('headers and body share one budget, not separate timeouts', () async {
      Timer? producer;
      late final StreamController<List<int>> body;
      body = StreamController<List<int>>(
        onListen: () {
          producer = Timer(const Duration(milliseconds: 160), () {
            body.add(utf8.encode('{}'));
            unawaited(body.close());
          });
        },
        onCancel: () {
          producer?.cancel();
        },
      );
      // Each phase fits 240 ms; their combined 320 ms does not.
      addTearDown(() {
        producer?.cancel();
        unawaited(body.close());
      });
      final transport = HttpTransport(
        config: const TransportConfig(
          baseUrl: 'https://example.test',
          timeout: Duration(milliseconds: 240),
          retryMax: 0,
        ),
        inner: _StreamClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 160));
          return http.StreamedResponse(body.stream, 200);
        }),
      );
      addTearDown(transport.close);
      await expectLater(
        transport.getJson('/budget').timeout(_outerBound),
        throwsA(_timeoutError),
      );
    });

    test('GET retries are bounded and cancel each abandoned body', () async {
      var calls = 0;
      var canceled = 0;
      final bodies = <StreamController<List<int>>>[];
      final transport = HttpTransport(
        config: const TransportConfig(
          baseUrl: 'https://example.test',
          timeout: _deadline,
          retryMax: 2,
          retryDelay: Duration(milliseconds: 1),
        ),
        inner: _StreamClient((_) async {
          calls++;
          final body = StreamController<List<int>>(
            onCancel: () {
              canceled++;
            },
          );
          bodies.add(body);
          return http.StreamedResponse(body.stream, 200);
        }),
      );
      addTearDown(() {
        transport.close();
        for (final body in bodies) {
          unawaited(body.close());
        }
      });
      final elapsed = Stopwatch()..start();
      await expectLater(
        transport.getJson('/retries').timeout(_outerBound),
        throwsA(_timeoutError),
      );
      expect(elapsed.elapsed, lessThan(_outerBound));
      expect(calls, 3);
      expect(canceled, 3);
    });

    test(
      'abort trigger fires for a request with never-arriving headers',
      () async {
        final aborted = Completer<void>();
        final transport = HttpTransport(
          config: _config,
          inner: _StreamClient((request) async {
            final abortable = request as http.AbortableRequest;
            await abortable.abortTrigger;
            aborted.complete();
            throw http.RequestAbortedException(request.url);
          }),
        );
        addTearDown(transport.close);
        await expectLater(
          transport.getJson('/abort').timeout(_outerBound),
          throwsA(_timeoutError),
        );
        await aborted.future.timeout(_outerBound);
      },
    );

    test(
      'chunks do not reset the deadline and delivery stops on cancel',
      () async {
        var delivered = 0;
        Timer? producer;
        late final StreamController<List<int>> body;
        body = StreamController<List<int>>(
          onListen: () {
            producer = Timer.periodic(const Duration(milliseconds: 5), (_) {
              delivered++;
              body.add([32]);
            });
          },
          onCancel: () {
            producer?.cancel();
          },
        );
        final transport = HttpTransport(
          config: _config,
          inner: _StreamClient(
            (_) async => http.StreamedResponse(body.stream, 200),
          ),
        );
        addTearDown(() {
          transport.close();
          producer?.cancel();
          unawaited(body.close());
        });
        await expectLater(
          transport.getJson('/drip').timeout(_outerBound),
          throwsA(_timeoutError),
        );
        expect(delivered, greaterThan(0));
        final stoppedAt = delivered;
        await Future<void>.delayed(_deadline);
        expect(delivered, stoppedAt);
      },
    );

    test('stalled cancellation cannot extend timeout', () async {
      final cleanup = Completer<void>();
      var cancelStarted = false;
      final body = StreamController<List<int>>(
        onCancel: () {
          cancelStarted = true;
          return cleanup.future;
        },
      );
      final transport = HttpTransport(
        config: _config,
        inner: _StreamClient(
          (_) async => http.StreamedResponse(body.stream, 200),
        ),
      );
      addTearDown(() {
        cleanup.complete();
        transport.close();
        unawaited(body.close());
      });
      await expectLater(
        transport.getJson('/cleanup').timeout(_outerBound),
        throwsA(_timeoutError),
      );
      expect(cancelStarted, isTrue);
      expect(cleanup.isCompleted, isFalse);
    });

    test('GET can succeed after a canceled body timeout', () async {
      var calls = 0;
      var canceled = false;
      final body = StreamController<List<int>>(
        onCancel: () {
          canceled = true;
        },
      );
      final transport = HttpTransport(
        config: const TransportConfig(
          baseUrl: 'https://example.test',
          timeout: _deadline,
          retryMax: 1,
          retryDelay: Duration.zero,
        ),
        inner: _StreamClient((_) async {
          calls++;
          return calls == 1
              ? http.StreamedResponse(body.stream, 200)
              : http.StreamedResponse(
                  Stream.value(utf8.encode('{"ok":true}')),
                  200,
                );
        }),
      );
      addTearDown(() {
        transport.close();
        unawaited(body.close());
      });
      expect(await transport.getJson('/recover').timeout(_outerBound), {
        'ok': true,
      });
      expect(calls, 2);
      expect(canceled, isTrue);
    });

    test('chunked success and HTTP error bodies preserve parsing', () async {
      final transport = HttpTransport(
        config: _config,
        inner: _StreamClient(
          (request) async => http.StreamedResponse(
            Stream.fromIterable([
              utf8.encode('{"message":"'),
              utf8.encode('café"}'),
            ]),
            request.url.path == '/error' ? 400 : 200,
            headers: {'content-type': 'application/json; charset=utf-8'},
            request: request,
          ),
        ),
      );
      addTearDown(transport.close);
      expect(await transport.getJson('/ok'), {'message': 'café'});
      await expectLater(
        transport.getJson('/error'),
        throwsA(
          isA<TransportException>()
              .having((e) => e.code, 'code', ErrorCode.connectionFailed)
              .having((e) => e.httpStatus, 'httpStatus', 400)
              .having(
                (e) => e.responseBody,
                'responseBody',
                '{"message":"café"}',
              ),
        ),
      );
    });

    test(
      'body buffering preserves chunks when a producer reuses storage',
      () async {
        Stream<List<int>> chunks() async* {
          final buffer = Uint8List.fromList([65]);
          yield buffer;
          buffer[0] = 66;
          yield buffer;
        }

        final transport = HttpTransport(
          config: _config,
          inner: _StreamClient(
            (_) async => http.StreamedResponse(chunks(), 200),
          ),
        );
        addTearDown(transport.close);
        expect(await transport.getBytes('/bytes'), [65, 66]);
      },
    );

    for (final method in ['POST', 'DELETE', 'bytes']) {
      test('$method does not retry on body timeout', () async {
        var calls = 0;
        var canceled = false;
        final body = StreamController<List<int>>(
          onCancel: () {
            canceled = true;
          },
        );
        final transport = HttpTransport(
          config: const TransportConfig(
            baseUrl: 'https://example.test',
            timeout: _deadline,
            retryMax: 2,
          ),
          inner: _StreamClient((_) async {
            calls++;
            return http.StreamedResponse(body.stream, 200);
          }),
        );
        addTearDown(() {
          transport.close();
          unawaited(body.close());
        });
        final request = switch (method) {
          'POST' => transport.postJson('/mutation', {'key': 'value'}),
          'DELETE' => transport.delete('/mutation'),
          _ => transport.getBytes('/bytes'),
        };
        await expectLater(request.timeout(_outerBound), throwsA(_timeoutError));
        expect(calls, 1);
        expect(canceled, isTrue);
      });
    }
  });
}

final class _StreamClient extends http.BaseClient {
  _StreamClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);

  @override
  void close() {
    closed = true;
  }
}
