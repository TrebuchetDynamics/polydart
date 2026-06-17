/// Relayer-specific error classification helpers.
///
/// Mirrors Polygolem's allowlist sentinel behavior for Builder Relayer V2
/// submit failures. The relayer can reject a WALLET batch when a target or
/// approval operator is outside its allowlist; callers should stop and inspect
/// contract constants instead of attempting a direct EOA fallback.
library;

import 'dart:convert';

import '../errors/errors.dart';
import 'relayer_types.dart';

/// Stable marker for relayer allowlist rejections.
const String relayerAllowlistBlockedCode = 'relayer: allowlist block';

const List<String> _allowlistRejectionMarkers = <String>[
  'not in the allowed list',
  'are not permitted',
  'call blocked',
];

/// Exception thrown when the relayer returns a structured error body.
final class RelayerApiException implements Exception {
  const RelayerApiException({required this.error, required this.cause});

  final RelayerError error;
  final Object cause;

  @override
  String toString() {
    final code = error.code == null ? '' : ' code=${error.code}';
    return 'relayer: ${error.error}$code: $cause';
  }
}

/// Exception thrown when the relayer rejects a submit body due to its allowlist.
final class RelayerAllowlistBlockedException implements Exception {
  const RelayerAllowlistBlockedException(this.cause);

  final Object cause;

  @override
  String toString() => '$relayerAllowlistBlockedCode: $cause';
}

/// Wraps known relayer API errors in typed exceptions.
///
/// Allowlist rejections are classified first because callers need a stable
/// safety signal for blocked approval/operator submissions. Other structured
/// `{error, code}` bodies become [RelayerApiException]. Unknown errors are
/// returned unchanged so callers can preserve existing error handling.
Object? classifyRelayerError(Object? error) {
  final allowlist = classifyRelayerAllowlistError(error);
  if (allowlist == null || !identical(allowlist, error)) return allowlist;
  if (error is TransportException && error.responseBody != null) {
    try {
      final decoded = jsonDecode(error.responseBody!);
      if (decoded is Map && decoded.containsKey('error')) {
        return RelayerApiException(
          error: RelayerError.fromJson(decoded.cast<String, dynamic>()),
          cause: error,
        );
      }
    } on FormatException {
      return error;
    }
  }
  return error;
}

/// Wraps known relayer allowlist rejection messages in a typed exception.
///
/// Unknown errors are returned unchanged so callers can preserve their existing
/// error handling. `null` returns `null`.
Object? classifyRelayerAllowlistError(Object? error) {
  if (error == null || error is RelayerAllowlistBlockedException) {
    return error;
  }
  final body = error is TransportException && error.responseBody != null
      ? error.responseBody!
      : error.toString();
  final message = body.toLowerCase();
  for (final marker in _allowlistRejectionMarkers) {
    if (message.contains(marker)) {
      return RelayerAllowlistBlockedException(error);
    }
  }
  return error;
}
