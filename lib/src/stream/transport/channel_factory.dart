/// Shared WebSocket channel factory contract for stream clients.
///
/// Tests inject fakes through this contract; production defaults delegate to
/// the platform-specific opener in `socket_dispatch.dart`.
library;

import 'package:web_socket_channel/web_socket_channel.dart';

/// Factory used to open a [WebSocketChannel] for a given URI.
typedef StreamWebSocketChannelFactory = WebSocketChannel Function(Uri url);
