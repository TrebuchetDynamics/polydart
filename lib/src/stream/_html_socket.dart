/// dart:html implementation of [defaultOpenChannel].
///
/// Used on Flutter Web. The browser's WebSocket implementation owns
/// keepalive — there is no application-level pingInterval hook on
/// [HtmlWebSocketChannel]. The argument is accepted for source-level
/// signature parity with the dart:io path and is otherwise ignored.
library;

import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel defaultOpenChannel(Uri url, Duration pingInterval) {
  // pingInterval intentionally unused — see library comment.
  return HtmlWebSocketChannel.connect(url);
}
