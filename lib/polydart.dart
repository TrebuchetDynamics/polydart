/// Polydart — Dart-native Polymarket SDK.
///
/// Peer implementation to polygolem (Go). See `docs/PRD.md` and
/// `docs/PLAN.md`.
library;

export 'src/config/config.dart';
export 'src/errors/errors.dart';
export 'src/gamma/gamma_client.dart' show GammaClient;
export 'src/gamma/gamma_params.dart' show GetMarketsParams, SearchParams;
export 'src/logging/logger.dart';
export 'src/modes/modes.dart';
export 'src/transport/circuit_breaker.dart'
    show CircuitBreaker, CircuitBreakerConfig, CircuitState;
export 'src/transport/http_transport.dart' show HttpTransport;
export 'src/transport/rate_limit.dart' show RateLimiter;
export 'src/transport/redact.dart';
export 'src/transport/transport_config.dart' show TransportConfig;
export 'src/types/types.dart';

import 'src/gamma/gamma_client.dart';
import 'src/transport/http_transport.dart';
import 'src/transport/transport_config.dart';

const String polydartVersion = '0.1.0-alpha.1';

/// Top-level read-only polydart client.
///
/// Phase 1 surfaces the Gamma client only. CLOB read endpoints, then write
/// flows (paper, live), arrive in subsequent phases per `docs/PLAN.md`.
final class Polydart {
  Polydart._(this.gamma);

  /// A read-only client. No wallet, no auth, no live writes.
  factory Polydart.readOnly({TransportConfig? gammaTransport}) {
    final transport = gammaTransport == null
        ? null
        : HttpTransport(config: gammaTransport);
    return Polydart._(GammaClient(transport: transport));
  }

  /// Gamma API surface (search, markets, …).
  final GammaClient gamma;

  /// Closes underlying transports. Idempotent.
  void close() => gamma.close();
}
