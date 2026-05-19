/// Order book reader — fetches CLOB order books by token ID.
///
/// Mirrors `pkg/orderbook` from polygolem. Provides [OrderBookReader] for
/// single-token fetches and [BatchOrderBookReader] for multi-token batch
/// fetches. Both use the CLOB HTTP API under the hood.
///
/// Combine with [BookReader] from `../bookreader/` for computed metrics
/// (midpoint, spread, depth) on the fetched snapshot.
library;

import 'package:http/http.dart' as http;

import '../errors/errors.dart';
import '../transport/http_transport.dart';
import '../transport/transport_config.dart';
import '../types/clob.dart';

/// Default Polymarket CLOB base URL.
const String defaultClobBaseUrl = 'https://clob.polymarket.com';

/// Fetches CLOB order books by ERC-1155 token ID.
///
/// Implementations must be safe for concurrent use.
/// Mirrors `orderbook.Reader` from polygolem.
abstract interface class OrderBookReader {
  /// Returns the current order-book snapshot for [tokenId].
  /// The returned [OrderBook] is sorted best-first on each side.
  Future<OrderBook> orderBook(String tokenId);
}

/// Fetches multiple CLOB order books in one API request.
///
/// Mirrors `orderbook.BatchReader` from polygolem.
abstract interface class BatchOrderBookReader implements OrderBookReader {
  /// Returns order-book snapshots for all [tokenIds] in a single request.
  /// Empty token IDs are silently skipped.
  Future<List<OrderBook>> orderBooks(List<String> tokenIds);
}

/// Production [OrderBookReader] backed by the CLOB HTTP API.
///
/// Implements both [OrderBookReader] and [BatchOrderBookReader].
final class ClobOrderBookReader
    implements OrderBookReader, BatchOrderBookReader {
  /// Creates a reader pointing at [clobBaseUrl].
  /// Defaults to [defaultClobBaseUrl] when empty.
  ClobOrderBookReader({
    String clobBaseUrl = defaultClobBaseUrl,
    HttpTransport? transport,
    http.Client? httpClient,
  }) : _transport =
           transport ??
           HttpTransport(
             config: TransportConfig(
               baseUrl: clobBaseUrl.isEmpty ? defaultClobBaseUrl : clobBaseUrl,
             ),
             inner: httpClient,
           );

  final HttpTransport _transport;

  @override
  Future<OrderBook> orderBook(String tokenId) async {
    if (tokenId.isEmpty) {
      throw const ValidationException(
        code: ErrorCode.missingField,
        message: 'tokenId must not be empty',
        field: 'tokenId',
      );
    }
    final body = await _transport.getJson(
      '/book',
      query: <String, dynamic>{'token_id': tokenId},
    );
    return OrderBook.fromJson(body);
  }

  @override
  Future<List<OrderBook>> orderBooks(List<String> tokenIds) async {
    final filtered = tokenIds.where((id) => id.isNotEmpty).toList();
    if (filtered.isEmpty) return const <OrderBook>[];

    final list = await _transport.postJsonList(
      '/books',
      filtered
          .map((id) => <String, dynamic>{'token_id': id})
          .toList(growable: false),
    );

    return list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => OrderBook.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Closes the underlying transport.
  void close() => _transport.close();
}
