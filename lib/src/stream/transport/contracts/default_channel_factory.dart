/// Default WebSocket channel factory adapter for stream clients.
///
/// Separates the public factory shape used by clients/tests from the
/// platform-conditional socket opener.
library;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../socket_dispatch.dart';
import 'channel_factory.dart';

typedef StreamOpenChannel =
    WebSocketChannel Function(Uri url, Duration pingInterval);

StreamWebSocketChannelFactory defaultStreamWebSocketChannelFactory({
  required Duration pingInterval,
  StreamOpenChannel openChannel = defaultOpenChannel,
}) {
  return (Uri url) => openChannel(url, pingInterval);
}
