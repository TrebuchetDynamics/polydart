/// Builder header signing adapters.
///
/// Mirrors `polygolem/pkg/builder` while keeping credentials outside SDK
/// storage. Local signing wraps [buildBuilderHeaders]; remote signing delegates
/// header creation to a caller-owned signer service.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../auth/l2.dart';

const String polyBuilderApiKeyHeader = 'POLY_BUILDER_API_KEY';
const String polyBuilderPassphraseHeader = 'POLY_BUILDER_PASSPHRASE';
const String polyBuilderTimestampHeader = 'POLY_BUILDER_TIMESTAMP';
const String polyBuilderSignatureHeader = 'POLY_BUILDER_SIGNATURE';

abstract interface class BuilderSigner {
  Future<Map<String, String>> createHeaders({
    required String method,
    required String path,
    String? body,
    int? timestamp,
  });
}

@immutable
final class LocalBuilderSignerConfig {
  const LocalBuilderSignerConfig({
    this.key = '',
    this.secret = '',
    this.passphrase = '',
  });

  final String key;
  final String secret;
  final String passphrase;

  BuilderConfig toBuilderConfig() {
    return BuilderConfig(key: key, secret: secret, passphrase: passphrase);
  }
}

final class LocalBuilderSigner implements BuilderSigner {
  LocalBuilderSigner(LocalBuilderSignerConfig config) : _config = config {
    if (!config.toBuilderConfig().isValid) {
      throw ArgumentError('builder signer config incomplete');
    }
  }

  final LocalBuilderSignerConfig _config;

  @override
  Future<Map<String, String>> createHeaders({
    required String method,
    required String path,
    String? body,
    int? timestamp,
  }) async {
    return buildBuilderHeaders(
      config: _config.toBuilderConfig(),
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      method: method,
      path: path,
      body: body,
    );
  }
}

@immutable
final class RemoteBuilderSignerConfig {
  const RemoteBuilderSignerConfig({required this.url, required this.token});

  final String url;
  final String token;
}

final class RemoteBuilderSigner implements BuilderSigner {
  RemoteBuilderSigner(
    RemoteBuilderSignerConfig config, {
    http.Client? httpClient,
  }) : _config = config,
       _client = httpClient ?? http.Client(),
       _ownsClient = httpClient == null {
    if (config.url.trim().isEmpty) {
      throw ArgumentError('remote signer URL is required');
    }
    if (config.token.trim().isEmpty) {
      throw ArgumentError('remote signer token is required');
    }
  }

  final RemoteBuilderSignerConfig _config;
  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<Map<String, String>> createHeaders({
    required String method,
    required String path,
    String? body,
    int? timestamp,
  }) async {
    final payload = <String, dynamic>{'method': method, 'path': path};
    if (body != null) payload['body'] = body;
    if (timestamp != null) payload['timestamp'] = timestamp.toString();

    final response = await _client.post(
      Uri.parse(_config.url),
      headers: <String, String>{
        'Authorization': 'Bearer ${_config.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw RemoteBuilderSignerException(
        'remote signer returned HTTP ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return const <String, String>{};
    return decoded.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

final class RemoteBuilderSignerException implements Exception {
  const RemoteBuilderSignerException(this.message);

  final String message;

  @override
  String toString() => 'RemoteBuilderSignerException: $message';
}

String genSignature({
  required String secret,
  required int timestamp,
  required String method,
  required String path,
  String? body,
}) {
  return signHmac(
    secret: secret,
    timestamp: timestamp,
    method: method,
    path: path,
    body: body,
  );
}
