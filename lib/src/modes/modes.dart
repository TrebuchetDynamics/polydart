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
