/// CLOB API client.
///
/// Mirrors `internal/clob`. Read paths (book / price / spread / …) are
/// always available; write paths (createOrder / cancelOrder / cancelAll /
/// cancelOrders) live behind [writes] and are gated by [PolydartMode.live].
library;

import '../auth/clob_auth.dart';
import '../auth/l2.dart';
import '../auth/wallet_signer.dart';
import '../errors/errors.dart';
import '../modes/modes.dart';
import '../transport/http_transport.dart';
import '../transport/transport_config.dart';
import '../types/clob.dart';
import 'clob_params.dart';
import 'clob_writes.dart';

final class ClobClient {
  ClobClient({
    HttpTransport? transport,
    PolydartMode mode = PolydartMode.readOnly,
    bool liveTradingEnabled = false,
    DateTime Function()? clock,
  }) : _transport =
           transport ??
           HttpTransport(
             config: const TransportConfig(baseUrl: defaultBaseUrl),
           ) {
    _writes = ClobWrites(
      transport: _transport,
      mode: mode,
      liveTradingEnabled: liveTradingEnabled,
      clock: clock,
    );
  }

  /// Public Polymarket CLOB base URL.
  static const String defaultBaseUrl = 'https://clob.polymarket.com';

  final HttpTransport _transport;
  late final ClobWrites _writes;

  /// Live-mode write surface. Every method throws [SafetyException] when
  /// the parent [Polydart] client is not in [PolydartMode.live] with the
  /// `liveTradingEnabled` flag on.
  ClobWrites get writes => _writes;

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

  /// Headless onboarding: creates the L2 API-key triple by signing the
  /// canonical ClobAuth EIP-712 payload with [signer] and posting it to
  /// `/auth/api-key`. Falls back to the deterministic
  /// `/auth/derive-api-key` when an account already exists.
  ///
  /// Mirrors `internal/clob/client.go` `CreateOrDeriveAPIKey`. The
  /// endpoint lazy-creates account, builder profile, and bytes32 builder
  /// code on first contact — see `polygolem/docs/BUILDER-AUTO.md` for the
  /// empirical flow.
  Future<ApiKey> createOrDeriveApiKey({
    required WalletSigner signer,
    int? nowSeconds,
  }) async {
    try {
      return await createApiKey(signer: signer, nowSeconds: nowSeconds);
    } on TransportException {
      return deriveApiKey(signer: signer, nowSeconds: nowSeconds);
    }
  }

  /// Mints a new API-key triple via `POST /auth/api-key`.
  Future<ApiKey> createApiKey({
    required WalletSigner signer,
    int? nowSeconds,
  }) async {
    final ts = nowSeconds ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final headers = await buildL1Headers(signer: signer, timestamp: ts);
    final body = await _transport.postJson(
      '/auth/api-key',
      const <String, dynamic>{},
      headers: headers,
    );
    return _parseApiKey(body);
  }

  /// Returns the deterministic API-key triple via `GET /auth/derive-api-key`.
  Future<ApiKey> deriveApiKey({
    required WalletSigner signer,
    int? nowSeconds,
  }) async {
    final ts = nowSeconds ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final headers = await buildL1Headers(signer: signer, timestamp: ts);
    final body = await _transport.getJson(
      '/auth/derive-api-key',
      headers: headers,
    );
    return _parseApiKey(body);
  }

  /// Parses the auth response, accepting the alternate field names the
  /// CLOB returns (`apiKey`/`api_key`, `passphrase`/`passPhrase`/`pass_phrase`).
  ApiKey _parseApiKey(Map<String, dynamic> body) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = body[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return '';
    }

    final key = pick(<String>['apiKey', 'api_key']);
    final secret = pick(<String>['secret']);
    final passphrase = pick(<String>['passphrase', 'passPhrase', 'pass_phrase']);
    final apiKey = ApiKey(key: key, secret: secret, passphrase: passphrase);
    apiKey.validate();
    return apiKey;
  }
}
