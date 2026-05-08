/// L2 HMAC-SHA256 authentication.
///
/// Mirrors `internal/auth/l2.go`. Signs Polymarket CLOB requests that
/// require an API-key triple (key/secret/passphrase). Builder attribution
/// headers (separate `POLY_BUILDER_*` set) live here too.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart' show Hmac, sha256;
import 'package:meta/meta.dart';

import '../errors/errors.dart';
import '../transport/redact.dart';

/// L2 API-key triple. The secret is base64-encoded.
@immutable
final class ApiKey {
  const ApiKey({
    required this.key,
    required this.secret,
    required this.passphrase,
  });

  final String key;
  final String secret;
  final String passphrase;

  void validate() {
    if (key.isEmpty) {
      throw const AuthException(
        code: ErrorCode.missingCreds,
        message: 'API key is empty',
      );
    }
    if (secret.isEmpty) {
      throw const AuthException(
        code: ErrorCode.missingCreds,
        message: 'API secret is empty',
      );
    }
    if (passphrase.isEmpty) {
      throw const AuthException(
        code: ErrorCode.missingCreds,
        message: 'API passphrase is empty',
      );
    }
  }

  ApiKey redacted() => ApiKey(
    key: redactSecret(key),
    secret: redactSecret(secret),
    passphrase: redactSecret(passphrase),
  );

  @override
  String toString() {
    final r = redacted();
    return 'ApiKey(key=${r.key}, secret=${r.secret}, passphrase=${r.passphrase})';
  }
}

/// Builder-attribution credentials. Distinct from user [ApiKey] per PRD §R3.
@immutable
final class BuilderConfig {
  const BuilderConfig({
    required this.key,
    required this.secret,
    required this.passphrase,
  });

  final String key;
  final String secret;
  final String passphrase;

  bool get isValid =>
      key.isNotEmpty && secret.isNotEmpty && passphrase.isNotEmpty;
}

/// Computes the Polymarket-compatible HMAC-SHA256 signature.
///
/// `signature = url-safe-base64(HMAC-SHA256(decoded_secret, msg))` where
/// `msg = "${timestamp}${METHOD}${path}${body?}"`. Body must be already
/// compacted by the caller — use [compactJson] for the canonical form.
String signHmac({
  required String secret,
  required int timestamp,
  required String method,
  required String path,
  String? body,
}) {
  final key = _decodeHmacSecret(secret);
  final buf = StringBuffer()
    ..write(timestamp)
    ..write(method.toUpperCase())
    ..write(path);
  if (body != null && body.isNotEmpty) buf.write(body);
  final digest = Hmac(sha256, key).convert(utf8.encode(buf.toString()));
  // Standard base64, then convert + → - and / → _ to match polygolem.
  final std = base64.encode(digest.bytes);
  return std.replaceAll('+', '-').replaceAll('/', '_');
}

/// Builds POLY_API_KEY / POLY_PASSPHRASE / POLY_TIMESTAMP / POLY_SIGNATURE.
Map<String, String> buildL2Headers({
  required ApiKey apiKey,
  required int timestamp,
  required String method,
  required String path,
  String? body,
}) {
  apiKey.validate();
  final sig = signHmac(
    secret: apiKey.secret,
    timestamp: timestamp,
    method: method,
    path: path,
    body: body,
  );
  return <String, String>{
    'POLY_API_KEY': apiKey.key,
    'POLY_PASSPHRASE': apiKey.passphrase,
    'POLY_TIMESTAMP': timestamp.toString(),
    'POLY_SIGNATURE': sig,
  };
}

/// Builds the POLY_BUILDER_* attribution header set.
Map<String, String> buildBuilderHeaders({
  required BuilderConfig config,
  required int timestamp,
  required String method,
  required String path,
  String? body,
}) {
  if (!config.isValid) {
    throw const AuthException(
      code: ErrorCode.missingCreds,
      message: 'builder config incomplete',
    );
  }
  final sig = signHmac(
    secret: config.secret,
    timestamp: timestamp,
    method: method,
    path: path,
    body: body,
  );
  return <String, String>{
    'POLY_BUILDER_API_KEY': config.key,
    'POLY_BUILDER_PASSPHRASE': config.passphrase,
    'POLY_BUILDER_TIMESTAMP': timestamp.toString(),
    'POLY_BUILDER_SIGNATURE': sig,
  };
}

/// Strips whitespace outside string literals. Used to canonicalise a
/// JSON body before HMAC signing.
String compactJson(String input) {
  final out = StringBuffer();
  var inString = false;
  var escape = false;
  for (final code in input.codeUnits) {
    final ch = String.fromCharCode(code);
    if (escape) {
      out.write(ch);
      escape = false;
      continue;
    }
    if (inString) {
      if (ch == r'\') {
        out.write(ch);
        escape = true;
        continue;
      }
      if (ch == '"') {
        inString = false;
      }
      out.write(ch);
      continue;
    }
    if (ch == '"') {
      inString = true;
      out.write(ch);
      continue;
    }
    if (ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t') continue;
    out.write(ch);
  }
  return out.toString();
}

/// Tries every base64 dialect Polymarket has used for the secret.
/// Falls back to raw UTF-8 bytes if nothing decodes — matches polygolem.
List<int> _decodeHmacSecret(String secret) {
  for (final padded in <String>[_padBase64(secret), secret]) {
    for (final urlSafe in const <bool>[true, false]) {
      try {
        return urlSafe ? base64Url.decode(padded) : base64.decode(padded);
      } on FormatException {
        continue;
      }
    }
  }
  return utf8.encode(secret);
}

String _padBase64(String s) {
  final pad = (4 - s.length % 4) % 4;
  if (pad == 0) return s;
  return s + '=' * pad;
}
