/// Read-only CLOB API client.
///
/// Mirrors the read-side of `internal/clob`. Phase 1 ships every endpoint
/// that does not require an L1/L2 signature: server time, markets, books,
/// prices, midpoints, spreads, tick sizes, last-trade prices, and price
/// history. Authenticated endpoints (balance-allowance, API keys,
/// rewards, order create / cancel) land in Phase 2.
library;

import '../transport/http_transport.dart';
import '../transport/transport_config.dart';
import '../types/clob.dart';
import 'clob_params.dart';

final class ClobClient {
  ClobClient({HttpTransport? transport})
    : _transport =
          transport ??
          HttpTransport(config: const TransportConfig(baseUrl: defaultBaseUrl));

  /// Public Polymarket CLOB base URL.
  static const String defaultBaseUrl = 'https://clob.polymarket.com';

  final HttpTransport _transport;

  /// Closes the underlying transport.
  void close() => _transport.close();

  /// Pings the root endpoint. Throws [TransportException] on failure.
  Future<void> health() async {
    await _transport.getJson('/');
  }

  /// Returns the server's current time.
  Future<ServerTime> serverTime() async {
    final body = await _transport.getJson('/time');
    return ServerTime.fromJson(body);
  }

  /// Lists CLOB markets with cursor pagination.
  Future<ClobPaginatedMarkets> markets({String? nextCursor}) async {
    final body = await _transport.getJson(
      '/markets',
      query: nextCursor == null || nextCursor.isEmpty
          ? null
          : <String, dynamic>{'next_cursor': nextCursor},
    );
    return ClobPaginatedMarkets.fromJson(body);
  }

  /// Returns a single CLOB market by condition id.
  Future<ClobMarket> market(String conditionId) async {
    final body = await _transport.getJson('/markets/$conditionId');
    return ClobMarket.fromJson(body);
  }

  /// Returns L2 order book depth for [tokenId].
  Future<OrderBook> orderBook(String tokenId) async {
    final body = await _transport.getJson(
      '/book',
      query: <String, dynamic>{'token_id': tokenId},
    );
    return OrderBook.fromJson(body);
  }

  /// Batch order books — POST `/books`.
  Future<List<OrderBook>> orderBooks(List<BookParams> params) async {
    final list = await _transport.postJsonList(
      '/books',
      params.map((p) => p.toJson()).toList(growable: false),
    );
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => OrderBook.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Best bid/ask for [tokenId] on a side ("BUY" or "SELL").
  Future<String> price(String tokenId, String side) async {
    final body = await _transport.getJson(
      '/price',
      query: <String, dynamic>{'token_id': tokenId, 'side': side},
    );
    return body['price']?.toString() ?? '';
  }

  /// Midpoint for a single token.
  Future<String> midpoint(String tokenId) async {
    final body = await _transport.getJson(
      '/midpoint',
      query: <String, dynamic>{'token_id': tokenId},
    );
    return body['mid']?.toString() ?? '';
  }

  /// Spread for a single token.
  Future<String> spread(String tokenId) async {
    final body = await _transport.getJson(
      '/spread',
      query: <String, dynamic>{'token_id': tokenId},
    );
    return body['spread']?.toString() ?? '';
  }

  /// Last trade price for a single token.
  Future<String> lastTradePrice(String tokenId) async {
    final body = await _transport.getJson(
      '/last-trade-price',
      query: <String, dynamic>{'token_id': tokenId},
    );
    return body['price']?.toString() ?? '';
  }

  /// Tick size for a single token.
  Future<TickSize> tickSize(String tokenId) async {
    final body = await _transport.getJson(
      '/tick-size',
      query: <String, dynamic>{'token_id': tokenId},
    );
    return TickSize.fromJson(body);
  }

  /// OHLCV-style price history.
  Future<PriceHistory> pricesHistory(PriceHistoryParams params) async {
    final body = await _transport.getJson(
      '/prices-history',
      query: params.toQuery(),
    );
    return PriceHistory.fromJson(body);
  }
}
