/// V2 Relayer API auth — mirrors `internal/relayer/auth_mint.go`.
///
/// `POST {relayerURL}/relayer/api/auth` with body `{}` and the polymarket
/// session cookie returns `{apiKey, address, createdAt, updatedAt}`.
/// Downstream relayer calls authenticate with two plain headers:
///
///   * `RELAYER_API_KEY`         — the apiKey UUID from the mint
///   * `RELAYER_API_KEY_ADDRESS` — the EOA address from the mint
///
/// No HMAC, no secret, no passphrase, no timestamp signature. Confirmed
/// against the bundled `@polymarket/relayer-client` SDK.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../auth/siwe_login.dart';
import '../errors/errors.dart';

const String defaultRelayerV2BaseUrl = 'https://relayer-v2.polymarket.com';

/// V2 Relayer API key triple (the "triple" is misleading — V2 uses two
/// fields). Timestamp fields are captured for diagnostics.
@immutable
final class V2APIKey {
  const V2APIKey({
    required this.key,
    required this.address,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory V2APIKey.fromJson(Map<String, dynamic> json) {
    return V2APIKey(
      key: (json['apiKey'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      updatedAt: (json['updatedAt'] ?? '').toString(),
    );
  }

  final String key;
  final String address;
  final String createdAt;
  final String updatedAt;

  /// Plain headers the V2 relayer expects on every authenticated request.
  Map<String, String> v2Headers() => <String, String>{
    'RELAYER_API_KEY': key,
    'RELAYER_API_KEY_ADDRESS': address,
  };
}

/// Mints a V2 Relayer API Key by POSTing `{}` to
/// `{relayerURL}/relayer/api/auth` with the cookie from [session].
///
/// Each call mints a fresh key — persist the result and don't re-mint
/// per request.
Future<V2APIKey> mintV2APIKey({
  required SIWESession session,
  String relayerBaseUrl = defaultRelayerV2BaseUrl,
  http.Client? httpClient,
}) async {
  if (!session.hasSession) {
    throw const AuthException(
      code: ErrorCode.missingCreds,
      message: 'mintV2APIKey: SIWESession has no cookies — call login() first',
    );
  }

  final uri = Uri.parse('${_strip(relayerBaseUrl)}/relayer/api/auth');
  final client = httpClient ?? http.Client();
  final ownsClient = httpClient == null;

  try {
    final resp = await client.post(
      uri,
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Cookie': session.cookieHeader(),
      },
      body: '{}',
    );
    if (resp.statusCode < 200 || resp.statusCode > 299) {
      throw TransportException(
        code: ErrorCode.connectionFailed,
        message: 'mintV2APIKey: HTTP ${resp.statusCode} ${resp.body}',
      );
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final key = V2APIKey.fromJson(json);
    if (key.key.trim().isEmpty || key.address.trim().isEmpty) {
      throw TransportException(
        code: ErrorCode.connectionFailed,
        message:
            'mintV2APIKey: relayer returned incomplete key '
            '(apiKey=${key.key} address=${key.address})',
      );
    }
    return key;
  } finally {
    if (ownsClient) client.close();
  }
}

String _strip(String url) =>
    url.endsWith('/') ? url.substring(0, url.length - 1) : url;
