/// Read-oriented convenience facade across Polymarket public data surfaces.
library;

import '../clob/clob_analytics_types.dart';
import '../clob/clob_auth_types.dart';
import '../clob/clob_client.dart';
import '../clob/clob_params.dart';
import '../dataapi/dataapi_client.dart';
import '../dataapi/dataapi_types.dart';
import '../gamma/gamma_client.dart';
import '../gamma/gamma_params.dart';
import '../marketdiscovery/market_discovery.dart';
import '../stream/market_client.dart';
import '../stream/stream_config.dart';
import '../transport/http_transport.dart';
import '../transport/transport_config.dart';
import '../types/clob.dart';
import '../types/market.dart';

/// Configuration for [UniversalClient].
///
/// Base URL defaults match the existing Polydart clients. Tests and advanced
/// callers may inject already-built clients or transports; supplied clients are
/// not closed by [UniversalClient.close].
final class UniversalConfig {
  const UniversalConfig({
    this.gammaBaseUrl = GammaClient.defaultBaseUrl,
    this.clobBaseUrl = ClobClient.defaultBaseUrl,
    this.dataBaseUrl = DataApiClient.defaultBaseUrl,
    this.streamUrl = defaultStreamUrl,
    this.gammaClient,
    this.clobClient,
    this.dataClient,
    this.marketDiscovery,
    this.gammaTransport,
    this.clobTransport,
    this.dataTransport,
    this.streamConfig,
    this.streamChannelFactory,
  });

  /// Public Gamma REST API base URL.
  final String gammaBaseUrl;

  /// Public CLOB REST API base URL.
  final String clobBaseUrl;

  /// Public Data API base URL.
  final String dataBaseUrl;

  /// Public CLOB market WebSocket URL.
  final String streamUrl;

  /// Optional prebuilt Gamma client.
  final GammaClient? gammaClient;

  /// Optional prebuilt CLOB client. Only read methods are exposed.
  final ClobClient? clobClient;

  /// Optional prebuilt Data API client.
  final DataApiClient? dataClient;

  /// Optional prebuilt market discovery service.
  final MarketDiscovery? marketDiscovery;

  /// Optional Gamma transport used when [gammaClient] is not provided.
  final HttpTransport? gammaTransport;

  /// Optional CLOB transport used when [clobClient] is not provided.
  final HttpTransport? clobTransport;

  /// Optional Data API transport used when [dataClient] is not provided.
  final HttpTransport? dataTransport;

  /// Optional full stream configuration. When supplied it takes precedence
  /// over [streamUrl].
  final StreamConfig? streamConfig;

  /// Optional WebSocket factory for stream clients.
  final WebSocketChannelFactory? streamChannelFactory;
}

/// Facade over Gamma, CLOB public reads, Data API, discovery, streams, and
/// health checks.
final class UniversalClient {
  UniversalClient({UniversalConfig config = const UniversalConfig()})
    : _gamma =
          config.gammaClient ??
          GammaClient(
            transport:
                config.gammaTransport ??
                HttpTransport(
                  config: TransportConfig(baseUrl: config.gammaBaseUrl),
                ),
          ),
      _clob =
          config.clobClient ??
          ClobClient(
            transport:
                config.clobTransport ??
                HttpTransport(
                  config: TransportConfig(baseUrl: config.clobBaseUrl),
                ),
          ),
      _data =
          config.dataClient ??
          DataApiClient(
            transport:
                config.dataTransport ??
                HttpTransport(
                  config: TransportConfig(baseUrl: config.dataBaseUrl),
                ),
          ),
      _streamConfig =
          config.streamConfig ?? StreamConfig.defaults(url: config.streamUrl),
      _streamChannelFactory = config.streamChannelFactory,
      _ownsGamma = config.gammaClient == null,
      _ownsClob = config.clobClient == null,
      _ownsData = config.dataClient == null {
    clob = UniversalClobReadClient._(_clob);
    _discovery =
        config.marketDiscovery ?? MarketDiscovery(gamma: _gamma, clob: _clob);
  }

  final GammaClient _gamma;
  final ClobClient _clob;
  final DataApiClient _data;
  late final MarketDiscovery _discovery;
  final StreamConfig _streamConfig;
  final WebSocketChannelFactory? _streamChannelFactory;
  final bool _ownsGamma;
  final bool _ownsClob;
  final bool _ownsData;

  /// Read-only CLOB view.
  late final UniversalClobReadClient clob;

  /// Underlying Gamma client. Gamma is read-only in Polydart.
  GammaClient get gamma => _gamma;

  /// Underlying Data API client.
  DataApiClient get data => _data;

  /// Market discovery service composed from Gamma and CLOB reads.
  MarketDiscovery get discovery => _discovery;

  /// Stream configuration used by [streamClient].
  StreamConfig get streamConfig => _streamConfig;

  /// Closes clients constructed by this facade.
  void close() {
    if (_ownsGamma) _gamma.close();
    if (_ownsClob) _clob.close();
    if (_ownsData) _data.close();
  }

  /// Creates a CLOB market WebSocket client.
  MarketClient streamClient({
    StreamConfig? config,
    WebSocketChannelFactory? channelFactory,
  }) {
    return MarketClient(
      config: config ?? _streamConfig,
      channelFactory: channelFactory ?? _streamChannelFactory,
    );
  }

  /// Creates a CLOB market WebSocket client with an explicit config.
  MarketClient streamClientWithConfig(
    StreamConfig config, {
    WebSocketChannelFactory? channelFactory,
  }) {
    return streamClient(config: config, channelFactory: channelFactory);
  }

  /// Pings Gamma, CLOB, and Data API and returns per-service reachability.
  ///
  /// Partial outages are represented in the returned summary. A
  /// [UniversalHealthException] is thrown only when every HTTP API fails.
  Future<UniversalHealthSummary> healthCheck() async {
    final errors = <String, Object>{};
    var gammaOk = false;
    var clobOk = false;
    var dataOk = false;

    try {
      await _gamma.health();
      gammaOk = true;
    } on Object catch (e) {
      errors['gamma'] = e;
    }

    try {
      await _clob.health();
      clobOk = true;
    } on Object catch (e) {
      errors['clob'] = e;
    }

    try {
      await _data.health();
      dataOk = true;
    } on Object catch (e) {
      errors['data'] = e;
    }

    final summary = UniversalHealthSummary(
      gammaOk: gammaOk,
      clobOk: clobOk,
      dataOk: dataOk,
      errors: errors,
    );
    if (!summary.anyOk) throw UniversalHealthException(summary);
    return summary;
  }

  // Gamma

  Future<List<Market>> activeMarkets() => _gamma.activeMarkets();

  Future<List<Market>> markets([
    GetMarketsParams params = const GetMarketsParams(),
  ]) {
    return _gamma.markets(params);
  }

  Future<Market?> marketById(String id) => _gamma.marketById(id);

  Future<Market?> marketBySlug(String slug) => _gamma.marketBySlug(slug);

  Future<List<Event>> events([
    GetEventsParams params = const GetEventsParams(),
  ]) {
    return _gamma.events(params);
  }

  Future<Event?> eventById(String id) => _gamma.eventById(id);

  Future<Event?> eventBySlug(String slug) => _gamma.eventBySlug(slug);

  Future<SearchResponse> search(SearchParams params) => _gamma.search(params);

  Future<List<Series>> series([
    GetSeriesParams params = const GetSeriesParams(),
  ]) {
    return _gamma.series(params);
  }

  Future<Series?> seriesById(String id) => _gamma.seriesById(id);

  Future<List<Tag>> tags([GetTagsParams params = const GetTagsParams()]) {
    return _gamma.tags(params);
  }

  Future<Tag?> tagById(String id) => _gamma.tagById(id);

  Future<Tag?> tagBySlug(String slug) => _gamma.tagBySlug(slug);

  Future<List<TagRelationship>> relatedTagsById(String tagId) {
    return _gamma.relatedTagsById(tagId);
  }

  Future<List<TagRelationship>> relatedTagsBySlug(String slug) {
    return _gamma.relatedTagsBySlug(slug);
  }

  Future<List<Team>> teams([GetTeamsParams params = const GetTeamsParams()]) {
    return _gamma.teams(params);
  }

  Future<List<Comment>> comments(CommentQuery query) => _gamma.comments(query);

  Future<Comment?> commentById(String id) => _gamma.commentById(id);

  Future<List<Comment>> commentsByUser(String userAddress, {int limit = 0}) {
    return _gamma.commentsByUser(userAddress, limit: limit);
  }

  Future<List<SportMetadata>> sportsMetadata() => _gamma.sportsMetadata();

  Future<List<SportsMarketType>> sportsMarketTypes() {
    return _gamma.sportsMarketTypes();
  }

  Future<MarketByTokenResponse?> marketByToken(String tokenId) {
    return _gamma.marketByToken(tokenId);
  }

  Future<Profile?> publicProfile(String walletAddress) {
    return _gamma.publicProfile(walletAddress);
  }

  Future<KeysetPage<Event>> eventsKeyset(KeysetParams params) {
    return _gamma.eventsKeyset(params);
  }

  Future<KeysetPage<Market>> marketsKeyset(KeysetParams params) {
    return _gamma.marketsKeyset(params);
  }

  // CLOB public reads

  Future<ServerTime> clobServerTime() => clob.serverTime();

  Future<ClobPaginatedMarkets> clobMarkets({String? nextCursor}) {
    return clob.markets(nextCursor: nextCursor);
  }

  Future<ClobMarket> clobMarket(String conditionId) {
    return clob.market(conditionId);
  }

  Future<ClobMarketByTokenResponse> clobMarketByToken(String tokenId) {
    return clob.marketByToken(tokenId);
  }

  Future<OrderBook> orderBook(String tokenId) => clob.orderBook(tokenId);

  Future<List<OrderBook>> orderBooks(List<BookParams> params) {
    return clob.orderBooks(params);
  }

  Future<String> price(String tokenId, String side) {
    return clob.price(tokenId, side);
  }

  Future<Map<String, String>> prices(List<BookParams> params) {
    return clob.prices(params);
  }

  Future<String> midpoint(String tokenId) => clob.midpoint(tokenId);

  Future<Map<String, String>> midpoints(List<BookParams> params) {
    return clob.midpoints(params);
  }

  Future<String> spread(String tokenId) => clob.spread(tokenId);

  Future<TickSize> tickSize(String tokenId) => clob.tickSize(tokenId);

  Future<bool> negRisk(String tokenId) => clob.negRisk(tokenId);

  Future<NegRiskInfo> negRiskInfo(String tokenId) => clob.negRiskInfo(tokenId);

  Future<int> feeRateBps(String tokenId) => clob.feeRateBps(tokenId);

  Future<String> lastTradePrice(String tokenId) {
    return clob.lastTradePrice(tokenId);
  }

  Future<Map<String, String>> lastTradesPrices(List<BookParams> params) {
    return clob.lastTradesPrices(params);
  }

  Future<List<TradeRecord>> publicTrades({String market = ''}) {
    return clob.publicTrades(market: market);
  }

  Future<PriceHistory> pricesHistory(PriceHistoryParams params) {
    return clob.pricesHistory(params);
  }

  Future<bool> orderScoring(String orderId) => clob.orderScoring(orderId);

  Future<List<bool>> ordersScoring(List<String> orderIds) {
    return clob.ordersScoring(orderIds);
  }

  Future<List<BuilderTrade>> builderTrades({int limit = 100}) {
    return clob.builderTrades(limit: limit);
  }

  Future<List<RewardsConfig>> rewardsConfig() => clob.rewardsConfig();

  Future<List<RawRewards>> rawRewards(String market) => clob.rawRewards(market);

  Future<List<UserEarnings>> userEarnings(String date) {
    return clob.userEarnings(date);
  }

  Future<TotalEarnings> totalEarnings(String date) {
    return clob.totalEarnings(date);
  }

  Future<List<RewardPercentages>> rewardPercentages() {
    return clob.rewardPercentages();
  }

  Future<List<UserRewardsMarket>> userRewardsByMarket([
    UserRewardsByMarketRequest? params,
  ]) {
    return clob.userRewardsByMarket(params);
  }

  Future<List<RebatedFees>> rebatedFees() => clob.rebatedFees();

  Future<ClobPaginatedMarkets> simplifiedMarkets({String? nextCursor}) {
    return clob.simplifiedMarkets(nextCursor: nextCursor);
  }

  Future<ClobPaginatedMarkets> samplingMarkets({String? nextCursor}) {
    return clob.samplingMarkets(nextCursor: nextCursor);
  }

  Future<ClobPaginatedMarkets> samplingSimplifiedMarkets({String? nextCursor}) {
    return clob.samplingSimplifiedMarkets(nextCursor: nextCursor);
  }

  // Data API

  Future<List<Position>> currentPositions(String user, {int limit = 0}) {
    return _data.currentPositions(user, limit: limit);
  }

  Future<List<ClosedPosition>> closedPositions(String user, {int limit = 0}) {
    return _data.closedPositions(user, limit: limit);
  }

  Future<List<Trade>> trades(String user, {int limit = 0}) {
    return _data.trades(user, limit: limit);
  }

  Future<List<Trade>> marketTrades(String market, {int limit = 0}) {
    return _data.marketTrades(market, limit: limit);
  }

  Future<List<Activity>> activity(String user, {int limit = 0}) {
    return _data.activity(user, limit: limit);
  }

  Future<List<MetaHolder>> topHolders(String market, {int limit = 0}) {
    return _data.topHolders(market, limit: limit);
  }

  Future<TotalValue> totalValue(String user) => _data.totalValue(user);

  Future<TotalMarketsTraded> marketsTraded(String user) {
    return _data.marketsTraded(user);
  }

  Future<OpenInterest> openInterest(String market) {
    return _data.openInterest(market);
  }

  Future<List<TraderLeaderboardEntry>> traderLeaderboard({int limit = 0}) {
    return _data.traderLeaderboard(limit: limit);
  }

  Future<LiveVolumeResponse> liveVolume(int eventId) {
    return _data.liveVolume(eventId);
  }

  // Market discovery

  Future<EnrichedMarket> enrichMarket(Market market) {
    return _discovery.enrichMarket(market);
  }

  Future<List<EnrichedMarket>> enrichedMarkets({int limit = 50}) {
    return _discovery.enrichedMarkets(limit: limit);
  }

  Future<List<EnrichedMarket>> searchAndEnrich(String query, {int limit = 5}) {
    return _discovery.searchAndEnrich(query, limit: limit);
  }
}

/// Read-only view over [ClobClient].
final class UniversalClobReadClient {
  UniversalClobReadClient._(this._clob);

  final ClobClient _clob;

  Future<ServerTime> serverTime() => _clob.serverTime();

  Future<ClobPaginatedMarkets> markets({String? nextCursor}) {
    return _clob.markets(nextCursor: nextCursor);
  }

  Future<ClobMarket> market(String conditionId) => _clob.market(conditionId);

  Future<ClobMarketByTokenResponse> marketByToken(String tokenId) {
    return _clob.marketByToken(tokenId);
  }

  Future<OrderBook> orderBook(String tokenId) => _clob.orderBook(tokenId);

  Future<List<OrderBook>> orderBooks(List<BookParams> params) {
    return _clob.orderBooks(params);
  }

  Future<String> price(String tokenId, String side) {
    return _clob.price(tokenId, side);
  }

  Future<Map<String, String>> prices(List<BookParams> params) {
    return _clob.prices(params);
  }

  Future<String> midpoint(String tokenId) => _clob.midpoint(tokenId);

  Future<Map<String, String>> midpoints(List<BookParams> params) {
    return _clob.midpoints(params);
  }

  Future<String> spread(String tokenId) => _clob.spread(tokenId);

  Future<String> lastTradePrice(String tokenId) {
    return _clob.lastTradePrice(tokenId);
  }

  Future<TickSize> tickSize(String tokenId) => _clob.tickSize(tokenId);

  Future<PriceHistory> pricesHistory(PriceHistoryParams params) {
    return _clob.pricesHistory(params);
  }

  Future<bool> negRisk(String tokenId) => _clob.negRisk(tokenId);

  Future<NegRiskInfo> negRiskInfo(String tokenId) {
    return _clob.negRiskInfo(tokenId);
  }

  Future<int> feeRateBps(String tokenId) => _clob.feeRateBps(tokenId);

  Future<ClobPaginatedMarkets> simplifiedMarkets({String? nextCursor}) {
    return _clob.simplifiedMarkets(nextCursor: nextCursor);
  }

  Future<ClobPaginatedMarkets> samplingMarkets({String? nextCursor}) {
    return _clob.samplingMarkets(nextCursor: nextCursor);
  }

  Future<ClobPaginatedMarkets> samplingSimplifiedMarkets({String? nextCursor}) {
    return _clob.samplingSimplifiedMarkets(nextCursor: nextCursor);
  }

  Future<Map<String, String>> lastTradesPrices(List<BookParams> params) {
    return _clob.lastTradesPrices(params);
  }

  Future<List<TradeRecord>> publicTrades({String market = ''}) {
    return _clob.publicTrades(market: market);
  }

  Future<bool> orderScoring(String orderId) => _clob.orderScoring(orderId);

  Future<List<bool>> ordersScoring(List<String> orderIds) {
    return _clob.ordersScoring(orderIds);
  }

  Future<List<BuilderTrade>> builderTrades({int limit = 100}) {
    return _clob.builderTrades(limit: limit);
  }

  Future<List<RewardsConfig>> rewardsConfig() => _clob.rewardsConfig();

  Future<List<RawRewards>> rawRewards(String market) {
    return _clob.rawRewards(market);
  }

  Future<List<UserEarnings>> userEarnings(String date) {
    return _clob.userEarnings(date);
  }

  Future<TotalEarnings> totalEarnings(String date) {
    return _clob.totalEarnings(date);
  }

  Future<List<RewardPercentages>> rewardPercentages() {
    return _clob.rewardPercentages();
  }

  Future<List<UserRewardsMarket>> userRewardsByMarket([
    UserRewardsByMarketRequest? params,
  ]) {
    return _clob.userRewardsByMarket(params);
  }

  Future<List<RebatedFees>> rebatedFees() => _clob.rebatedFees();
}

/// Reachability for every HTTP API used by [UniversalClient].
final class UniversalHealthSummary {
  UniversalHealthSummary({
    required this.gammaOk,
    required this.clobOk,
    required this.dataOk,
    Map<String, Object> errors = const <String, Object>{},
  }) : errors = Map.unmodifiable(errors);

  final bool gammaOk;
  final bool clobOk;
  final bool dataOk;
  final Map<String, Object> errors;

  bool get allOk => gammaOk && clobOk && dataOk;

  bool get anyOk => gammaOk || clobOk || dataOk;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'gamma_ok': gammaOk,
    'clob_ok': clobOk,
    'data_ok': dataOk,
    'errors': errors.map((key, value) => MapEntry(key, value.toString())),
  };
}

/// Thrown by [UniversalClient.healthCheck] when no HTTP API is reachable.
final class UniversalHealthException implements Exception {
  const UniversalHealthException(this.summary);

  final UniversalHealthSummary summary;

  @override
  String toString() => 'UniversalHealthException: all HTTP APIs unreachable';
}
