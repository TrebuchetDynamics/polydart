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
import '../gamma/gamma_client.dart';
import '../gamma/gamma_params.dart';
import '../modes/modes.dart';
import '../transport/http_transport.dart';
import '../transport/transport_config.dart';
import '../types/clob.dart';
import 'clob_analytics_types.dart';
import 'clob_auth_types.dart';
import 'clob_params.dart';
import 'clob_writes.dart';
import 'shared/clob_json.dart';

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

  /// Resolves a token id to its parent CLOB market ids.
  Future<ClobMarketByTokenResponse> marketByToken(String tokenId) async {
    final body = await _transport.getJson('/markets-by-token/$tokenId');
    return ClobMarketByTokenResponse.fromJson(body);
  }

  /// Resolves a market's outcome by condition id.
  ///
  /// Queries the CLOB API first. When CLOB knows the market but it is not yet
  /// closed (or has no single winner) the result is
  /// [ClobMarketOutcomeStatus.unresolved]. If the CLOB lookup fails (for
  /// example a 404) and [gammaBaseUrl] is non-empty, resolution falls back to
  /// the Gamma API. The winning token id is carried only when CLOB confirms
  /// the market closed with exactly one winning token.
  ///
  /// Mirrors `pkg/clob.Client.MarketOutcome`.
  Future<ClobMarketOutcome> marketOutcome(
    String conditionId, {
    String gammaBaseUrl = '',
  }) async {
    final id = conditionId.trim();
    if (id.isEmpty) {
      throw const ValidationException(
        code: ErrorCode.missingField,
        message: 'conditionId must not be empty',
        field: 'conditionId',
      );
    }

    // First try CLOB.
    try {
      final marketRow = await market(id);
      final winner = _winningTokenId(marketRow);
      if (marketRow.closed && winner.isNotEmpty) {
        return ClobMarketOutcome(
          status: ClobMarketOutcomeStatus.resolved,
          conditionId: id,
          winningTokenId: winner,
          closed: true,
          source: 'clob:/markets/$id',
        );
      }
      // CLOB knows the market but it is not yet closed or has no winner.
      return ClobMarketOutcome(
        status: ClobMarketOutcomeStatus.unresolved,
        conditionId: id,
        closed: marketRow.closed,
        source: 'clob:/markets/$id:not_closed_or_no_winner',
      );
    } catch (_) {
      // Fall back to Gamma when CLOB returned an error (e.g. 404).
      final gammaUrl = gammaBaseUrl.trim();
      if (gammaUrl.isEmpty) {
        rethrow;
      }
      final outcome = await _resolveViaGamma(gammaUrl, id);
      if (outcome != null) {
        return outcome;
      }
      // Both CLOB and Gamma failed — surface the original CLOB error.
      rethrow;
    }
  }

  /// Returns the single winning token id, or '' when zero or more than one
  /// token is flagged as the winner. Mirrors `winningTokenID`.
  static String _winningTokenId(ClobMarket market) {
    var winner = '';
    var count = 0;
    for (final token in market.tokens) {
      if (token.winner) {
        winner = token.tokenId;
        count++;
      }
    }
    return count == 1 ? winner : '';
  }

  /// Resolves an outcome through the Gamma API. Returns null when no closed
  /// market is found or the Gamma lookup itself fails, so the caller can fall
  /// back to the original CLOB error. Mirrors `resolveViaGamma`.
  Future<ClobMarketOutcome?> _resolveViaGamma(
    String gammaBaseUrl,
    String conditionId,
  ) async {
    final gamma = GammaClient(
      transport: HttpTransport(config: TransportConfig(baseUrl: gammaBaseUrl)),
    );
    try {
      final markets = await gamma.markets(
        GetMarketsParams(conditionIds: <String>[conditionId]),
      );
      for (final m in markets) {
        if (!m.closed) continue;
        return ClobMarketOutcome(
          status: ClobMarketOutcomeStatus.unresolved,
          conditionId: conditionId,
          closed: true,
          source: 'gamma:closed_condition_id=$conditionId',
        );
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      gamma.close();
    }
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
    return clobDecodeObjectList(list, '/books', OrderBook.fromJson);
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
  Future<bool> negRisk(String tokenId) async {
    return (await negRiskInfo(tokenId)).negRisk;
  }

  /// Full negative-risk metadata for [tokenId].
  ///
  /// Mirrors Polygolem `NegRisk`, including market id and fee bips when the
  /// upstream includes them.
  Future<NegRiskInfo> negRiskInfo(String tokenId) async {
    final body = await _transport.getJson(
      '/neg-risk',
      query: <String, dynamic>{'token_id': tokenId},
    );
    return NegRiskInfo.fromJson(body);
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
    return _toInt(
      _first(body, 'fee_rate_bps', 'feeRateBps', 'base_fee', 'baseFee'),
    );
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

  /// Public CLOB trade history for a token/market.
  ///
  /// The CLOB route is unauthenticated and returns either a bare list or a
  /// wrapped `{ "trades": [...] }` / `{ "data": [...] }` payload depending on
  /// the upstream or paper-compatible adapter.
  Future<List<TradeRecord>> publicTrades({String market = ''}) async {
    final body = await _transport.getJsonValue(
      '/trades',
      query: market.trim().isEmpty
          ? null
          : <String, dynamic>{'market': market.trim()},
    );
    final raw = body is Map ? (body['trades'] ?? body['data']) : body;
    if (raw is! List) return const <TradeRecord>[];
    return clobDecodeObjectList(raw, '/trades', TradeRecord.fromJson);
  }

  // --- Order scoring ---

  /// Trades attributed to the configured builder code.
  ///
  /// Mirrors Polygolem `BuilderTrades`. The public route returns a wrapped
  /// `{ "trades": [...] }` payload.
  Future<List<BuilderTrade>> builderTrades({int limit = 100}) async {
    final body = await _transport.getJson(
      '/builder-trades',
      query: <String, dynamic>{'limit': limit},
    );
    final raw = body['trades'];
    if (raw is! List) return const <BuilderTrade>[];
    return clobDecodeObjectList(
      raw,
      '/builder-trades.trades',
      BuilderTrade.fromJson,
    );
  }

  /// Whether [orderId] is currently scored for rewards.
  ///
  /// Wire response: `{"scoring": bool}`.
  Future<bool> orderScoring(String orderId) async {
    final body = await _transport.getJson(
      '/orders/scoring',
      query: <String, dynamic>{'order_id': orderId},
    );
    return _toBool(body['scoring']);
  }

  /// Batch scoring lookup. Returns one boolean per id, in the order
  /// the server returns them. Wire body: `{"order_ids": [...]}`,
  /// response: `[bool, ...]`.
  Future<List<bool>> ordersScoring(List<String> orderIds) async {
    final list = await _transport.postJsonList(
      '/orders/scoring',
      <String, dynamic>{'order_ids': orderIds},
    );
    return list.map(_toBool).toList(growable: false);
  }

  // --- Rewards ---

  /// Active rewards configuration across all markets.
  Future<List<RewardsConfig>> rewardsConfig() async {
    final list = await _transport.getJsonList('/rewards/config');
    return clobDecodeObjectList(
      list,
      '/rewards/config',
      RewardsConfig.fromJson,
    );
  }

  /// One public cursor page of current active reward markets.
  Future<CurrentRewardMarketsPage> currentRewardMarkets({
    String? nextCursor,
  }) async {
    final body = await _transport.getJson(
      '/rewards/markets/current',
      query: nextCursor == null || nextCursor.isEmpty
          ? null
          : <String, dynamic>{'next_cursor': nextCursor},
    );
    return CurrentRewardMarketsPage.fromJson(body);
  }

  /// Raw rewards series for a market (`market` is the condition id).
  Future<List<RawRewards>> rawRewards(String market) async {
    final list = await _transport.getJsonList(
      '/rewards/raw',
      query: <String, dynamic>{'market': market},
    );
    return clobDecodeObjectList(list, '/rewards/raw', RawRewards.fromJson);
  }

  /// Caller-scoped earnings on [date] (YYYY-MM-DD).
  Future<List<UserEarnings>> userEarnings(String date) async {
    final list = await _transport.getJsonList(
      '/rewards/earnings',
      query: <String, dynamic>{'date': date},
    );
    return clobDecodeObjectList(
      list,
      '/rewards/earnings',
      UserEarnings.fromJson,
    );
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
    return clobDecodeObjectList(
      list,
      '/rewards/percentages',
      RewardPercentages.fromJson,
    );
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
    return clobDecodeObjectList(
      list,
      '/rewards/markets',
      UserRewardsMarket.fromJson,
    );
  }

  /// Maker rebated fees, summed across markets when the API returns
  /// rows without a `market` key.
  Future<List<RebatedFees>> rebatedFees() async {
    final list = await _transport.getJsonList('/rebates');
    return clobDecodeObjectList(list, '/rebates', RebatedFees.fromJson);
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
    final ts = nowSeconds ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final headers = await buildL1Headers(signer: signer, timestamp: ts);
    try {
      return await createApiKeyWithL1Headers(headers);
    } on TransportException {
      return deriveApiKeyWithL1Headers(headers);
    }
  }

  /// Mints a new API-key triple via `POST /auth/api-key`.
  Future<ApiKey> createApiKey({
    required WalletSigner signer,
    int? nowSeconds,
  }) async {
    final ts = nowSeconds ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final headers = await buildL1Headers(signer: signer, timestamp: ts);
    return createApiKeyWithL1Headers(headers);
  }

  /// Mints a new API-key triple with already-built ClobAuth L1 headers.
  ///
  /// This lets higher-level flows reuse the same wallet-approved ClobAuth
  /// signature across create -> derive fallback without asking the wallet to
  /// sign twice.
  Future<ApiKey> createApiKeyWithL1Headers(Map<String, String> headers) async {
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
    return deriveApiKeyWithL1Headers(headers);
  }

  /// Returns the deterministic API-key triple with already-built ClobAuth L1
  /// headers.
  Future<ApiKey> deriveApiKeyWithL1Headers(Map<String, String> headers) async {
    final body = await _transport.getJson(
      '/auth/derive-api-key',
      headers: headers,
    );
    return _parseApiKey(body);
  }

  /// Mints a CLOB builder-fee key via `POST /auth/builder-api-key`.
  ///
  /// The returned triple is the fee-attribution key — attach its [ApiKey.key]
  /// to the `builder` bytes32 field of V2 orders to claim integrator fees.
  ///
  /// Distinct from the L2 trading triple minted by [createApiKey] / [deriveApiKey].
  /// Caller must already hold an L2 [apiKey] (the request is L2-HMAC signed
  /// with it). Fully headless — no cookie, no browser.
  ///
  /// See `polygolem/docs/HEADLESS-BUILDER-KEYS-INVESTIGATION.md`.
  Future<ApiKey> createBuilderFeeKey({required ApiKey apiKey}) async {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final headers = buildL2Headers(
      apiKey: apiKey,
      timestamp: ts,
      method: 'POST',
      path: '/auth/builder-api-key',
    );
    final body = await _transport.postJson(
      '/auth/builder-api-key',
      const <String, dynamic>{},
      headers: headers,
    );
    return _parseApiKey(body);
  }

  /// Lists every builder-fee key minted for the authenticated wallet via
  /// `GET /auth/builder-api-keys`.
  Future<List<BuilderFeeKeyRecord>> listBuilderFeeKeys({
    required ApiKey apiKey,
  }) async {
    final list = await _l2GetList(
      path: '/auth/builder-api-keys',
      apiKey: apiKey,
    );
    return clobDecodeObjectList(
      list,
      '/auth/builder-api-keys',
      BuilderFeeKeyRecord.fromJson,
    );
  }

  /// Revokes a builder-fee key via `DELETE /auth/builder-api-key/{key}`.
  Future<void> revokeBuilderFeeKey({
    required ApiKey apiKey,
    required String builderKey,
  }) async {
    if (builderKey.trim().isEmpty) {
      throw const ValidationException(
        code: ErrorCode.missingField,
        message: 'builderKey is required',
        field: 'builderKey',
      );
    }
    final path = '/auth/builder-api-key/${Uri.encodeComponent(builderKey)}';
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final headers = buildL2Headers(
      apiKey: apiKey,
      timestamp: ts,
      method: 'DELETE',
      path: path,
    );
    await _transport.delete(path, headers: headers);
  }

  /// Returns every open order owned by the API-key wallet.
  ///
  /// Mirrors `internal/clob/orders.go::ListOrders`. Caller must supply a
  /// derived [ApiKey] — use [createOrDeriveApiKey] to mint one.
  Future<List<OrderRecord>> listOrders({required ApiKey apiKey}) async {
    final list = await _l2GetPages(path: '/data/orders', apiKey: apiKey);
    return clobDecodeObjectList(list, '/data/orders', OrderRecord.fromJson);
  }

  /// Returns the trade history for the API-key wallet.
  Future<List<TradeRecord>> listTrades({required ApiKey apiKey}) async {
    final list = await _l2GetPages(path: '/data/trades', apiKey: apiKey);
    return clobDecodeObjectList(list, '/data/trades', TradeRecord.fromJson);
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
      path: path,
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
      path: path,
    );
    return _transport.getJsonList(path, query: query, headers: headers);
  }

  /// The official client signs only the endpoint path, never GET query
  /// parameters or an app proxy prefix. Consume every page of private orders
  /// and trades; also accept the unwrapped arrays used by existing adapters.
  Future<List<dynamic>> _l2GetPages({
    required String path,
    required ApiKey apiKey,
  }) async {
    final results = <dynamic>[];
    final seenCursors = <String>{};
    String? cursor;
    for (var page = 0; page < 1000; page++) {
      final headers = buildL2Headers(
        apiKey: apiKey,
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        method: 'GET',
        path: path,
      );
      final body = await _transport.getJsonValue(
        path,
        query: cursor == null ? null : {'next_cursor': cursor},
        headers: headers,
      );
      if (body is List) return [...results, ...body];
      if (body is! Map || body['data'] is! List) {
        throw FormatException('$path response must contain a data list');
      }
      results.addAll(body['data'] as List);
      final next = body['next_cursor'];
      if (next == null || next == '' || next == 'LTE=') return results;
      if (next is! String || !seenCursors.add(next)) {
        throw FormatException('$path returned an invalid or repeated cursor');
      }
      cursor = next;
    }
    throw FormatException('$path pagination exceeded the page limit');
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

  bool _toBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final normalized = raw.toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  Object? _first(
    Map<String, dynamic> json,
    String a,
    String b,
    String c,
    String d,
  ) {
    for (final key in <String>[a, b, c, d]) {
      if (json.containsKey(key)) return json[key];
    }
    return null;
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

    // /auth/api-key returns "apiKey"/"api_key"; /auth/builder-api-key
    // returns the bare "key" field. Accept all variants.
    final key = pick(<String>['apiKey', 'api_key', 'key']);
    final secret = pick(<String>['secret']);
    final passphrase = pick(<String>[
      'passphrase',
      'passPhrase',
      'pass_phrase',
    ]);
    final apiKey = ApiKey(key: key, secret: secret, passphrase: passphrase);
    apiKey.validate();
    return apiKey;
  }
}
