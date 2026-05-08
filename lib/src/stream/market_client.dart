/// Public Polymarket CLOB market WebSocket client.
///
/// Mirrors `internal/stream/client.go::MarketClient`. The polygolem version
/// fans events out via `OnBook` / `OnPriceChange` / `OnLastTrade` callbacks;
/// this Dart port replaces them with broadcast `Stream` getters
/// ([books], [priceChanges], [lastTrades], [errors]) so consumers can mix in
/// `await for`, `StreamGroup`, etc.
library;

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'dedup.dart' show splitArray;
import 'stream_config.dart';
import 'stream_messages.dart';

/// Factory used to open a [WebSocketChannel] for a given URI. Tests inject a
/// fake; the default opens an `IOWebSocketChannel` with the configured ping
/// interval.
typedef WebSocketChannelFactory = WebSocketChannel Function(Uri url);

/// Streams Polymarket CLOB market events for a set of asset IDs.
final class MarketClient {
  MarketClient({
    required StreamConfig config,
    WebSocketChannelFactory? channelFactory,
  }) : _config = config,
       _channelFactory =
           channelFactory ??
           ((Uri url) => IOWebSocketChannel.connect(
             url,
             pingInterval: config.pingInterval,
           ));

  final StreamConfig _config;
  final WebSocketChannelFactory _channelFactory;

  final StreamController<BookMessage> _books =
      StreamController<BookMessage>.broadcast();
  final StreamController<PriceChangeMessage> _priceChanges =
      StreamController<PriceChangeMessage>.broadcast();
  final StreamController<LastTradeMessage> _lastTrades =
      StreamController<LastTradeMessage>.broadcast();
  final StreamController<Object> _errors = StreamController<Object>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  int _reconnects = 0;
  bool _connected = false;
  bool _closed = false;

  /// Decoded order-book snapshots (`event_type: "book"`).
  Stream<BookMessage> get books => _books.stream;

  /// Decoded incremental price changes (`event_type: "price_change"`).
  Stream<PriceChangeMessage> get priceChanges => _priceChanges.stream;

  /// Decoded last-trade fills (`event_type: "last_trade_price"`).
  Stream<LastTradeMessage> get lastTrades => _lastTrades.stream;

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
    final payload = <String, dynamic>{
      'type': 'market',
      'assets_ids': assetIds,
    };
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
    await _errors.close();
  }

  void _handleFrame(dynamic frame) {
    final bytes = _frameBytes(frame);
    if (bytes == null) return;
    _dispatch(bytes);
  }

  List<int>? _frameBytes(dynamic frame) {
    if (frame is String) return utf8.encode(frame);
    if (frame is List<int>) return frame;
    return null;
  }

  void _dispatch(List<int> bytes) {
    final children = splitArray(bytes);
    if (children.isNotEmpty) {
      for (final child in children) {
        _dispatchSingle(child);
      }
      return;
    }
    _dispatchSingle(bytes);
  }

  void _dispatchSingle(List<int> bytes) {
    Object? decoded;
    try {
      decoded = json.decode(utf8.decode(bytes));
    } on FormatException catch (e) {
      _emitError(e);
      return;
    }
    if (decoded is! Map) {
      _emitError(FormatException('stream: expected JSON object', decoded));
      return;
    }
    final payload = decoded.map<String, dynamic>(
      (k, v) => MapEntry(k.toString(), v),
    );
    final eventType = (payload['event_type'] ?? '').toString();
    switch (eventType) {
      case 'book':
        _books.add(BookMessage.fromJson(payload));
      case 'price_change':
        _priceChanges.add(PriceChangeMessage.fromJson(payload));
      case 'last_trade_price':
        _lastTrades.add(LastTradeMessage.fromJson(payload));
      default:
        // Unknown / unsupported event — drop silently to match polygolem.
        return;
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
    final base = _config.reconnectDelay.inMilliseconds;
    final cap = _config.reconnectMaxDelay.inMilliseconds;
    var delay = base;
    for (var i = 0; i < _reconnects; i++) {
      delay *= 2;
      if (delay > cap) {
        delay = cap;
        break;
      }
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delay), () async {
      _reconnectTimer = null;
      if (_closed) return;
      try {
        await _dial();
      } on Object catch (e) {
        _emitError(e);
        _scheduleReconnect();
      }
    });
  }
}
