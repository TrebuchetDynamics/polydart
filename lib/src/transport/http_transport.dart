/// HTTP transport with retry and timeout.
///
/// Mirrors `internal/transport/client.go`. Phase 1 ships GET / POST / DELETE
/// with exponential-backoff retry on idempotent reads. Rate limiting and
/// circuit breaker land in a follow-up commit.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/errors.dart';
import '../logging/logger.dart';
import 'transport_config.dart';

/// HTTP transport. Inject an [http.Client] for testing.
final class HttpTransport {
  HttpTransport({
    required this.config,
    http.Client? inner,
    Logger? logger,
  })  : _inner = inner ?? http.Client(),
        _logger = logger ?? Logger.silent;

  final TransportConfig config;
  final http.Client _inner;
  final Logger _logger;

  /// Closes the underlying client.
  void close() => _inner.close();

  /// Performs a GET request and decodes the JSON response as a map.
  ///
  /// `query` values may be `String` or `Iterable<String>`. Iterable values
  /// emit one query-string pair per element (e.g. `slug=a&slug=b`).
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final resp = await _do('GET', path, query: query, headers: headers);
    return _decodeMap(resp);
  }

  /// Performs a GET request and decodes the JSON response as a list.
  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final resp = await _do('GET', path, query: query, headers: headers);
    return _decodeList(resp);
  }

  /// Performs a POST request. POSTs are not retried.
  Future<Map<String, dynamic>> postJson(
    String path,
    Object? body, {
    Map<String, String>? headers,
  }) async {
    final resp = await _do('POST', path, body: body, headers: headers);
    return _decodeMap(resp);
  }

  /// Performs a DELETE request. Returns the parsed JSON map if any.
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    final resp = await _do('DELETE', path, headers: headers);
    if (resp.body.isEmpty) return const <String, dynamic>{};
    return _decodeMap(resp);
  }

  /// Fetches raw bytes without retry or JSON decoding.
  Future<List<int>> getBytes(String path, {Map<String, dynamic>? query}) async {
    final resp = await _do('GET', path, query: query, retry: false);
    return resp.bodyBytes;
  }

  Future<http.Response> _do(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool retry = true,
  }) async {
    final url = _buildUrl(path, query);
    final maxAttempts =
        (retry && method == 'GET' ? config.retryMax : 0) + 1;

    TransportException? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        final shift = attempt - 1;
        final delay = Duration(
          microseconds: config.retryDelay.inMicroseconds << shift,
        );
        _logger.debug(
          'transport.retry',
          fields: {
            'method': method,
            'url': url,
            'attempt': attempt,
            'delay_ms': delay.inMilliseconds,
          },
        );
        await Future<void>.delayed(delay);
      }

      try {
        final resp = await _attempt(method, url, body, headers);
        if (resp.statusCode == 429) {
          throw const TransportException(
            code: ErrorCode.rateLimited,
            message: 'rate limited',
            httpStatus: 429,
          );
        }
        if (resp.statusCode >= 500) {
          throw TransportException(
            code: ErrorCode.connectionFailed,
            message: 'server error: ${_truncate(resp.body)}',
            httpStatus: resp.statusCode,
          );
        }
        if (resp.statusCode < 200 || resp.statusCode > 299) {
          throw TransportException(
            code: ErrorCode.connectionFailed,
            message:
                'HTTP ${resp.statusCode} $url: ${_truncate(resp.body)}',
            httpStatus: resp.statusCode,
          );
        }
        return resp;
      } on TransportException catch (e) {
        lastError = e;
        if (!_isRetryable(e, method)) rethrow;
      } on TimeoutException catch (e) {
        lastError = TransportException(
          code: ErrorCode.timeout,
          message: 'request timed out',
          cause: e,
        );
        if (method != 'GET') rethrow;
      } on http.ClientException catch (e) {
        lastError = TransportException(
          code: ErrorCode.connectionFailed,
          message: 'request failed',
          cause: e,
        );
        if (method != 'GET') rethrow;
      } on Exception catch (e) {
        lastError = TransportException(
          code: ErrorCode.connectionFailed,
          message: 'request failed',
          cause: e,
        );
        if (method != 'GET') rethrow;
      }
    }

    throw lastError ??
        const TransportException(
          code: ErrorCode.connectionFailed,
          message: 'request failed with no recorded error',
        );
  }

  Future<http.Response> _attempt(
    String method,
    String url,
    Object? body,
    Map<String, String>? headers,
  ) async {
    final req = http.Request(method, Uri.parse(url));
    req.headers['Accept'] = 'application/json';
    req.headers['User-Agent'] = config.userAgent;
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    if (headers != null) req.headers.addAll(headers);

    final streamed = await _inner.send(req).timeout(config.timeout);
    return http.Response.fromStream(streamed);
  }

  String _buildUrl(String path, Map<String, dynamic>? query) {
    final base = config.normalisedBaseUrl;
    final joined = path.startsWith('/') ? '$base$path' : '$base/$path';
    if (query == null || query.isEmpty) return joined;

    final cleaned = <String, dynamic>{};
    for (final e in query.entries) {
      final v = e.value;
      if (v == null) continue;
      if (v is Iterable) {
        final list = v
            .where((x) => x != null && x.toString().isNotEmpty)
            .map((x) => x.toString())
            .toList(growable: false);
        if (list.isNotEmpty) cleaned[e.key] = list;
      } else {
        final s = v.toString();
        if (s.isNotEmpty) cleaned[e.key] = s;
      }
    }
    if (cleaned.isEmpty) return joined;

    return Uri.parse(joined).replace(queryParameters: cleaned).toString();
  }

  bool _isRetryable(TransportException e, String method) {
    if (method != 'GET') return false;
    if (e.code == ErrorCode.timeout) return true;
    if (e.code == ErrorCode.rateLimited) return true;
    final status = e.httpStatus;
    if (status != null && status >= 500) return true;
    if (status == null && e.code == ErrorCode.connectionFailed) return true;
    return false;
  }

  Map<String, dynamic> _decodeMap(http.Response resp) {
    if (resp.body.isEmpty) return const <String, dynamic>{};
    final decoded = jsonDecode(resp.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw TransportException(
      code: ErrorCode.connectionFailed,
      message: 'expected JSON object, got ${decoded.runtimeType}',
      httpStatus: resp.statusCode,
    );
  }

  List<dynamic> _decodeList(http.Response resp) {
    if (resp.body.isEmpty) return const <dynamic>[];
    final decoded = jsonDecode(resp.body);
    if (decoded is List) return decoded;
    throw TransportException(
      code: ErrorCode.connectionFailed,
      message: 'expected JSON array, got ${decoded.runtimeType}',
      httpStatus: resp.statusCode,
    );
  }

  String _truncate(String s, {int max = 200}) =>
      s.length <= max ? s : '${s.substring(0, max)}…';
}
