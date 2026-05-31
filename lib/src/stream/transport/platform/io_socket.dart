/// dart:io implementation of [defaultOpenChannel].
///
/// Used on Flutter mobile / desktop / Dart server. Uses
/// [IOWebSocketChannel] which sends WebSocket-protocol pings at
/// [pingInterval]; the OS-level socket keepalive supplements that.
library;

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel defaultOpenChannel(Uri url, Duration pingInterval) {
  return IOWebSocketChannel.connect(url, pingInterval: pingInterval);
}
