/// Transport configuration.
library;

import 'package:meta/meta.dart';

const bool _sendUserAgentHeaderByDefault = !bool.fromEnvironment(
  'dart.library.js_interop',
);

@immutable
final class TransportConfig {
  const TransportConfig({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 30),
    this.userAgent = 'polydart/0.1',
    this.sendUserAgentHeader = _sendUserAgentHeaderByDefault,
    this.retryMax = 3,
    this.retryDelay = const Duration(milliseconds: 100),
  });

  /// Base URL for all requests. Trailing slashes are stripped at use site.
  final String baseUrl;

  /// Per-attempt timeout.
  final Duration timeout;

  /// User-Agent header value.
  final String userAgent;

  /// Whether to send [userAgent] as an HTTP `User-Agent` header.
  ///
  /// Defaults to false for browser builds so public APIs with restrictive
  /// CORS preflight headers, including Polymarket Gamma, remain reachable
  /// from Flutter Web.
  final bool sendUserAgentHeader;

  /// Maximum retries for idempotent (GET) requests.
  ///
  /// `retryMax = 0` means a single attempt with no retries.
  final int retryMax;

  /// Base delay for exponential backoff. Attempt N waits
  /// `retryDelay << (N - 1)`.
  final Duration retryDelay;

  String get normalisedBaseUrl => baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
}
