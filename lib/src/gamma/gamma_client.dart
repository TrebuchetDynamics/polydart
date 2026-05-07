/// Read-only Gamma API client.
///
/// Mirrors the read-side of `internal/gamma`. Phase 1 ships `markets`,
/// `marketBySlug`, `marketById`, `search`, and `health`. Events, series,
/// tags, comments, and teams arrive in later commits.
library;

import '../transport/http_transport.dart';
import '../transport/transport_config.dart';
import '../types/market.dart';
import 'gamma_params.dart';

final class GammaClient {
  GammaClient({HttpTransport? transport})
    : _transport =
          transport ??
          HttpTransport(config: const TransportConfig(baseUrl: defaultBaseUrl));

  /// Public Polymarket Gamma base URL.
  static const String defaultBaseUrl = 'https://gamma-api.polymarket.com';

  final HttpTransport _transport;

  /// Closes the underlying HTTP transport. Safe to call multiple times.
  void close() => _transport.close();

  /// Fetches the root endpoint to verify reachability.
  Future<HealthResponse> health() async {
    final body = await _transport.getJson('/');
    if (body.isEmpty) return const HealthResponse(data: 'ok');
    return HealthResponse.fromJson(body);
  }

  /// Lists markets with optional filters.
  Future<List<Market>> markets([
    GetMarketsParams params = const GetMarketsParams(),
  ]) async {
    final list = await _transport.getJsonList(
      '/markets',
      query: params.toQuery(),
    );
    return _markets(list);
  }

  /// Returns a single market by Gamma id.
  Future<Market?> marketById(String id) async {
    final body = await _transport.getJson('/markets/$id');
    if (body.isEmpty) return null;
    return Market.fromJson(body);
  }

  /// Returns a single market by slug.
  ///
  /// Polymarket exposes `/markets/{slugOrId}` for both lookups; the API
  /// returns the same shape either way. We expose them as separate methods
  /// so callers see intent.
  Future<Market?> marketBySlug(String slug) => marketById(slug);

  /// Cross-entity search.
  Future<SearchResponse> search(SearchParams params) async {
    final body = await _transport.getJson(
      '/public-search',
      query: params.toQuery(),
    );
    return SearchResponse.fromJson(body);
  }

  static List<Market> _markets(List<dynamic> raw) => raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => Market.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);
}
