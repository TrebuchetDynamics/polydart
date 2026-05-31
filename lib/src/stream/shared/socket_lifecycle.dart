/// Shared WebSocket lifecycle helpers for stream clients.
///
/// Keeps reconnect/manual-redial cleanup consistent across market and user
/// stream clients so stale sockets cannot keep dispatching into active output
/// streams after a replacement connection is opened.
library;

import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Cancels the read loop and closes the socket sink for a client-owned channel.
///
/// Close errors are intentionally ignored: callers are already replacing or
/// tearing down local state, and transport close failures are not actionable.
Future<void> detachStreamSocket({
  StreamSubscription<dynamic>? subscription,
  WebSocketChannel? channel,
}) async {
  await subscription?.cancel();
  if (channel == null) return;
  try {
    await channel.sink.close();
  } on Object {
    // Ignore close errors — caller state is already detached.
  }
}
