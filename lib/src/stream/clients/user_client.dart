/// Authenticated Polymarket CLOB user WebSocket client.
///
/// Mirrors polygolem `pkg/stream.UserClient`. Requires CLOB L2 credentials
/// and dispatches typed user order/trade events from the `/ws/user` channel.
library;

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../auth/l2.dart' show ApiKey;
import '../config/stream_config.dart';
import '../models/stream_messages.dart';
import '../shared/json_frame.dart';
import '../transport/contracts/channel_factory.dart';
import '../transport/socket_dispatch.dart' as platform;

const String defaultUserStreamUrl =
    'wss://ws-subscriptions-clob.polymarket.com/ws/user';

/// Factory used to open a [WebSocketChannel] for a given URI.
typedef UserWebSocketChannelFactory = StreamWebSocketChannelFactory;

final class UserClient {
  UserClient({
    required StreamConfig config,
    required ApiKey credentials,
    UserWebSocketChannelFactory? channelFactory,
  }) : _config = config,
       _credentials = credentials,
       _channelFactory =
           channelFactory ??
           ((Uri url) => platform.defaultOpenChannel(url, config.pingInterval));

  UserClient.defaults({
    required ApiKey credentials,
    UserWebSocketChannelFactory? channelFactory,
  }) : this(
         config: const StreamConfig(url: defaultUserStreamUrl),
         credentials: credentials,
         channelFactory: channelFactory,
       );

  final StreamConfig _config;
  final ApiKey _credentials;
  final UserWebSocketChannelFactory _channelFactory;

  final StreamController<UserOrderMessage> _orders =
      StreamController<UserOrderMessage>.broadcast();
  final StreamController<UserTradeMessage> _trades =
      StreamController<UserTradeMessage>.broadcast();
  final StreamController<Object> _errors = StreamController<Object>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _connected = false;
  bool _closed = false;

  Stream<UserOrderMessage> get orders => _orders.stream;
  Stream<UserTradeMessage> get trades => _trades.stream;
  Stream<Object> get errors => _errors.stream;
  bool get isConnected => _connected;

  Future<void> connect() async {
    _credentials.validate();
    if (_closed) {
      throw StateError('UserClient: cannot connect after close()');
    }
    final channel = _channelFactory(Uri.parse(_config.url));
    _channel = channel;
    _connected = true;
    _subscription = channel.stream.listen(
      _handleFrame,
      onError: _handleSocketError,
      onDone: _handleSocketDone,
      cancelOnError: false,
    );
  }

  /// Authenticates the user channel and optionally filters by market condition
  /// IDs when upstream supports market scoping.
  Future<void> subscribeUser({List<String> markets = const <String>[]}) async {
    final channel = _channel;
    if (channel == null || !_connected) {
      throw StateError('UserClient: not connected');
    }
    _credentials.validate();
    channel.sink.add(
      jsonEncode(<String, dynamic>{
        'type': 'user',
        'markets': markets,
        'auth': <String, String>{
          'apiKey': _credentials.key,
          'secret': _credentials.secret,
          'passphrase': _credentials.passphrase,
        },
      }),
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _connected = false;
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await channel.sink.close();
      } on Object {
        // Ignore close errors — state is already torn down.
      }
    }
    await _orders.close();
    await _trades.close();
    await _errors.close();
  }

  void _handleFrame(dynamic frame) {
    final bytes = streamFrameBytes(frame);
    if (bytes == null) return;
    final payload = decodeStreamJsonObject(
      bytes,
      expectedObjectMessage: 'user stream: expected JSON object',
      emitError: _emitError,
    );
    if (payload == null) return;
    final eventType = (payload['event_type'] ?? payload['type'] ?? '')
        .toString();
    switch (eventType) {
      case 'order':
        _orders.add(UserOrderMessage.fromJson(payload));
      case 'trade':
        _trades.add(UserTradeMessage.fromJson(payload));
      default:
        return;
    }
  }

  void _handleSocketError(Object error, StackTrace stack) {
    _emitError(error);
    _connected = false;
  }

  void _handleSocketDone() {
    _connected = false;
  }

  void _emitError(Object error) {
    if (_errors.isClosed) return;
    _errors.add(error);
  }
}
