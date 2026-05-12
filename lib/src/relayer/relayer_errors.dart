/// Relayer-specific error classification helpers.
///
/// Mirrors Polygolem's allowlist sentinel behavior for Builder Relayer V2
/// submit failures. The relayer can reject a WALLET batch when a target or
/// approval operator is outside its allowlist; callers should stop and inspect
/// contract constants instead of attempting a direct EOA fallback.
library;

/// Stable marker for relayer allowlist rejections.
const String relayerAllowlistBlockedCode = 'relayer: allowlist block';

const List<String> _allowlistRejectionMarkers = <String>[
  'not in the allowed list',
  'are not permitted',
  'call blocked',
];

/// Exception thrown when the relayer rejects a submit body due to its allowlist.
final class RelayerAllowlistBlockedException implements Exception {
  const RelayerAllowlistBlockedException(this.cause);

  final Object cause;

  @override
  String toString() => '$relayerAllowlistBlockedCode: $cause';
}

/// Wraps known relayer allowlist rejection messages in a typed exception.
///
/// Unknown errors are returned unchanged so callers can preserve their existing
/// error handling. `null` returns `null`.
Object? classifyRelayerAllowlistError(Object? error) {
  if (error == null || error is RelayerAllowlistBlockedException) {
    return error;
  }
  final message = error.toString().toLowerCase();
  for (final marker in _allowlistRejectionMarkers) {
    if (message.contains(marker)) {
      return RelayerAllowlistBlockedException(error);
    }
  }
  return error;
}
