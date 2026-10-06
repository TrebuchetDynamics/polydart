import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/transport/http_transport.dart';
import 'package:polydart/src/transport/transport_config.dart';
import 'package:test/test.dart';

void main() {
  group('HTTP response stream bounds', () {
    test('reads a bounded multi-chunk JSON response', () async {
      final transport = _transport(
        _StreamClient(
          (_) => http.StreamedResponse(
            Stream<List<int>>.fromIterable([
              utf8.encode('{"ok":'),
              utf8.encode('true}'),
            ]),
            200,
          ),
        ),
      );

      expect(await transport.getJson('/bounded'), {'ok': true});
    });

    test(
      'buffers a large finite body completely; there is no size cap',
      () async {
        final payload = utf8.encode('{"data":"${'x' * 1024 * 1024}"}');
        final client = _StreamClient(
          (_) => http.StreamedResponse(
            Stream<List<int>>.fromIterable(
              List.generate((payload.length / 1024).ceil(), (index) {
                final start = index * 1024;
                final end = (start + 1024).clamp(0, payload.length);
                return payload.sublist(start, end);
              }),
            ),
            200,
          ),
        );
        final transport = _transport(client);

        expect((await transport.getJson('/large'))['data'], 'x' * 1024 * 1024);
      },
    );

    test(
      'times out an endless body, cancels its subscription, then reuses client',
      () async {
        var canceled = false;
        var calls = 0;
        late StreamController<List<int>> body;
        final client = _StreamClient((_) {
          calls++;
          if (calls == 1) {
            body = StreamController<List<int>>(onCancel: () => canceled = true);
            body.add(utf8.encode('{"partial":'));
            return http.StreamedResponse(body.stream, 200);
          }
          return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
        });
        final transport = _transport(
          client,
          timeout: const Duration(milliseconds: 30),
        );

        await expectLater(
          transport.getJson('/endless'),
          throwsA(
            isA<TransportException>().having(
              (error) => error.code,
              'code',
              ErrorCode.timeout,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 1));
        expect(canceled, isTrue);
        expect(body.hasListener, isFalse);
        expect(await transport.getJson('/reuse'), isEmpty);
        expect(calls, 2);
        transport.close();
        expect(client.closed, isTrue);
      },
    );

    test('consumes and retains the complete finite error payload', () async {
      final errorBody = '{"error":"${'e' * 4096}"}';
      final transport = _transport(
        _StreamClient(
          (_) =>
              http.StreamedResponse(Stream.value(utf8.encode(errorBody)), 404),
        ),
      );

      await expectLater(
        transport.getJson('/error'),
        throwsA(
          isA<TransportException>().having(
            (error) => error.responseBody,
            'responseBody',
            errorBody,
          ),
        ),
      );
    });
  });
}

HttpTransport _transport(
  _StreamClient client, {
  Duration timeout = const Duration(seconds: 1),
}) => HttpTransport(
  config: TransportConfig(
    baseUrl: 'https://example.test',
    timeout: timeout,
    retryMax: 0,
  ),
  inner: client,
);

final class _StreamClient extends http.BaseClient {
  _StreamClient(this.respond);

  final http.StreamedResponse Function(http.BaseRequest request) respond;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      respond(request);

  @override
  void close() => closed = true;
}
