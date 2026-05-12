/// Operating-mode enum and gate helpers.
///
/// Mirrors `internal/modes`. `Polydart.readOnly`, `.paper`, and `.live`
/// factories project a [PolydartMode] onto the SDK; gate functions reject
/// auth-only calls in modes that lack credentials.
library;

import '../errors/errors.dart';

enum PolydartMode {
  readOnly('read-only'),
  paper('paper'),
  live('live');

  const PolydartMode(this.label);
  final String label;

  static PolydartMode parse(String raw) {
    final s = raw.trim().toLowerCase();
    switch (s) {
      case '':
      case 'read-only':
      case 'readonly':
      case 'read_only':
      case 'ro':
        return readOnly;
      case 'paper':
        return paper;
      case 'live':
        return live;
    }
    throw ValidationException(
      code: ErrorCode.invalidValue,
      message: 'invalid mode: $raw',
      field: 'mode',
    );
  }
}

/// One failed live-mode gate.
final class LiveGateFailure {
  const LiveGateFailure({required this.code, required this.message});

  final String code;
  final String message;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    'message': message,
  };
}

/// Inputs that must all be true before a consumer can enter live mode.
final class LiveGateInput {
  const LiveGateInput({
    required this.envEnabled,
    required this.configEnabled,
    required this.confirmLive,
    required this.preflightOk,
  });

  final bool envEnabled;
  final bool configEnabled;
  final bool confirmLive;
  final bool preflightOk;
}

/// Result of evaluating live-mode gates.
final class LiveGateResult {
  const LiveGateResult({required this.allowed, required this.failures});

  final bool allowed;
  final List<LiveGateFailure> failures;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'allowed': allowed,
    'failures': failures.map((f) => f.toJson()).toList(growable: false),
  };
}

/// Mirrors Polygolem's four live gates: environment, config, confirmation,
/// and preflight. The public SDK does not infer these from process state.
LiveGateResult validateLiveGates(LiveGateInput input) {
  final failures = <LiveGateFailure>[];
  if (!input.envEnabled) {
    failures.add(
      const LiveGateFailure(
        code: 'env_gate_required',
        message: 'POLYMARKET_LIVE_PROFILE must be on',
      ),
    );
  }
  if (!input.configEnabled) {
    failures.add(
      const LiveGateFailure(
        code: 'config_gate_required',
        message: 'live_trading_enabled must be true',
      ),
    );
  }
  if (!input.confirmLive) {
    failures.add(
      const LiveGateFailure(
        code: 'cli_confirmation_required',
        message: '--confirm-live is required',
      ),
    );
  }
  if (!input.preflightOk) {
    failures.add(
      const LiveGateFailure(
        code: 'preflight_required',
        message: 'preflight must pass',
      ),
    );
  }
  return LiveGateResult(
    allowed: failures.isEmpty,
    failures: List<LiveGateFailure>.unmodifiable(failures),
  );
}

/// Throws [SafetyException] if the current [mode] does not allow live writes.
///
/// Use this at every entry point that signs or submits an order. Live mode
/// also requires `liveTradingEnabled=true` in `PolydartConfig` so callers
/// can keep a hard kill switch in environment.
void requireLive(PolydartMode mode, {required bool liveTradingEnabled}) {
  if (mode != PolydartMode.live) {
    throw SafetyException(
      code: ErrorCode.liveDisabled,
      message:
          'live writes blocked: mode is ${mode.label}, expected ${PolydartMode.live.label}',
    );
  }
  if (!liveTradingEnabled) {
    throw const SafetyException(
      code: ErrorCode.liveDisabled,
      message: 'live writes blocked: liveTradingEnabled flag is off',
    );
  }
}

/// Throws [SafetyException] if the mode does not allow simulated submission.
void requirePaperOrLive(PolydartMode mode) {
  if (mode == PolydartMode.readOnly) {
    throw const SafetyException(
      code: ErrorCode.liveDisabled,
      message: 'order submission blocked: mode is read-only',
    );
  }
}
