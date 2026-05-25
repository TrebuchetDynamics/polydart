import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart' show DelegatingStreamSink;
import 'package:polydart/src/auth/l2.dart';
import 'package:polydart/src/errors/errors.dart';
import 'package:polydart/src/stream/stream_config.dart';
import 'package:polydart/src/stream/user_client.dart';
import 'package:stream_channel/stream_channel.dart' show StreamChannelMixin;
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _FakeWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _FakeWebSocketChannel()
    : _incoming = StreamController<dynamic>(),
      _outgoing = StreamController<dynamic>() {
    sink = _FakeWebSocketSink(_outgoing);
    outbound = _outgoing.stream;
  }

  final StreamController<dynamic> _incoming;
  final StreamController<dynamic> _outgoing;
  late final Stream<dynamic> outbound;

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

  void push(String frame) => _incoming.add(frame);
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

const _apiKey = ApiKey(key: 'key', secret: 'secret', passphrase: 'pass');

void main() {
  group('UserClient', () {
    late _FakeWebSocketChannel channel;
    late UserClient client;

    setUp(() {
      channel = _FakeWebSocketChannel();
      client = UserClient(
        config: const StreamConfig(
          url: defaultUserStreamUrl,
          reconnect: false,
          pingInterval: Duration(milliseconds: 10),
        ),
        credentials: _apiKey,
        channelFactory: (_) => channel,
      );
    });

    tearDown(() async {
      await client.close();
    });

    test('default URL targets the authenticated user stream', () {
      expect(
        defaultUserStreamUrl,
        'wss://ws-subscriptions-clob.polymarket.com/ws/user',
      );
    });

    test('connect + subscribeUser writes auth envelope', () async {
      final outboundFuture = channel.outbound.first;
      await client.connect();
      expect(client.isConnected, isTrue);
      await client.subscribeUser(markets: <String>['condition-1']);

      final raw = await outboundFuture;
      final body = jsonDecode(raw as String) as Map<String, dynamic>;
      expect(body['type'], 'user');
      expect(body['markets'], <String>['condition-1']);
      expect(body['auth'], <String, dynamic>{
        'apiKey': 'key',
        'secret': 'secret',
        'passphrase': 'pass',
      });
    });

    test('dispatches order and trade events', () async {
      await client.connect();
      final orderFuture = client.orders.first;
      final tradeFuture = client.trades.first;

      channel.push(
        jsonEncode(<String, dynamic>{
          'event_type': 'order',
          'order_id': 'ord-1',
          'market': 'condition-1',
          'asset_id': 'token-1',
          'side': 'BUY',
          'price': '0.5',
          'size': '10',
          'status': 'live',
          'timestamp': '1757908892351',
        }),
      );
      channel.push(
        jsonEncode(<String, dynamic>{
          'event_type': 'trade',
          'trade_id': 'trade-1',
          'order_id': 'ord-1',
          'market': 'condition-1',
          'asset_id': 'token-1',
          'side': 'BUY',
          'price': '0.5',
          'size': '10',
          'transaction_hash': '0xtx',
          'timestamp': '1757908892352',
        }),
      );

      final order = await orderFuture;
      expect(order.orderId, 'ord-1');
      expect(order.status, 'live');
      expect(order.assetId, 'token-1');

      final trade = await tradeFuture;
      expect(trade.tradeId, 'trade-1');
      expect(trade.transactionHash, '0xtx');
    });

    test('rejects missing credentials before opening a socket', () async {
      final bad = UserClient(
        config: const StreamConfig(url: defaultUserStreamUrl),
        credentials: const ApiKey(key: 'key', secret: '', passphrase: ''),
        channelFactory: (_) => channel,
      );
      addTearDown(bad.close);

      await expectLater(bad.connect(), throwsA(isA<AuthException>()));
    });
  });
}
