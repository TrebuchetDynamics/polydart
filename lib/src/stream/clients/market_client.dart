/// Public Polymarket CLOB market WebSocket client.
///
/// Mirrors `internal/stream/client.go::MarketClient`. The polygolem version
/// fans events out via callbacks; this Dart port replaces them with broadcast
/// `Stream` getters so consumers can mix in `await for`, `StreamGroup`, etc.
library;

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/reconnect_policy.dart';
import '../config/stream_config.dart';
import '../models/stream_messages.dart';
import '../shared/json_frame.dart';
import '../transport/contracts/channel_factory.dart';
import '../transport/contracts/default_channel_factory.dart';

/// Factory used to open a [WebSocketChannel] for a given URI. Tests inject a
/// fake; the default opens a platform-appropriate channel
/// (`IOWebSocketChannel` on dart:io, `HtmlWebSocketChannel` on dart:html)
/// with the configured ping interval. On the dart:html (Flutter Web) path
/// `pingInterval` is informational — the browser owns WS keepalive.
typedef WebSocketChannelFactory = StreamWebSocketChannelFactory;

/// Streams Polymarket CLOB market events for a set of asset IDs.
final class MarketClient {
  MarketClient({
    required StreamConfig config,
    WebSocketChannelFactory? channelFactory,
  }) : _config = config,
       _channelFactory =
           channelFactory ??
           defaultStreamWebSocketChannelFactory(
             pingInterval: config.pingInterval,
           );

  final StreamConfig _config;
  final WebSocketChannelFactory _channelFactory;

  final StreamController<BookMessage> _books =
      StreamController<BookMessage>.broadcast();
  final StreamController<PriceChangeMessage> _priceChanges =
      StreamController<PriceChangeMessage>.broadcast();
  final StreamController<LastTradeMessage> _lastTrades =
      StreamController<LastTradeMessage>.broadcast();
  final StreamController<TickSizeChangeMessage> _tickSizeChanges =
      StreamController<TickSizeChangeMessage>.broadcast();
  final StreamController<BestBidAskMessage> _bestBidAsks =
      StreamController<BestBidAskMessage>.broadcast();
  final StreamController<NewMarketMessage> _newMarkets =
      StreamController<NewMarketMessage>.broadcast();
  final StreamController<MarketResolvedMessage> _marketResolutions =
      StreamController<MarketResolvedMessage>.broadcast();
  final StreamController<Object> _errors = StreamController<Object>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  List<String> _subscribedAssetIds = const <String>[];
  int _reconnects = 0;
  bool _connected = false;
  bool _closed = false;

  /// Decoded order-book snapshots (`event_type: "book"`).
  Stream<BookMessage> get books => _books.stream;

  /// Decoded incremental price changes (`event_type: "price_change"`).
  Stream<PriceChangeMessage> get priceChanges => _priceChanges.stream;

  /// Decoded last-trade fills (`event_type: "last_trade_price"`).
  Stream<LastTradeMessage> get lastTrades => _lastTrades.stream;

  /// Decoded tick-size updates (`event_type: "tick_size_change"`).
  Stream<TickSizeChangeMessage> get tickSizeChanges => _tickSizeChanges.stream;

  /// Decoded top-of-book updates (`event_type: "best_bid_ask"`).
  Stream<BestBidAskMessage> get bestBidAsks => _bestBidAsks.stream;

  /// Decoded market creation events (`event_type: "new_market"`).
  Stream<NewMarketMessage> get newMarkets => _newMarkets.stream;

  /// Decoded market resolution events (`event_type: "market_resolved"`).
  Stream<MarketResolvedMessage> get marketResolutions =>
      _marketResolutions.stream;

  /// WebSocket and parse errors. Surfacing them keeps the underlying socket
  /// alive (errors are not fatal — reconnect handles transport faults).
  Stream<Object> get errors => _errors.stream;

  /// True between a successful [connect] and the next read error or [close].
  bool get isConnected => _connected;

  /// Opens the WebSocket and starts the read loop. Safe to call again after
  /// a reconnect bubbles up; the existing stream subscribers are preserved.
  Future<void> connect() async {
    _reconnects = 0;
    await _dial();
  }

  Future<void> _dial() async {
    if (_closed) {
      throw StateError('MarketClient: cannot connect after close()');
    }
    final url = Uri.parse(_config.url);
    final channel = _channelFactory(url);
    _channel = channel;
    _connected = true;
    _subscription = channel.stream.listen(
      _handleFrame,
      onError: _handleSocketError,
      onDone: _handleSocketDone,
      cancelOnError: false,
    );
  }

  /// Subscribes to order-book updates for the given CLOB asset (token) IDs.
  /// Throws [StateError] if called before [connect].
  Future<void> subscribeAssets(List<String> assetIds) async {
    final channel = _channel;
    if (channel == null || !_connected) {
      throw StateError('MarketClient: not connected');
    }
    _writeSubscribe(channel, assetIds);
    _subscribedAssetIds = List<String>.unmodifiable(assetIds);
  }

  void _resubscribe() {
    final assetIds = _subscribedAssetIds;
    if (assetIds.isEmpty) return;
    final channel = _channel;
    if (channel == null || !_connected) {
      throw StateError('MarketClient: not connected');
    }
    _writeSubscribe(channel, assetIds);
  }

  void _writeSubscribe(WebSocketChannel channel, List<String> assetIds) {
    final payload = <String, dynamic>{'type': 'market', 'assets_ids': assetIds};
    if (_config.level > 0) {
      payload['level'] = _config.level;
    }
    if (_config.customFeatureEnabled) {
      payload['custom_feature_enabled'] = true;
    }
    channel.sink.add(jsonEncode(payload));
  }

  /// Tears down the connection and shuts every output stream. Idempotent.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _connected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await channel.sink.close();
      } on Object {
        // Ignore close errors — we've already torn down state.
      }
    }
    await _books.close();
    await _priceChanges.close();
    await _lastTrades.close();
    await _tickSizeChanges.close();
    await _bestBidAsks.close();
    await _newMarkets.close();
    await _marketResolutions.close();
    await _errors.close();
  }

  void _handleFrame(dynamic frame) {
    final bytes = streamFrameBytes(frame);
    if (bytes == null) return;
    _dispatch(bytes);
  }

  void _dispatch(List<int> bytes) {
    for (final child in streamJsonObjectFrames(bytes)) {
      _dispatchSingle(child);
    }
  }

  void _dispatchSingle(List<int> bytes) {
    final payload = decodeStreamJsonObject(
      bytes,
      expectedObjectMessage: 'stream: expected JSON object',
      emitError: _emitError,
    );
    if (payload == null) return;
    final eventType = (payload['event_type'] ?? '').toString();
    try {
      switch (eventType) {
        case 'book':
          _books.add(BookMessage.fromJson(payload));
        case 'price_change':
          _priceChanges.add(PriceChangeMessage.fromJson(payload));
        case 'last_trade_price':
          _lastTrades.add(LastTradeMessage.fromJson(payload));
        case 'tick_size_change':
          _tickSizeChanges.add(TickSizeChangeMessage.fromJson(payload));
        case 'best_bid_ask':
          _bestBidAsks.add(BestBidAskMessage.fromJson(payload));
        case 'new_market':
          _newMarkets.add(NewMarketMessage.fromJson(payload));
        case 'market_resolved':
          _marketResolutions.add(MarketResolvedMessage.fromJson(payload));
        default:
          // Unknown / unsupported event — drop silently to match polygolem.
          return;
      }
    } on FormatException catch (e) {
      _emitError(e);
    }
  }

  void _emitError(Object error) {
    if (_errors.isClosed) return;
    _errors.add(error);
  }

  void _handleSocketError(Object error, StackTrace stack) {
    _emitError(error);
    _connected = false;
    _scheduleReconnect();
  }

  void _handleSocketDone() {
    _connected = false;
    if (_closed) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closed || !_config.reconnect) return;
    if (_reconnects >= _config.reconnectMax) return;
    _reconnects += 1;
    final delay = reconnectDelayForAttempt(_config, _reconnects);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      _reconnectTimer = null;
      if (_closed) return;
      try {
        await _dial();
        _resubscribe();
      } on Object catch (e) {
        _emitError(e);
        _scheduleReconnect();
      }
    });
  }
}
