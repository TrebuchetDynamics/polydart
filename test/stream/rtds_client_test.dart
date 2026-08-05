import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:polydart/polydart.dart';
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

  void pushError(Object error) => _incoming.addError(error);

  Future<void> closeIncoming() => _incoming.close();
}

class _FakeWebSocketSink extends DelegatingStreamSink<dynamic>
    implements WebSocketSink {
  _FakeWebSocketSink(this._controller) : super(_controller.sink);

  final StreamController<dynamic> _controller;

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_controller.isClosed) unawaited(_controller.close());
  }
}

void main() {
  test(
    'uses the default endpoint and encodes both crypto topic filters',
    () async {
      final channel = _FakeWebSocketChannel();
      Uri? opened;
      final client = RtdsClient(
        channelFactory: (url) {
          opened = url;
          return channel;
        },
      );
      addTearDown(client.close);
      final queue = StreamQueue<dynamic>(channel.outbound);
      addTearDown(queue.cancel);

      client.subscribeCryptoPrices(
        topic: rtdsCryptoPricesTopic,
        symbols: const ['btcusdt', 'ethusdt'],
      );
      final binance =
          jsonDecode(await queue.next as String) as Map<String, dynamic>;

      client.subscribeCryptoPrices(
        topic: rtdsCryptoPricesChainlinkTopic,
        symbols: const ['eth/usd'],
      );
      final chainlink =
          jsonDecode(await queue.next as String) as Map<String, dynamic>;

      expect(opened.toString(), defaultRtdsUrl);
      expect(binance, <String, dynamic>{
        'action': 'subscribe',
        'subscriptions': [
          <String, dynamic>{
            'topic': 'crypto_prices',
            'type': 'update',
            'filters': 'btcusdt,ethusdt',
          },
        ],
      });
      expect((chainlink['subscriptions'] as List).single, <String, dynamic>{
        'topic': 'crypto_prices_chainlink',
        'type': '*',
        'filters': jsonEncode(<String, String>{'symbol': 'eth/usd'}),
      });
    },
  );

  test('encodes an unfiltered Chainlink subscription explicitly', () async {
    final channel = _FakeWebSocketChannel();
    final client = RtdsClient(channelFactory: (_) => channel);
    addTearDown(client.close);

    client.subscribeCryptoPrices(
      topic: rtdsCryptoPricesChainlinkTopic,
      symbols: const <String>[],
    );
    final payload =
        jsonDecode(await channel.outbound.first as String)
            as Map<String, dynamic>;

    expect((payload['subscriptions'] as List).single, <String, dynamic>{
      'topic': 'crypto_prices_chainlink',
      'type': '*',
      'filters': '',
    });
  });

  test('decodes historical payload.data and live decimal prices', () async {
    final channel = _FakeWebSocketChannel();
    final client = RtdsClient(
      config: const StreamConfig(url: defaultRtdsUrl, reconnect: false),
      channelFactory: (_) => channel,
    );
    addTearDown(client.close);

    final prices = client.subscribeCryptoPrices(
      topic: rtdsCryptoPricesChainlinkTopic,
      symbols: const ['eth/usd'],
    );
    final received = prices.take(3).toList();
    await channel.outbound.first;

    channel.push(
      jsonEncode(<String, dynamic>{
        'topic': rtdsCryptoPricesChainlinkTopic,
        'payload': <String, dynamic>{
          'symbol': 'eth/usd',
          'data': [
            <String, dynamic>{'timestamp': 1000, 'value': '3400.01'},
            <String, dynamic>{'timestamp': '2000', 'value': 3410.02},
          ],
        },
      }),
    );
    channel.push(
      jsonEncode(<String, dynamic>{
        'topic': rtdsCryptoPricesChainlinkTopic,
        'payload': <String, dynamic>{
          'symbol': 'eth/usd',
          'timestamp': 3000,
          'value': '3420.15',
        },
      }),
    );

    final values = await received.timeout(const Duration(milliseconds: 250));
    expect(values.map((event) => event.symbol), everyElement('eth/usd'));
    expect(values.map((event) => event.timestamp), [1000, 2000, 3000]);
    expect(values.map((event) => event.price), [
      '3400.01',
      '3410.02',
      '3420.15',
    ]);
  });

  test('sends PING and reconnects with the previous subscriptions', () async {
    final channels = <_FakeWebSocketChannel>[];
    final secondChannel = Completer<_FakeWebSocketChannel>();
    final client = RtdsClient(
      config: const StreamConfig(
        url: defaultRtdsUrl,
        pingInterval: Duration(milliseconds: 1),
        reconnect: true,
        reconnectDelay: Duration.zero,
        reconnectMaxDelay: Duration.zero,
        reconnectMax: 1,
      ),
      channelFactory: (_) {
        final channel = _FakeWebSocketChannel();
        channels.add(channel);
        if (channels.length == 2) secondChannel.complete(channel);
        return channel;
      },
    );
    addTearDown(client.close);

    client.subscribeCryptoPrices(
      topic: rtdsCryptoPricesTopic,
      symbols: const ['btcusdt'],
    );
    await Future<void>.delayed(Duration.zero);
    final firstQueue = StreamQueue<dynamic>(channels.single.outbound);
    addTearDown(firstQueue.cancel);
    await firstQueue.next;
    expect(await firstQueue.next, 'PING');

    await channels.single.closeIncoming();
    final reconnected = await secondChannel.future.timeout(
      const Duration(milliseconds: 250),
    );
    final payload =
        jsonDecode(
              await reconnected.outbound.first.timeout(
                    const Duration(milliseconds: 250),
                  )
                  as String,
            )
            as Map<String, dynamic>;
    expect(
      ((payload['subscriptions'] as List).single as Map)['filters'],
      'btcusdt',
    );
  });

  test(
    'surfaces socket errors without throwing from the returned stream',
    () async {
      final channel = _FakeWebSocketChannel();
      final client = RtdsClient(
        config: const StreamConfig(url: defaultRtdsUrl, reconnect: false),
        channelFactory: (_) => channel,
      );
      addTearDown(client.close);

      client.subscribeCryptoPrices(
        topic: rtdsCryptoPricesTopic,
        symbols: const ['btcusdt'],
      );
      final error = client.errors.first;
      await channel.outbound.first;
      channel.pushError(StateError('socket failed'));

      expect(await error, isA<StateError>());
    },
  );
}
