/// Polydart error model.
///
/// Mirrors polygolem `internal/errors`. Every recoverable failure surface
/// in the SDK throws a [PolydartException] subclass with a stable [ErrorCode]
/// so consumers can branch on it.
library;

import 'dart:convert';

import 'package:meta/meta.dart';

/// Stable machine-readable error codes. Mirrors `internal/errors.Code`.
@immutable
final class ErrorCode {
  const ErrorCode(this.value);
  final String value;

  // Transport.
  static const ErrorCode timeout = ErrorCode('NET-001');
  static const ErrorCode connectionFailed = ErrorCode('NET-002');
  static const ErrorCode rateLimited = ErrorCode('NET-003');
  static const ErrorCode circuitOpen = ErrorCode('NET-004');

  // Auth.
  static const ErrorCode missingSigner = ErrorCode('AUTH-001');
  static const ErrorCode missingCreds = ErrorCode('AUTH-002');
  static const ErrorCode invalidSignature = ErrorCode('AUTH-003');
  static const ErrorCode unauthorized = ErrorCode('AUTH-004');

  // CLOB.
  static const ErrorCode orderNotFound = ErrorCode('CLOB-001');
  static const ErrorCode insufficientFunds = ErrorCode('CLOB-002');
  static const ErrorCode invalidOrder = ErrorCode('CLOB-003');
  static const ErrorCode invalidTokenId = ErrorCode('CLOB-004');

  // Validation.
  static const ErrorCode missingField = ErrorCode('VAL-001');
  static const ErrorCode invalidValue = ErrorCode('VAL-002');
  static const ErrorCode batchSizeExceed = ErrorCode('VAL-003');

  // Safety.
  static const ErrorCode liveDisabled = ErrorCode('SAFETY-001');
  static const ErrorCode preflightFailed = ErrorCode('SAFETY-002');
  static const ErrorCode notAuthorized = ErrorCode('SAFETY-003');

  // Gamma.
  static const ErrorCode marketNotFound = ErrorCode('GAMMA-001');
  static const ErrorCode eventNotFound = ErrorCode('GAMMA-002');

  @override
  bool operator ==(Object other) => other is ErrorCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Sealed root for every exception raised by polydart.
@immutable
sealed class PolydartException implements Exception {
  const PolydartException({
    required this.code,
    required this.message,
    this.httpStatus,
    this.cause,
  });

  final ErrorCode code;
  final String message;
  final int? httpStatus;
  final Object? cause;

  @override
  String toString() {
    final base = '[${code.value}] $message';
    if (cause != null) return '$base: $cause';
    return base;
  }
}

final class TransportException extends PolydartException {
  const TransportException({
    required super.code,
    required super.message,
    super.httpStatus,
    super.cause,
    this.responseBody,
  });

  final String? responseBody;
}

@immutable
final class ClobErrorResponse {
  const ClobErrorResponse({
    required this.message,
    required this.rawBody,
    this.httpStatus,
    this.code,
    this.type,
    this.details = const <String, dynamic>{},
  });

  factory ClobErrorResponse.fromBody(String body, {int? httpStatus}) {
    final raw = body.trim();
    if (raw.isEmpty) {
      return ClobErrorResponse(
        message: httpStatus == null
            ? 'CLOB request failed'
            : 'CLOB HTTP $httpStatus',
        rawBody: body,
        httpStatus: httpStatus,
      );
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final details = decoded.map<String, dynamic>(
          (key, value) => MapEntry(key.toString(), value),
        );
        final message =
            _firstString(
              details['message'],
              details['error'],
              details['errorMsg'],
              details['error_msg'],
              details['detail'],
              details['reason'],
            ) ??
            raw;
        return ClobErrorResponse(
          message: message,
          rawBody: body,
          httpStatus: httpStatus,
          code: _firstString(
            details['code'],
            details['errorCode'],
            details['error_code'],
          ),
          type: _firstString(
            details['type'],
            details['errorType'],
            details['error_type'],
          ),
          details: Map.unmodifiable(details),
        );
      }
    } on FormatException {
      // Fall through to the raw-body representation.
    }

    return ClobErrorResponse(
      message: raw,
      rawBody: body,
      httpStatus: httpStatus,
    );
  }

  final String message;
  final String rawBody;
  final int? httpStatus;
  final String? code;
  final String? type;
  final Map<String, dynamic> details;
}

final class AuthException extends PolydartException {
  const AuthException({
    required super.code,
    required super.message,
    super.cause,
  });
}

final class ClobException extends PolydartException {
  const ClobException({
    required super.code,
    required super.message,
    super.httpStatus,
    super.cause,
    this.upstream,
  });

  final ClobErrorResponse? upstream;
}

final class ValidationException extends PolydartException {
  const ValidationException({
    required super.code,
    required super.message,
    this.field,
    super.cause,
  });

  final String? field;

  @override
  String toString() {
    final base = '[${code.value}] $message';
    final withField = field == null ? base : '$base (field: $field)';
    if (cause != null) return '$withField: $cause';
    return withField;
  }
}

final class SafetyException extends PolydartException {
  const SafetyException({
    required super.code,
    required super.message,
    super.cause,
  });
}

final class GammaException extends PolydartException {
  const GammaException({
    required super.code,
    required super.message,
    super.httpStatus,
    super.cause,
  });
}

String? _firstString(
  Object? first, [
  Object? second,
  Object? third,
  Object? fourth,
  Object? fifth,
  Object? sixth,
]) {
  for (final value in <Object?>[first, second, third, fourth, fifth, sixth]) {
    final s = value?.toString().trim();
    if (s != null && s.isNotEmpty) return s;
  }
  return null;
}
