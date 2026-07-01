/// SDK configuration.
///
/// Mirrors `internal/config`. Bindable from a `Map<String, String>`
/// environment so consumers can wire `Platform.environment` (CLI/server),
/// `dart-define` values (Flutter web), or hand-rolled maps (tests).
library;

import 'package:meta/meta.dart';

import '../errors/errors.dart';
import '../modes/modes.dart';

@immutable
final class PolydartConfig {
  const PolydartConfig({
    this.mode = PolydartMode.readOnly,
    this.gammaBaseUrl = defaultGammaBaseUrl,
    this.clobBaseUrl = defaultClobBaseUrl,
    this.dataBaseUrl = defaultDataBaseUrl,
    this.webBaseUrl = defaultWebBaseUrl,
    this.requestTimeout = const Duration(seconds: 10),
    this.liveTradingEnabled = false,
    this.paperStatePath = '',
  });

  /// Public Polymarket Gamma API base.
  static const String defaultGammaBaseUrl = 'https://gamma-api.polymarket.com';

  /// Public Polymarket CLOB API base.
  static const String defaultClobBaseUrl = 'https://clob.polymarket.com';

  /// Public Polymarket Data API base.
  static const String defaultDataBaseUrl = 'https://data-api.polymarket.com';

  /// Public Polymarket web app base.
  static const String defaultWebBaseUrl = 'https://polymarket.com';

  /// Reads config from an environment map. Keys are looked up as
  /// `${prefix}_${UPPER_SNAKE}` (e.g. `POLYMARKET_MODE`).
  factory PolydartConfig.fromEnv(
    Map<String, String> env, {
    String prefix = 'POLYMARKET',
  }) {
    String? get(String key) {
      final v = env['${prefix}_${key.toUpperCase()}'];
      if (v == null) return null;
      final trimmed = v.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final modeRaw = get('MODE') ?? PolydartMode.readOnly.label;
    final mode = PolydartMode.parse(modeRaw);

    final timeoutRaw = get('REQUEST_TIMEOUT') ?? '10s';
    final timeout = parseDuration(timeoutRaw);
    if (timeout == null || timeout <= Duration.zero) {
      throw ValidationException(
        code: ErrorCode.invalidValue,
        message: 'request_timeout must be a positive duration; got $timeoutRaw',
        field: '${prefix}_REQUEST_TIMEOUT',
      );
    }

    return PolydartConfig(
      mode: mode,
      gammaBaseUrl: get('GAMMA_BASE_URL') ?? defaultGammaBaseUrl,
      clobBaseUrl: get('CLOB_BASE_URL') ?? defaultClobBaseUrl,
      dataBaseUrl: get('DATA_BASE_URL') ?? defaultDataBaseUrl,
      webBaseUrl: get('WEB_BASE_URL') ?? defaultWebBaseUrl,
      requestTimeout: timeout,
      liveTradingEnabled:
          (get('LIVE_TRADING_ENABLED') ?? 'false').toLowerCase() == 'true',
      paperStatePath: get('PAPER_STATE_PATH') ?? '',
    );
  }

  final PolydartMode mode;
  final String gammaBaseUrl;
  final String clobBaseUrl;
  final String dataBaseUrl;
  final String webBaseUrl;
  final Duration requestTimeout;
  final bool liveTradingEnabled;
  final String paperStatePath;

  PolydartConfig copyWith({
    PolydartMode? mode,
    String? gammaBaseUrl,
    String? clobBaseUrl,
    String? dataBaseUrl,
    String? webBaseUrl,
    Duration? requestTimeout,
    bool? liveTradingEnabled,
    String? paperStatePath,
  }) {
    return PolydartConfig(
      mode: mode ?? this.mode,
      gammaBaseUrl: gammaBaseUrl ?? this.gammaBaseUrl,
      clobBaseUrl: clobBaseUrl ?? this.clobBaseUrl,
      dataBaseUrl: dataBaseUrl ?? this.dataBaseUrl,
      webBaseUrl: webBaseUrl ?? this.webBaseUrl,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      liveTradingEnabled: liveTradingEnabled ?? this.liveTradingEnabled,
      paperStatePath: paperStatePath ?? this.paperStatePath,
    );
  }

  @override
  String toString() =>
      'PolydartConfig('
      'mode=${mode.label}, '
      'gamma=$gammaBaseUrl, '
      'clob=$clobBaseUrl, '
      'data=$dataBaseUrl, '
      'web=$webBaseUrl, '
      'timeout=$requestTimeout, '
      'live=$liveTradingEnabled, '
      'paperPath=${paperStatePath.isEmpty ? "<empty>" : "<set>"})';
}

/// Parses a Go-style duration string (`10s`, `500ms`, `2m`, `1h`).
///
/// Returns null on garbage. Mirrors the subset of `time.ParseDuration` we
/// actually need.
Duration? parseDuration(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  final match = _durationRegex.firstMatch(s);
  if (match == null) return null;
  final value = int.tryParse(match.group(1)!);
  if (value == null) return null;
  switch (match.group(2)) {
    case 'ms':
      return Duration(milliseconds: value);
    case 's':
      return Duration(seconds: value);
    case 'm':
      return Duration(minutes: value);
    case 'h':
      return Duration(hours: value);
  }
  return null;
}

final RegExp _durationRegex = RegExp(r'^(\d+)(ms|s|m|h)$');
