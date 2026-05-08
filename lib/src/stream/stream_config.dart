/// Polymarket CLOB market WebSocket connection configuration.
///
/// Mirrors `internal/stream/client.go::Config`. Defaults match polygolem's
/// `DefaultConfig`: 10 s ping, 30 s pong timeout, 5 reconnect attempts with
/// exponential backoff capped at 30 s.
library;

import 'package:meta/meta.dart';

/// Default public Polymarket CLOB market WebSocket URL.
const String defaultStreamUrl =
    'wss://ws-subscriptions-clob.polymarket.com/ws/';

/// Connection settings for [MarketClient].
@immutable
final class StreamConfig {
  const StreamConfig({
    required this.url,
    this.pingInterval = const Duration(seconds: 10),
    this.pongTimeout = const Duration(seconds: 30),
    this.reconnect = true,
    this.reconnectDelay = const Duration(seconds: 2),
    this.reconnectMaxDelay = const Duration(seconds: 30),
    this.reconnectMax = 5,
  });

  /// Builds a [StreamConfig] with polygolem's defaults. [url] overrides the
  /// canonical [defaultStreamUrl] for staging or fakes.
  factory StreamConfig.defaults({String? url}) =>
      StreamConfig(url: url ?? defaultStreamUrl);

  /// WebSocket URL (e.g. `wss://ws-subscriptions-clob.polymarket.com/ws/`).
  final String url;

  /// Interval between client pings. Forwarded to `IOWebSocketChannel`'s
  /// `pingInterval`, which both sends pings and enforces the pong timeout.
  final Duration pingInterval;

  /// Maximum time to wait for a pong before treating the connection as dead.
  /// Currently informational — the underlying socket's ping interval doubles
  /// as the pong deadline.
  final Duration pongTimeout;

  /// Whether to attempt reconnection on read errors.
  final bool reconnect;

  /// Initial backoff applied before doubling.
  final Duration reconnectDelay;

  /// Upper bound on the backoff between reconnect attempts.
  final Duration reconnectMaxDelay;

  /// Hard ceiling on consecutive reconnect attempts.
  final int reconnectMax;
}
