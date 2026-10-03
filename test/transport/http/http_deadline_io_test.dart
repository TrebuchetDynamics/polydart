@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:polydart/polydart.dart';
import 'package:test/test.dart';

void main() {
  for (final phase in ['headers', 'body']) {
    test('IOClient aborts stalled $phase and remains reusable', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <Socket>[];
      final received = Completer<void>();
      final disconnected = Completer<void>();
      final connections = server.listen((socket) {
        sockets.add(socket);
        var request = '';
        var handled = false;
        var stalled = false;
        socket.listen(
          (bytes) {
            if (handled) return;
            request += ascii.decode(bytes);
            if (!request.contains('\r\n\r\n')) return;
            handled = true;
            if (request.startsWith('GET /next ')) {
              socket.write(
                'HTTP/1.1 200 OK\r\nContent-Length: 11\r\n'
                'Content-Type: application/json\r\nConnection: close\r\n\r\n'
                '{"ok":true}',
              );
              unawaited(socket.flush().then((_) => socket.close()));
            } else {
              stalled = true;
              received.complete();
              if (phase == 'body') {
                socket.write(
                  'HTTP/1.1 200 OK\r\nContent-Length: 1000\r\n'
                  'Content-Type: application/json\r\n\r\n{"partial":',
                );
              }
            }
          },
          onDone: () {
            if (stalled && !disconnected.isCompleted) disconnected.complete();
          },
          onError: (Object error) {
            if (stalled && !disconnected.isCompleted) disconnected.complete();
          },
        );
      });
      final transport = HttpTransport(
        config: TransportConfig(
          baseUrl: 'http://127.0.0.1:${server.port}',
          timeout: const Duration(milliseconds: 150),
          retryMax: 0,
        ),
      );
      addTearDown(() async {
        transport.close();
        for (final socket in sockets) {
          socket.destroy();
        }
        await connections.cancel();
        await server.close();
      });
      final elapsed = Stopwatch()..start();
      await expectLater(
        transport.getJson('/stall').timeout(const Duration(seconds: 2)),
        throwsA(
          isA<TransportException>().having(
            (e) => e.code,
            'code',
            ErrorCode.timeout,
          ),
        ),
      );
      expect(elapsed.elapsed, lessThan(const Duration(seconds: 1)));
      await received.future.timeout(const Duration(seconds: 1));
      // Observe closure at the real peer, not just a fake onCancel hook.
      await disconnected.future.timeout(const Duration(seconds: 1));
      expect(await transport.getJson('/next'), {'ok': true});
    });
  }
}
