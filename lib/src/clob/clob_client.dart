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
import 'clob_analytics_types.dart';
import 'clob_auth_types.dart';
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

  // --- Market metadata ---

  /// Returns whether [tokenId] belongs to a negative-risk market.
  ///
  /// Mirrors `internal/clob/client.go::NegRisk`. The wire response is
  /// `{"neg_risk": bool}`; only the boolean flag is surfaced.
  Future<bool> negRisk(String tokenId) async {
    final body = await _transport.getJson(
      '/neg-risk',
      query: <String, dynamic>{'token_id': tokenId},
    );
    return body['neg_risk'] == true;
  }

  /// Returns the maker fee rate in basis points for [tokenId].
  ///
  /// Mirrors polygolem `FeeRateBps`. Response shape:
  /// `{"fee_rate_bps": <number>}`.
  Future<int> feeRateBps(String tokenId) async {
    final body = await _transport.getJson(
      '/fee-rate',
      query: <String, dynamic>{'token_id': tokenId},
    );
    return _toInt(body['fee_rate_bps']);
  }

  /// Cursor-paginated list of simplified markets.
  Future<ClobPaginatedMarkets> simplifiedMarkets({String? nextCursor}) async {
    final body = await _transport.getJson(
      '/simplified-markets',
      query: nextCursor == null || nextCursor.isEmpty
          ? null
          : <String, dynamic>{'next_cursor': nextCursor},
    );
    return ClobPaginatedMarkets.fromJson(body);
  }

  /// Cursor-paginated list of sampling markets.
  Future<ClobPaginatedMarkets> samplingMarkets({String? nextCursor}) async {
    final body = await _transport.getJson(
      '/sampling-markets',
      query: nextCursor == null || nextCursor.isEmpty
          ? null
          : <String, dynamic>{'next_cursor': nextCursor},
    );
    return ClobPaginatedMarkets.fromJson(body);
  }

  /// Cursor-paginated list of sampling-simplified markets.
  Future<ClobPaginatedMarkets> samplingSimplifiedMarkets({
    String? nextCursor,
  }) async {
    final body = await _transport.getJson(
      '/sampling-simplified-markets',
      query: nextCursor == null || nextCursor.isEmpty
          ? null
          : <String, dynamic>{'next_cursor': nextCursor},
    );
    return ClobPaginatedMarkets.fromJson(body);
  }

  // --- Batch pricing ---

  /// Best bid/ask for a list of token+side pairs.
  ///
  /// Posts to `/prices-post`; on transport failure (4xx/5xx) falls back
  /// to the legacy `/prices` endpoint. Mirrors polygolem `Prices`.
  /// Response shape `{"<token>": {"price": "<value>"}}` is flattened to
  /// `tokenId → priceString`. Non-wrapped values fall back to their raw
  /// JSON encoding.
  Future<Map<String, String>> prices(List<BookParams> params) async {
    final payload = params.map((p) => p.toJson()).toList(growable: false);
    Map<String, dynamic> raw;
    try {
      raw = await _transport.postJson('/prices-post', payload);
    } on TransportException {
      raw = await _transport.postJson('/prices', payload);
    }
    return _flattenWrapped(raw, 'price');
  }

  /// Midpoints for a list of token+side pairs.
  ///
  /// Mirrors polygolem `Midpoints`. Wrapped response
  /// `{"<token>": {"mid": "<value>"}}` is flattened.
  Future<Map<String, String>> midpoints(List<BookParams> params) async {
    final payload = params.map((p) => p.toJson()).toList(growable: false);
    final raw = await _transport.postJson('/midpoints', payload);
    return _flattenWrapped(raw, 'mid');
  }

  /// Last-trade prices for a list of token+side pairs.
  ///
  /// Mirrors polygolem `LastTradesPrices`. Wrapped response
  /// `{"<token>": {"price": "<value>"}}` is flattened.
  Future<Map<String, String>> lastTradesPrices(List<BookParams> params) async {
    final payload = params.map((p) => p.toJson()).toList(growable: false);
    final raw = await _transport.postJson('/last-trades-prices', payload);
    return _flattenWrapped(raw, 'price');
  }

  // --- Order scoring ---

  /// Whether [orderId] is currently scored for rewards.
  ///
  /// Wire response: `{"scoring": bool}`.
  Future<bool> orderScoring(String orderId) async {
    final body = await _transport.getJson(
      '/orders/scoring',
      query: <String, dynamic>{'order_id': orderId},
    );
    return body['scoring'] == true;
  }

  /// Batch scoring lookup. Returns one boolean per id, in the order
  /// the server returns them. Wire body: `{"order_ids": [...]}`,
  /// response: `[bool, ...]`.
  Future<List<bool>> ordersScoring(List<String> orderIds) async {
    final list = await _transport.postJsonList(
      '/orders/scoring',
      <String, dynamic>{'order_ids': orderIds},
    );
    return list.map((e) => e == true).toList(growable: false);
  }

  // --- Rewards ---

  /// Active rewards configuration across all markets.
  Future<List<RewardsConfig>> rewardsConfig() async {
    final list = await _transport.getJsonList('/rewards/config');
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => RewardsConfig.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Raw rewards series for a market (`market` is the condition id).
  Future<List<RawRewards>> rawRewards(String market) async {
    final list = await _transport.getJsonList(
      '/rewards/raw',
      query: <String, dynamic>{'market': market},
    );
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => RawRewards.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Caller-scoped earnings on [date] (YYYY-MM-DD).
  Future<List<UserEarnings>> userEarnings(String date) async {
    final list = await _transport.getJsonList(
      '/rewards/earnings',
      query: <String, dynamic>{'date': date},
    );
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => UserEarnings.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Aggregated earnings across all markets on [date] (YYYY-MM-DD).
  Future<TotalEarnings> totalEarnings(String date) async {
    final body = await _transport.getJson(
      '/rewards/total-earnings',
      query: <String, dynamic>{'date': date},
    );
    return TotalEarnings.fromJson(body);
  }

  /// Per-market reward percentages.
  Future<List<RewardPercentages>> rewardPercentages() async {
    final list = await _transport.getJsonList('/rewards/percentages');
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => RewardPercentages.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Caller-scoped rewards segmented by market. Optional [params]
  /// narrow the query (date / order_by / no_competition).
  Future<List<UserRewardsMarket>> userRewardsByMarket([
    UserRewardsByMarketRequest? params,
  ]) async {
    final query = params?.toQuery();
    final list = await _transport.getJsonList(
      '/rewards/markets',
      query: (query == null || query.isEmpty)
          ? null
          : query.map((k, v) => MapEntry<String, dynamic>(k, v)),
    );
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => UserRewardsMarket.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Maker rebated fees, summed across markets when the API returns
  /// rows without a `market` key.
  Future<List<RebatedFees>> rebatedFees() async {
    final list = await _transport.getJsonList('/rebates');
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => RebatedFees.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
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

  /// Returns every open order owned by the API-key wallet.
  ///
  /// Mirrors `internal/clob/orders.go::ListOrders`. Caller must supply a
  /// derived [ApiKey] — use [createOrDeriveApiKey] to mint one.
  Future<List<OrderRecord>> listOrders({required ApiKey apiKey}) async {
    final list = await _l2GetList(path: '/data/orders', apiKey: apiKey);
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => OrderRecord.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Returns the trade history for the API-key wallet.
  Future<List<TradeRecord>> listTrades({required ApiKey apiKey}) async {
    final list = await _l2GetList(path: '/data/trades', apiKey: apiKey);
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => TradeRecord.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Returns one order by id, scoped to the API-key wallet.
  Future<OrderRecord> order({
    required String orderId,
    required ApiKey apiKey,
  }) async {
    final path = '/data/order/$orderId';
    final body = await _l2Get(path: path, apiKey: apiKey);
    return OrderRecord.fromJson(body);
  }

  /// Returns CLOB collateral or conditional-token balance plus the V2
  /// exchange-spender allowances.
  Future<BalanceAllowanceResponse> balanceAllowance({
    required ApiKey apiKey,
    required BalanceAllowanceParams params,
  }) async {
    final query = params.toQuery();
    final body = await _l2Get(
      path: '/balance-allowance',
      apiKey: apiKey,
      query: query,
    );
    return BalanceAllowanceResponse.fromJson(body);
  }

  /// Forces the CLOB to refresh its on-chain balance/allowance cache.
  Future<BalanceAllowanceResponse> updateBalanceAllowance({
    required ApiKey apiKey,
    required BalanceAllowanceParams params,
  }) async {
    final query = params.toQuery();
    final body = await _l2Get(
      path: '/balance-allowance/update',
      apiKey: apiKey,
      query: query,
    );
    return BalanceAllowanceResponse.fromJson(body);
  }

  Future<Map<String, dynamic>> _l2Get({
    required String path,
    required ApiKey apiKey,
    Map<String, String>? query,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final headers = buildL2Headers(
      apiKey: apiKey,
      timestamp: ts,
      method: 'GET',
      path: _pathForSig(path, query),
    );
    return _transport.getJson(path, query: query, headers: headers);
  }

  Future<List<dynamic>> _l2GetList({
    required String path,
    required ApiKey apiKey,
    Map<String, String>? query,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final headers = buildL2Headers(
      apiKey: apiKey,
      timestamp: ts,
      method: 'GET',
      path: _pathForSig(path, query),
    );
    return _transport.getJsonList(path, query: query, headers: headers);
  }

  /// HMAC over the path + query for L2 GETs. Matches polygolem's
  /// `internal/auth.SignHMAC` input where `path` is the full URL path
  /// including query string.
  String _pathForSig(String path, Map<String, String>? query) {
    if (query == null || query.isEmpty) return path;
    final sb = StringBuffer(path)..write('?');
    var first = true;
    query.forEach((k, v) {
      if (!first) sb.write('&');
      sb..write(Uri.encodeQueryComponent(k))..write('=')..write(Uri.encodeQueryComponent(v));
      first = false;
    });
    return sb.toString();
  }

  /// Flattens `{"<token>": {"<inner>": "<value>"}}` to
  /// `tokenId → value`. Non-wrapped values fall back to their raw JSON
  /// encoding (matching polygolem's `string(v)` fallback for raw bytes).
  Map<String, String> _flattenWrapped(
    Map<String, dynamic> raw,
    String innerKey,
  ) {
    final out = <String, String>{};
    raw.forEach((k, v) {
      if (v is Map) {
        final inner = v[innerKey];
        if (inner != null) {
          out[k] = inner.toString();
          return;
        }
      }
      out[k] = v == null ? '' : v.toString();
    });
    return out;
  }

  int _toInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
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
