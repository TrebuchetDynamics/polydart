import 'dart:async';

import 'package:async/async.dart' show DelegatingStreamSink;
import 'package:polydart/src/stream/transport/contracts/default_channel_factory.dart';
import 'package:stream_channel/stream_channel.dart' show StreamChannelMixin;
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _FakeWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _FakeWebSocketChannel()
    : _incoming = StreamController<dynamic>(),
      _outgoing = StreamController<dynamic>() {
    sink = _FakeWebSocketSink(_outgoing);
  }

  final StreamController<dynamic> _incoming;
  final StreamController<dynamic> _outgoing;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  late final WebSocketSink sink;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  Future<void> get ready => Future<void>.value();
}

class _FakeWebSocketSink extends DelegatingStreamSink<dynamic>
    implements WebSocketSink {
  _FakeWebSocketSink(this._controller) : super(_controller.sink);

  final StreamController<dynamic> _controller;

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_controller.isClosed) {
      unawaited(_controller.close());
    }
  }
}

void main() {
  test(
    'defaultStreamWebSocketChannelFactory binds configured ping interval',
    () {
      final opened = <({Uri url, Duration pingInterval})>[];
      final expectedChannel = _FakeWebSocketChannel();
      const pingInterval = Duration(seconds: 7);
      final url = Uri.parse('wss://example.test/ws');

      final factory = defaultStreamWebSocketChannelFactory(
        pingInterval: pingInterval,
        openChannel: (url, pingInterval) {
          opened.add((url: url, pingInterval: pingInterval));
          return expectedChannel;
        },
      );

      final channel = factory(url);

      expect(channel, same(expectedChannel));
      expect(opened, hasLength(1));
      expect(opened.single.url, url);
      expect(opened.single.pingInterval, pingInterval);
    },
  );
}
