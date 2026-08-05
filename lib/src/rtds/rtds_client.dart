/// Polymarket Real-Time Data Service crypto-price stream.
library;

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../stream/config/reconnect_policy.dart';
import '../stream/config/stream_config.dart';
import '../stream/shared/json_frame.dart';
import '../stream/shared/socket_lifecycle.dart';
import '../stream/transport/contracts/channel_factory.dart';
import '../stream/transport/contracts/default_channel_factory.dart';

const String defaultRtdsUrl = 'wss://ws-live-data.polymarket.com';
const String rtdsCryptoPricesTopic = 'crypto_prices';
const String rtdsCryptoPricesChainlinkTopic = 'crypto_prices_chainlink';

@immutable
final class RtdsCryptoPrice {
  const RtdsCryptoPrice({
    required this.topic,
    required this.symbol,
    required this.timestamp,
    required this.price,
  });

  final String topic;
  final String symbol;
  final int timestamp;
  final String price;
}

final class RtdsClient {
  RtdsClient({
    StreamConfig? config,
    StreamWebSocketChannelFactory? channelFactory,
  }) : _config =
           config ??
           const StreamConfig(
             url: defaultRtdsUrl,
             pingInterval: Duration(seconds: 5),
           ),
       _channelFactory =
           channelFactory ??
           defaultStreamWebSocketChannelFactory(
             pingInterval: config?.pingInterval ?? const Duration(seconds: 5),
           );

  final StreamConfig _config;
  final StreamWebSocketChannelFactory _channelFactory;
  final StreamController<RtdsCryptoPrice> _prices =
      StreamController<RtdsCryptoPrice>.broadcast();
  final StreamController<Object> _errors = StreamController<Object>.broadcast();
  final Map<String, _RtdsSubscription> _subscriptions =
      <String, _RtdsSubscription>{};

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Future<void>? _connecting;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnects = 0;
  bool _connected = false;
  bool _closed = false;

  Stream<Object> get errors => _errors.stream;
  bool get isConnected => _connected;

  Stream<RtdsCryptoPrice> subscribeCryptoPrices({
    required String topic,
    required List<String> symbols,
  }) {
    if (topic != rtdsCryptoPricesTopic &&
        topic != rtdsCryptoPricesChainlinkTopic) {
      throw ArgumentError.value(
        topic,
        'topic',
        'unsupported RTDS crypto topic',
      );
    }
    if (_closed) throw StateError('RtdsClient: cannot subscribe after close()');

    final normalizedSymbols = symbols
        .map((symbol) => symbol.trim().toLowerCase())
        .where((symbol) => symbol.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final subscription = _RtdsSubscription(topic, normalizedSymbols);
    final isNew = !_subscriptions.containsKey(subscription.key);
    _subscriptions[subscription.key] = subscription;
    if (_connected) {
      if (isNew) _writeSubscription(subscription);
    } else {
      _ensureConnected();
    }
    final accepted = normalizedSymbols.toSet();
    return _prices.stream.where(
      (event) =>
          event.topic == topic &&
          (accepted.isEmpty || accepted.contains(event.symbol)),
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _connected = false;
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final subscription = _socketSubscription;
    final channel = _channel;
    _socketSubscription = null;
    _channel = null;
    await detachStreamSocket(subscription: subscription, channel: channel);
    await _prices.close();
    await _errors.close();
  }

  void _ensureConnected() {
    if (_closed || _connected || _connecting != null) return;
    Future<void> connect() async {
      Object? failure;
      try {
        await _dial();
      } on Object catch (error) {
        failure = error;
        _emitError(error);
      } finally {
        _connecting = null;
      }
      if (failure != null) _scheduleReconnect();
    }

    _connecting = connect();
    unawaited(_connecting!);
  }

  Future<void> _dial() async {
    await detachStreamSocket(
      subscription: _socketSubscription,
      channel: _channel,
    );
    if (_closed) return;
    _socketSubscription = null;
    _channel = null;
    _connected = false;
    _pingTimer?.cancel();

    final channel = _channelFactory(Uri.parse(_config.url));
    _channel = channel;
    _connected = true;
    _socketSubscription = channel.stream.listen(
      _handleFrame,
      onError: _handleSocketError,
      onDone: _handleSocketDone,
      cancelOnError: false,
    );
    for (final subscription in _subscriptions.values) {
      _writeSubscription(subscription);
    }
    _pingTimer = Timer.periodic(_config.pingInterval, (_) {
      if (_connected && !_closed) channel.sink.add('PING');
    });
  }

  void _writeSubscription(_RtdsSubscription subscription) {
    final channel = _channel;
    if (channel == null || !_connected) return;
    final rows = subscription.topic == rtdsCryptoPricesTopic
        ? <Map<String, dynamic>>[
            <String, dynamic>{
              'topic': subscription.topic,
              'type': 'update',
              if (subscription.symbols.isNotEmpty)
                'filters': subscription.symbols.join(','),
            },
          ]
        : subscription.symbols.isEmpty
        ? <Map<String, dynamic>>[
            <String, dynamic>{
              'topic': subscription.topic,
              'type': '*',
              'filters': '',
            },
          ]
        : subscription.symbols
              .map(
                (symbol) => <String, dynamic>{
                  'topic': subscription.topic,
                  'type': '*',
                  'filters': jsonEncode(<String, String>{'symbol': symbol}),
                },
              )
              .toList(growable: false);
    channel.sink.add(
      jsonEncode(<String, dynamic>{
        'action': 'subscribe',
        'subscriptions': rows,
      }),
    );
  }

  void _handleFrame(dynamic frame) {
    final bytes = streamFrameBytes(frame);
    if (bytes == null) return;
    final root = decodeStreamJsonObject(
      bytes,
      expectedObjectMessage: 'rtds: expected JSON object',
      emitError: _emitError,
    );
    if (root == null) return;
    final topic = root['topic']?.toString() ?? '';
    final rawPayload = root['payload'];
    if (rawPayload is! Map) return;
    final payload = rawPayload.cast<String, dynamic>();
    final symbol = payload['symbol']?.toString() ?? '';
    final history = payload['data'];
    if (history is List) {
      for (final item in history.whereType<Map<dynamic, dynamic>>()) {
        _emitPrice(topic, item.cast<String, dynamic>(), fallbackSymbol: symbol);
      }
      return;
    }
    _emitPrice(topic, payload, fallbackSymbol: symbol);
  }

  void _emitPrice(
    String topic,
    Map<String, dynamic> payload, {
    required String fallbackSymbol,
  }) {
    final symbol = (payload['symbol']?.toString() ?? fallbackSymbol)
        .trim()
        .toLowerCase();
    final timestamp = _int(payload['timestamp']);
    final price = payload['value']?.toString() ?? '';
    final numericPrice = double.tryParse(price);
    if (symbol.isEmpty ||
        timestamp <= 0 ||
        numericPrice == null ||
        numericPrice <= 0) {
      return;
    }
    _prices.add(
      RtdsCryptoPrice(
        topic: topic,
        symbol: symbol,
        timestamp: timestamp,
        price: price,
      ),
    );
  }

  void _handleSocketError(Object error, StackTrace stackTrace) {
    _emitError(error);
    _connected = false;
    _pingTimer?.cancel();
    _pingTimer = null;
    _scheduleReconnect();
  }

  void _handleSocketDone() {
    _connected = false;
    _pingTimer?.cancel();
    _pingTimer = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closed || !_config.reconnect || _reconnectTimer != null) return;
    if (_reconnects >= _config.reconnectMax) return;
    _reconnects += 1;
    final delay = reconnectDelayForAttempt(_config, _reconnects);
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      _ensureConnected();
    });
  }

  void _emitError(Object error) {
    if (!_errors.isClosed) _errors.add(error);
  }
}

final class _RtdsSubscription {
  const _RtdsSubscription(this.topic, this.symbols);

  final String topic;
  final List<String> symbols;

  String get key => '$topic:${symbols.join(',')}';
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
