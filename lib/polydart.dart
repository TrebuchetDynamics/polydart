/// Polydart — Dart-native Polymarket SDK.
///
/// Peer implementation to polygolem (Go). See `docs/PRD.md` and
/// `docs/PLAN.md`.
library;

export 'src/auth/clob_auth.dart'
    show
        buildClobAuthTypedData,
        buildL1Headers,
        clobAuthDefaultMessage,
        clobAuthDomainName,
        clobAuthDomainVersion,
        hashClobAuth;
export 'src/auth/create2.dart'
    show
        PolymarketAddresses,
        deriveDepositWallet,
        deriveProxyWallet,
        deriveSafeWallet,
        makerAddressForSignatureType,
        predictCreate2Address;
export 'src/auth/eip712.dart'
    show
        Eip712Domain,
        Eip712Field,
        eip712DomainSeparator,
        eip712HashStruct,
        eip712TypeHash,
        hashTypedData;
export 'src/auth/erc7739.dart'
    show
        assemblePoly1271WrappedSignature,
        buildPoly1271TypedDataEnvelope,
        computePoly1271FinalHash,
        poly1271DigestFromEnvelope,
        poly1271StructHash,
        poly1271TypedDataSignTypeHash,
        polyDepositWalletDomainName,
        polyDepositWalletDomainVersion,
        typedDataSignPrefix,
        wrapPoly1271Signature;
export 'src/auth/l2.dart'
    show
        ApiKey,
        BuilderConfig,
        buildBuilderHeaders,
        buildL2Headers,
        compactJson,
        signHmac;
export 'src/auth/eth_hex.dart'
    show
        bytesToHex,
        bytesToHex0x,
        concatBytes,
        hexToBytes,
        keccak256Bytes,
        keccak256Utf8,
        leftPadBytes,
        normalizeAddress,
        uint256BigEndian;
export 'src/auth/siwe.dart'
    show
        SIWEMessage,
        buildPolymarketSIWE,
        buildSIWEBearerToken,
        polymarketSIWEDomain,
        polymarketSIWEStatement,
        polymarketSIWEURI,
        siweVersion,
        toEIP55Checksum;
export 'src/auth/siwe_login.dart' show SIWESession;
export 'src/auth/wallet_signer.dart' show WalletSigner;
export 'src/bookreader/bookreader.dart' show BookReader;
export 'src/bridge/bridge_client.dart'
    show
        BridgeClient,
        CreateDepositAddressResponse,
        DepositAddress,
        DepositStatusResponse,
        DepositTransaction,
        FeeBreakdown,
        QuoteRequest,
        QuoteResponse,
        SupportedAsset,
        SupportedAssetsResponse,
        TokenInfo,
        defaultBridgeBaseUrl;
export 'src/builder/builder.dart'
    show
        BuilderSigner,
        LocalBuilderSigner,
        LocalBuilderSignerConfig,
        RemoteBuilderSigner,
        RemoteBuilderSignerConfig,
        RemoteBuilderSignerException,
        genSignature,
        polyBuilderApiKeyHeader,
        polyBuilderPassphraseHeader,
        polyBuilderSignatureHeader,
        polyBuilderTimestampHeader;
export 'src/clob/clob_analytics_types.dart'
    show
        RawRewards,
        RebatedFees,
        RewardPercentages,
        RewardsConfig,
        TotalEarnings,
        UserEarnings,
        UserRewardsByMarketRequest,
        UserRewardsMarket;
export 'src/clob/clob_auth_types.dart'
    show
        BalanceAllowanceParams,
        BalanceAllowanceResponse,
        BuilderFeeKeyRecord,
        OrderRecord,
        TradeRecord;
export 'src/clob/clob_client.dart' show ClobClient;
export 'src/clob/clob_params.dart' show BookParams, PriceHistoryParams;
export 'src/clob/clob_writes.dart'
    show
        BatchOrderResponse,
        CancelResponse,
        ClobWrites,
        CreateOrderRequest,
        maxCancelBatchSize,
        maxBatchPostSize;
export 'src/contracts/contracts.dart'
    show
        CTF,
        CTFExchangeV2,
        CollateralOfframp,
        CollateralOnramp,
        CtfCollateralAdapter,
        DepositWalletFactory,
        DeploymentStatus,
        GnosisSafeFactory,
        NegRiskAdapterV2,
        NegRiskCtfCollateralAdapter,
        NegRiskExchangeV2,
        PUSD,
        PermissionedRamp,
        PolygonChainID,
        PolygonRPC,
        ProxyFactory,
        Registry,
        USDCE,
        contractDeployed,
        depositWalletDeployed,
        polygonMainnet,
        redeemAdapterFor;
export 'src/ctf/ctf.dart'
    show
        collectionId,
        conditionalTokensAddress,
        mergePositionsData,
        negRiskAdapterAddress,
        positionId,
        redeemPositionsData,
        splitPositionData,
        usdcAddress;
export 'src/dataapi/dataapi_client.dart' show DataApiClient;
export 'src/dataapi/dataapi_types.dart'
    show
        Activity,
        ClosedPosition,
        LiveVolumeEntry,
        LiveVolumeMarket,
        LiveVolumeResponse,
        MetaHolder,
        OpenInterest,
        Position,
        TotalMarketsTraded,
        TotalValue,
        Trade,
        TraderLeaderboardEntry;
export 'src/credentials/live_credentials.dart'
    show
        CredentialKey,
        CredentialReadiness,
        CredentialStore,
        LiveCredentialAction,
        LiveCredentialReadiness,
        LiveCredentialService,
        LiveCredentialStatus,
        MemoryCredentialStore,
        WalletSignatureRejectedException;
export 'src/enabletrading/enable_trading.dart'
    show
        buildEnableTradingApprovalBatchTypedData,
        buildEnableTradingApprovalCalls,
        buildEnableTradingClobAuthTypedData,
        clobAuthControlMessage,
        polygonChainId,
        signEnableTradingApprovalBatchTypedData,
        signEnableTradingClobAuthTypedData,
        validateEnableTradingApprovalCalls;
export 'src/config/config.dart';
export 'src/errors/errors.dart';
export 'src/funding/funding.dart'
    show
        EoaPusdTransferPlan,
        PusdFundingRoutePlan,
        PusdFundingRouteStatus,
        PusdTransferCallPlan,
        buildEoaPusdTransferPlan,
        planEoaPusdFundingRoute,
        buildPusdTransferBatchTypedData,
        buildPusdTransferCall,
        buildPusdTransferCallPlan,
        pusdTransferSelector;
export 'src/gamma/gamma_client.dart'
    show
        GammaClient,
        KeysetPage,
        deduplicateEventsBySlugOrId,
        deduplicateMarketsByConditionId,
        deduplicateSeriesBySlugOrId,
        deduplicateTagsBySlugOrId,
        filterEventsByCategory,
        filterMarketsByCategory,
        marketMatchesCategory;
export 'src/gamma/gamma_params.dart'
    show
        CommentQuery,
        GetEventsParams,
        GetMarketsParams,
        GetSeriesParams,
        GetTagsParams,
        GetTeamsParams,
        KeysetParams,
        SearchParams;
export 'src/gamma/gamma_profile.dart'
    show
        CreateProfileRequest,
        CreateProfileResponse,
        CreateProfileUser,
        GammaProfileException,
        createProfile,
        defaultAppNotificationPreferences,
        defaultEmailNotificationPreferences,
        defaultPreferencesBlock,
        defaultWalletPreferencesBlock,
        newCreateProfileRequest;
export 'src/logging/logger.dart';
export 'src/marketdiscovery/market_discovery.dart'
    show EnrichedMarket, MarketDiscovery;
export 'src/marketdata/marketdata_tracker.dart'
    show Level, MarketDataTracker, Snapshot;
export 'src/marketresolver/market_resolver.dart'
    show MarketResolver, ResolvedMarket, parseClobTokenIds;
export 'src/modes/modes.dart';
export 'src/orders/amounts.dart'
    show
        OrderAmounts,
        buildSalt,
        computeAmounts,
        defaultExpiration,
        generateOrderSalt,
        roundToTick,
        usdcDecimals,
        validatePriceAgainstTick;
export 'src/orders/order_builder.dart' show OrderBuilder;
export 'src/orders/deposit_wallet_order_signing.dart'
    show signDepositWalletOrderV2;
export 'src/orders/order_placement.dart'
    show
        CreateDepositWalletLimitOrderParams,
        CreateDepositWalletMarketOrderParams,
        CreateLimitOrderParams,
        CreateMarketOrderParams,
        createDepositWalletLimitOrder,
        createDepositWalletLimitOrders,
        createDepositWalletMarketOrder,
        createLimitOrder,
        createMarketOrder;
export 'src/orders/order_signing.dart'
    show
        OrderV2Draft,
        bytes32Zero,
        buildOrderV2TypedData,
        clobExchangeAddressV2,
        hashOrderV2,
        negRiskExchangeAddressV2,
        orderV2ContentsType,
        orderV2DomainSeparator,
        orderV2Fields,
        orderV2StructHash,
        polymarketChainId,
        polymarketCtfV2DomainName,
        polymarketCtfV2DomainVersion,
        signOrderV2;
export 'src/orders/order_intent.dart'
    show LifecycleState, OrderIntent, OrderResponse, SignedOrder;
export 'src/orderfills/orderfills.dart'
    show
        OrderFill,
        OrderFillsBlockNumberReader,
        OrderFillsMarket,
        OrderFillsQuery,
        OrderFillsReader,
        RpcOrderFillsReader,
        normalizeOrderFill,
        orderFillSideBuy,
        orderFillSideSell,
        orderFillSourceOnchainOrderFilled,
        validateOrderFill,
        validateOrderFillsQuery;
export 'src/orderresults/orderresults.dart'
    show
        ClobOrderResultsReader,
        DataApiOrderResultsReader,
        OrderResultsClobReader,
        OrderResultsDataReader,
        OrderResultsOptions,
        OrderResultsOrderSummary,
        OrderResultsReport,
        OrderResultsRow,
        OrderResultsSummary,
        OrderResultsTradeSummary,
        buildReport,
        orderResultSourceClob,
        orderResultSourceData,
        orderResultStatusClosed,
        orderResultStatusLost,
        orderResultStatusOpen,
        orderResultStatusUnknown,
        orderResultStatusWon;
export 'src/paper/paper.dart'
    show PaperFill, PaperOrder, PaperPosition, PaperState;
export 'src/pagination/pagination.dart'
    show
        CursorPage,
        CursorPager,
        ItemResult,
        OffsetPage,
        OffsetPageResult,
        OffsetPager,
        Page,
        StreamResult,
        batch,
        collectAll,
        collectOffset,
        streamItems,
        streamPages;
export 'src/plugins/plugins.dart'
    show MarketDataPlugin, PluginOrder, RiskPlugin;
export 'src/preflight/preflight.dart'
    show
        PreflightCheck,
        PreflightCheckResult,
        PreflightResult,
        Probe,
        runPreflight;
export 'src/risk/breaker.dart'
    show
        Breaker,
        Policy,
        RiskStatus,
        TripReason,
        defaultPolicy,
        tripReasonFromString;
export 'src/rpc/rpc.dart'
    show erc20Allowance, hasCode, isApprovedForAll, polygonRpc;
export 'src/settlement/settlement.dart'
    show
        DataApiSettlementReader,
        RedeemResult,
        RedeemablePosition,
        SettlementAdapterApproval,
        SettlementDataReader,
        SettlementReadiness,
        buildRedeemCall,
        checkReadiness,
        chunkRedeemPositionsByCondition,
        dedupeRedeemPositionsByCondition,
        defaultBatchLimit,
        findRedeemable,
        requiredSettlementAdapters,
        settlementStatusDataApiUnavailable,
        settlementStatusDepositWalletNotDeployed,
        settlementStatusMissingAdapterApproval,
        settlementStatusMissingRelayerCredentials,
        settlementStatusReady,
        settlementStatusRpcError;
export 'src/transport/circuit_breaker.dart'
    show CircuitBreaker, CircuitBreakerConfig, CircuitState;
export 'src/transport/http_transport.dart' show HttpTransport;
export 'src/transport/rate_limit.dart' show RateLimiter;
export 'src/transport/redact.dart';
export 'src/transport/transport_config.dart' show TransportConfig;
export 'src/types/types.dart';
export 'src/wallet/deposit_wallet_signing.dart'
    show
        WalletBatchCall,
        buildWalletBatchTypedData,
        defaultBatchDeadline,
        depositWalletDomainName,
        depositWalletDomainVersion,
        hashWalletBatchCall,
        hashWalletBatchStruct,
        hashWalletBatchTypedData,
        signWalletBatch,
        walletBatchCallTypeHash,
        walletBatchCallTypeString,
        walletBatchTypeHash,
        walletBatchTypeString;
export 'src/wallet/deposit_wallet_readiness.dart'
    show
        DepositWalletApprovalCheck,
        DepositWalletApprovalKind,
        DepositWalletFundingConfirmation,
        DepositWalletFundingConfirmationStatus,
        DepositWalletReadiness,
        DepositWalletReadinessService,
        DepositWalletReadinessStatus,
        waitForDepositWalletFundingReadiness;
export 'src/stream/dedup.dart' show Deduplicator, splitArray;
export 'src/stream/market_client.dart'
    show MarketClient, WebSocketChannelFactory;
export 'src/stream/stream_config.dart' show StreamConfig, defaultStreamUrl;
export 'src/stream/stream_messages.dart'
    show
        BestBidAskMessage,
        BookMessage,
        LastTradeMessage,
        MarketResolvedMessage,
        NewMarketMessage,
        PriceChangeEntry,
        PriceChangeMessage,
        PriceLevel,
        TickSizeChangeMessage;
export 'src/telemetry/telemetry.dart'
    show RedactableValue, TelemetryLogger, redactTelemetryValue;
export 'src/relayer/relayer_client.dart'
    show RelayerClient, defaultRelayerBaseUrl, depositWalletFactoryAddr;
export 'src/relayer/relayer_errors.dart'
    show
        RelayerAllowlistBlockedException,
        classifyRelayerAllowlistError,
        relayerAllowlistBlockedCode;
export 'src/relayer/v2_auth.dart'
    show V2APIKey, defaultRelayerV2BaseUrl, mintV2APIKey;
export 'src/relayer/relayer_types.dart'
    show
        DeployedResponse,
        DepositWalletCall,
        NonceResponse,
        RelayerError,
        RelayerTransaction,
        RelayerTransactionState;
export 'src/relayer/approvals.dart'
    show
        buildApprovalCalls,
        ctfAddress,
        ctfExchangeV2,
        negRiskAdapterV2,
        negRiskExchangeV2,
        pusdAddress;
export 'src/universal/universal_client.dart'
    show
        UniversalClient,
        UniversalClobReadClient,
        UniversalConfig,
        UniversalHealthException,
        UniversalHealthSummary;

import 'src/clob/clob_client.dart';
import 'src/config/config.dart';
import 'src/dataapi/dataapi_client.dart';
import 'src/errors/errors.dart';
import 'src/gamma/gamma_client.dart';
import 'src/marketdiscovery/market_discovery.dart';
import 'src/marketresolver/market_resolver.dart';
import 'src/modes/modes.dart';
import 'src/transport/http_transport.dart';
import 'src/transport/transport_config.dart';

const String polydartVersion = '0.1.0-alpha.2';

/// Top-level polydart client.
///
/// Owns one HTTP transport per upstream (Gamma + CLOB + Data API) and shares those
/// transports across every sub-client. Closing the top-level client is
/// the only correct way to release resources.
///
/// Three factories are available today:
///
///   * [Polydart.readOnly] — no wallet, no auth, no live writes.
///   * [Polydart.paper] — read-only protocol surface plus a paper-mode
///     marker so risk gates can permit simulated submissions. Wallet
///     wiring remains application-owned.
///
/// Live write paths are exposed through lower-level clients and remain blocked
/// unless the caller uses [PolydartMode.live] with explicit live-trading gates.
final class Polydart {
  Polydart._({
    required this.config,
    required this.eoaAddress,
    required this.gamma,
    required this.clob,
    required this.data,
    required this.resolver,
    required this.discovery,
  });

  /// Constructs a polydart client for [PolydartMode.readOnly].
  ///
  /// Pass [config] to override base URLs / timeouts (typically wired from
  /// [PolydartConfig.fromEnv]). Pass [gammaTransport] / [clobTransport] /
  /// [dataTransport]
  /// to inject a custom [HttpTransport] (for example one with a shared
  /// rate limiter or circuit breaker).
  factory Polydart.readOnly({
    PolydartConfig? config,
    HttpTransport? gammaTransport,
    HttpTransport? clobTransport,
    HttpTransport? dataTransport,
  }) {
    final cfg = (config ?? const PolydartConfig()).copyWith(
      mode: PolydartMode.readOnly,
    );
    return _build(
      cfg,
      gammaTransport,
      clobTransport,
      dataTransport,
      eoaAddress: '',
    );
  }

  /// Constructs a polydart client for [PolydartMode.paper].
  ///
  /// [eoaAddress] is required so future paper-mode flows can derive the
  /// deposit-wallet address that will own simulated balances. The address
  /// is not used by Phase 1 surfaces — it's stored for forward
  /// compatibility.
  factory Polydart.paper({
    required String eoaAddress,
    PolydartConfig? config,
    HttpTransport? gammaTransport,
    HttpTransport? clobTransport,
    HttpTransport? dataTransport,
  }) {
    if (eoaAddress.trim().isEmpty) {
      throw const ValidationException(
        code: ErrorCode.missingField,
        message: 'eoaAddress is required for Polydart.paper',
        field: 'eoaAddress',
      );
    }
    final cfg = (config ?? const PolydartConfig()).copyWith(
      mode: PolydartMode.paper,
    );
    return _build(
      cfg,
      gammaTransport,
      clobTransport,
      dataTransport,
      eoaAddress: eoaAddress,
    );
  }

  /// SDK configuration captured at construction time.
  final PolydartConfig config;

  /// Active operating mode. Sugar for `config.mode`.
  PolydartMode get mode => config.mode;

  /// EOA address provided to [Polydart.paper]. Empty for read-only mode.
  final String eoaAddress;

  /// Gamma API surface — search, markets, events, …
  final GammaClient gamma;

  /// CLOB API surface — book, price, midpoint, spread, …
  final ClobClient clob;

  /// Data API surface — positions, activity, holders, analytics, …
  final DataApiClient data;

  /// Slug ↔ id ↔ token resolver layered on top of [gamma].
  final MarketResolver resolver;

  /// Composed Gamma + CLOB enrichment.
  final MarketDiscovery discovery;

  /// Closes both shared transports. Idempotent.
  void close() {
    gamma.close();
    clob.close();
    data.close();
  }

  static Polydart _build(
    PolydartConfig cfg,
    HttpTransport? gammaTransport,
    HttpTransport? clobTransport,
    HttpTransport? dataTransport, {
    required String eoaAddress,
  }) {
    final gt =
        gammaTransport ??
        HttpTransport(
          config: TransportConfig(
            baseUrl: cfg.gammaBaseUrl,
            timeout: cfg.requestTimeout,
          ),
        );
    final ct =
        clobTransport ??
        HttpTransport(
          config: TransportConfig(
            baseUrl: cfg.clobBaseUrl,
            timeout: cfg.requestTimeout,
          ),
        );
    final dt =
        dataTransport ??
        HttpTransport(
          config: TransportConfig(
            baseUrl: cfg.dataBaseUrl,
            timeout: cfg.requestTimeout,
          ),
        );
    final gamma = GammaClient(transport: gt);
    final clob = ClobClient(
      transport: ct,
      mode: cfg.mode,
      liveTradingEnabled: cfg.liveTradingEnabled,
    );
    final data = DataApiClient(transport: dt);
    return Polydart._(
      config: cfg,
      eoaAddress: eoaAddress,
      gamma: gamma,
      clob: clob,
      data: data,
      resolver: MarketResolver(gamma: gamma),
      discovery: MarketDiscovery(gamma: gamma, clob: clob),
    );
  }
}
