import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart' show DelegatingStreamSink;
import 'package:polydart/src/stream/market_client.dart';
import 'package:polydart/src/stream/stream_config.dart';
import 'package:polydart/src/stream/stream_messages.dart';
import 'package:stream_channel/stream_channel.dart' show StreamChannelMixin;
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// In-memory `WebSocketChannel` used by these tests. Inbound bytes flow from
/// [push] to the client's read loop; outbound bytes (`channel.sink.add`) land
/// in [outbound] for assertions.
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
    // Avoid awaiting the underlying single-subscription StreamController's
    // `done` future — without an active listener it never completes, which
    // would deadlock teardown. Fire-and-forget the underlying close.
    if (!_controller.isClosed) {
      unawaited(_controller.close());
    }
  }
}

void main() {
  group('MarketClient', () {
    late _FakeWebSocketChannel channel;
    late MarketClient client;

    setUp(() {
      channel = _FakeWebSocketChannel();
      client = MarketClient(
        config: const StreamConfig(
          url: defaultStreamUrl,
          reconnect: false,
          pingInterval: Duration(milliseconds: 10),
        ),
        channelFactory: (_) => channel,
      );
    });

    tearDown(() async {
      await client.close();
    });

    test('connect + subscribeAssets writes the expected JSON envelope',
        () async {
      final outboundFuture = channel.outbound.first;
      await client.connect();
      expect(client.isConnected, isTrue);
      await client.subscribeAssets(<String>['t1', 't2']);
      final raw = await outboundFuture;
      final body = jsonDecode(raw as String) as Map<String, dynamic>;
      expect(body['type'], 'market');
      expect(body['assets_ids'], <String>['t1', 't2']);
    });

    test('subscribeAssets before connect throws StateError', () async {
      expect(
        () => client.subscribeAssets(<String>['t1']),
        throwsA(isA<StateError>()),
      );
    });

    test('inbound book event lands on books stream', () async {
      await client.connect();
      final next = client.books.first;
      channel.push(
        jsonEncode(<String, dynamic>{
          'event_type': 'book',
          'asset_id': 'a1',
          'market': 'm1',
          'timestamp': 'ts',
          'hash': 'h1',
          'bids': <Map<String, dynamic>>[
            <String, dynamic>{'price': '0.5', 'size': '10'},
          ],
          'asks': <Map<String, dynamic>>[
            <String, dynamic>{'price': '0.6', 'size': '5'},
          ],
        }),
      );
      final book = await next;
      expect(book.assetId, 'a1');
      expect(book.bids, hasLength(1));
      expect(book.bids.first.price, '0.5');
      expect(book.asks.first.size, '5');
    });

    test('inbound price_change event lands on priceChanges stream', () async {
      await client.connect();
      final next = client.priceChanges.first;
      channel.push(
        jsonEncode(<String, dynamic>{
          'event_type': 'price_change',
          'market': 'm2',
          'timestamp': 'ts',
          'price_changes': <Map<String, dynamic>>[
            <String, dynamic>{
              'asset_id': 'a2',
              'price': '0.5',
              'side': 'BUY',
              'size': '100',
              'hash': 'pc1',
            },
          ],
        }),
      );
      final pc = await next;
      expect(pc.market, 'm2');
      expect(pc.changes, hasLength(1));
      expect(pc.changes.first.side, 'BUY');
    });

    test('inbound last_trade_price event lands on lastTrades stream',
        () async {
      await client.connect();
      final next = client.lastTrades.first;
      channel.push(
        jsonEncode(<String, dynamic>{
          'event_type': 'last_trade_price',
          'asset_id': 'a3',
          'market': 'm3',
          'price': '0.61',
          'side': 'SELL',
          'size': '7',
          'fee_rate_bps': '15',
          'timestamp': 'ts',
        }),
      );
      final lt = await next;
      expect(lt.assetId, 'a3');
      expect(lt.price, '0.61');
      expect(lt.feeRateBps, '15');
    });

    test('inbound array of mixed events fans out to typed streams',
        () async {
      await client.connect();
      final book = client.books.first;
      final pc = client.priceChanges.first;
      final lt = client.lastTrades.first;
      channel.push(
        jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'event_type': 'book',
            'asset_id': 'A',
            'market': 'M',
            'timestamp': 'T',
            'hash': 'BH',
            'bids': <Map<String, dynamic>>[],
            'asks': <Map<String, dynamic>>[],
          },
          <String, dynamic>{
            'event_type': 'price_change',
            'market': 'M',
            'timestamp': 'T',
            'price_changes': <Map<String, dynamic>>[],
          },
          <String, dynamic>{
            'event_type': 'last_trade_price',
            'asset_id': 'A',
            'market': 'M',
            'price': '0.4',
            'side': 'BUY',
            'size': '1',
            'fee_rate_bps': '0',
            'timestamp': 'T',
          },
        ]),
      );
      final results = await Future.wait<Object>(<Future<Object>>[book, pc, lt]);
      expect(results[0], isA<BookMessage>());
      expect(results[1], isA<PriceChangeMessage>());
      expect(results[2], isA<LastTradeMessage>());
    });

    test('malformed message lands on errors stream and connection survives',
        () async {
      await client.connect();
      final errFuture = client.errors.first;
      final bookFuture = client.books.first;
      channel.push('not json');
      channel.push(
        jsonEncode(<String, dynamic>{
          'event_type': 'book',
          'asset_id': 'a',
          'market': 'm',
          'timestamp': 't',
          'hash': 'h',
          'bids': <Map<String, dynamic>>[],
          'asks': <Map<String, dynamic>>[],
        }),
      );
      final err = await errFuture;
      expect(err, isA<FormatException>());
      final book = await bookFuture;
      expect(book.assetId, 'a');
      expect(client.isConnected, isTrue);
    });

    test('close shuts down all output streams', () async {
      await client.connect();
      await client.close();
      expect(await client.books.isEmpty, isTrue);
      expect(await client.priceChanges.isEmpty, isTrue);
      expect(await client.lastTrades.isEmpty, isTrue);
      expect(await client.errors.isEmpty, isTrue);
      expect(client.isConnected, isFalse);
    });
  });
}
