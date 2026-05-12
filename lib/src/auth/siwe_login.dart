/// Polymarket SIWE login orchestrator. Mirrors `internal/auth/siwe_login.go`.
///
/// Wire flow:
///   1. `GET  {gammaURL}/nonce` → `{ nonce: "..." }`
///   2. Build [SIWEMessage], `personalSign` via [WalletSigner]
///   3. `GET  {gammaURL}/login` with `Authorization: Bearer <token>`
///      → `Set-Cookie: <polymarket session>` headers
///   4. Cookies are captured into the session and exposed via
///      [SIWESession.cookieHeader] for downstream calls.
///
/// Polydart deliberately uses manual cookie capture rather than a jar
/// library to keep the dependency surface small. The downstream call —
/// `POST relayer-v2.polymarket.com/relayer/api/auth` — accepts the cookie
/// header verbatim, so a jar is unnecessary.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/errors.dart';
import 'siwe.dart';
import 'wallet_signer.dart';

/// Holds the cookies captured by [SIWESession.login] and exposes them as
/// a `Cookie:` header for downstream relayer calls.
final class SIWESession {
  SIWESession({
    required this.signer,
    String gammaBaseUrl = defaultGammaBaseUrl,
    http.Client? httpClient,
    DateTime Function()? clock,
  }) : _gammaBaseUrl = _stripTrailing(gammaBaseUrl),
       _http = httpClient ?? http.Client(),
       _clock = clock ?? DateTime.now;

  static const String defaultGammaBaseUrl = 'https://gamma-api.polymarket.com';

  final WalletSigner signer;
  final String _gammaBaseUrl;
  final http.Client _http;
  final DateTime Function() _clock;

  /// Cookies captured from the most recent `Set-Cookie` response. Each
  /// entry is the raw `name=value` pair (no Domain / Path / Expires —
  /// the relayer doesn't validate those, it just needs the cookie pair).
  final List<String> _cookies = <String>[];

  /// Returns the `Cookie:` header value for downstream calls — empty if
  /// [login] hasn't run successfully yet.
  String cookieHeader() => _cookies.join('; ');

  /// True once [login] has captured at least one cookie.
  bool get hasSession => _cookies.isNotEmpty;

  /// Releases the underlying HTTP client. Idempotent.
  void close() => _http.close();

  /// Runs the SIWE login. On success the polymarket session cookie is
  /// captured and returned via [cookieHeader].
  Future<void> login() async {
    final nonce = await _fetchNonce();
    final msg = buildPolymarketSIWE(
      address: signer.address,
      nonce: nonce,
      chainId: signer.chainId,
      now: _clock().toUtc(),
    );
    final sig = await signer.personalSign(utf8.encode(msg.toString()));
    final token = buildSIWEBearerToken(msg, sig);
    await _callLogin(token);
  }

  Future<String> _fetchNonce() async {
    final uri = Uri.parse('$_gammaBaseUrl/nonce');
    final resp = await _http.get(
      uri,
      headers: <String, String>{'Accept': 'application/json'},
    );
    _captureCookies(resp);
    if (resp.statusCode < 200 || resp.statusCode > 299) {
      throw TransportException(
        code: ErrorCode.connectionFailed,
        message: 'siwe nonce: HTTP ${resp.statusCode} ${resp.body}',
      );
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final nonce = (body['nonce'] ?? '').toString();
    if (nonce.trim().isEmpty) {
      throw const TransportException(
        code: ErrorCode.connectionFailed,
        message: 'siwe nonce: server returned empty nonce',
      );
    }
    return nonce;
  }

  Future<void> _callLogin(String bearerToken) async {
    final uri = Uri.parse('$_gammaBaseUrl/login');
    final resp = await _http.get(
      uri,
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $bearerToken',
        if (_cookies.isNotEmpty) 'Cookie': cookieHeader(),
      },
    );
    _captureCookies(resp);
    if (resp.statusCode < 200 || resp.statusCode > 299) {
      throw TransportException(
        code: ErrorCode.connectionFailed,
        message: 'siwe login: HTTP ${resp.statusCode} ${resp.body}',
      );
    }
  }

  void _captureCookies(http.Response resp) {
    // package:http drops repeated Set-Cookie headers in resp.headers
    // (Map<String, String> with comma-joined values). Try both the joined
    // header and any raw split-set on the underlying response.
    final raw = resp.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;
    for (final cookie in _splitSetCookie(raw)) {
      final pair = cookie.split(';').first.trim();
      if (pair.isEmpty) continue;
      final name = pair.split('=').first;
      // Replace existing cookie of the same name; otherwise append.
      _cookies.removeWhere((c) => c.startsWith('$name='));
      _cookies.add(pair);
    }
  }
}

/// Splits a comma-joined Set-Cookie header into individual cookies. The
/// HTTP spec allows multiple Set-Cookie headers but RFC 7230 forbids
/// joining them with commas — except that's exactly what package:http
/// does when downcasting to Map<String, String>. We split on commas not
/// inside the Expires=... attribute (which contains a comma in the
/// weekday).
List<String> _splitSetCookie(String joined) {
  final out = <String>[];
  final buf = StringBuffer();
  for (var i = 0; i < joined.length; i++) {
    final c = joined[i];
    if (c == ',') {
      // Look ahead to see if this comma is inside an Expires= attribute.
      final remaining = joined.substring(i + 1).trimLeft();
      if (RegExp(r'^\s*\d{1,2}[-\s]').hasMatch(remaining)) {
        // Likely Expires=Wed, 09-Jun-2026 ... — the comma is separator
        // between weekday and date. Keep it as part of the current cookie.
        buf.write(c);
        continue;
      }
      out.add(buf.toString().trim());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  if (buf.isNotEmpty) out.add(buf.toString().trim());
  return out;
}

String _stripTrailing(String url) {
  return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
