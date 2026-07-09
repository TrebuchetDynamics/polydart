# Changelog

All notable changes documented here. Follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Added current Polygolem read-only order simulation parity via
  `simulateMarketOrderBook`, including fill levels, average price, slippage,
  and unfilled amount without signing or submitting.
- Added current Polygolem parity for curated polymarket.com category feeds:
  `polymarketCategories`, `polymarketCategoryBySlug`, and
  `GammaClient.categoryEvents` call Gamma `/events/keyset` with curated
  `tag_slug` mappings.
- Added `previewDepositWalletMarketOrder`, a non-posting POLY_1271 market-order
  signing preview that hides the signature while exposing the expected
  `DepositWallet` `TypedDataSign` / `signatureType=3` context.
- Added Polygolem Wallet Intelligence V1 parity: read-only wallet dossier DTOs,
  shrinkage scoring helpers, Data API-backed dossier/leaderboard/alert/market
  flow service, `Polydart.intel`, `UniversalClient` convenience methods, and a
  local/mock E2E regression.

### Changed

- Typed additional Polygolem Gamma metadata fields: `Market.marketType`,
  `Market.umaResolutionStatus`, `Market.readyTimestamp`,
  `Market.rewardsMinSize`, `Market.rewardsMaxSpread`,
  `Market.negRiskFeeBips`, `Event.subtitle`, `Event.subcategory`,
  `Event.sortBy`, `Event.isTemplate`, `Event.templateVariables`,
  `Event.createdBy`, `Event.updatedBy`, `Event.competitive`,
  `Event.featuredImage`, `Event.imageOptimized`, `Event.iconOptimized`,
  `Event.featuredImageOptimized`, `Event.disqusThread`, `Event.parentEvent`,
  `Event.isNew`, `Event.cyom`, `Event.showAllOutcomes`,
  `Event.showMarketImages`, `Event.automaticallyResolved`,
  `Event.enableNegRisk`, `Event.automaticallyActive`, `Event.seriesSlug`,
  `Event.eventWeek`, `Event.score`, `Event.elapsed`, `Event.period`, and
  `Event.negRiskFeeBips`.
- Added Polygolem `pkg/orderfills` parity for on-chain `OrderFilled` truth
  data, including public models, validation, reader interfaces, and a read-only
  Polygon JSON-RPC log reader for `eth_getLogs`/block timestamp decoding.
- Added a mock-only Flutter Web deposit-wallet order smoke example that proves
  the `WalletSigner` approval boundary and `signatureType=3` payload path
  without live endpoints or raw private keys.
- Matched Data API aggregate routing to current Polygolem endpoints:
  `/holders`, `/value`, `/traded`, `/oi`, `/v1/leaderboard`, and
  `/live-volume?id=...`.
- Flattened current `/holders` responses and widened leaderboard decoding to
  Polygolem's current field aliases.

## [0.1.0-alpha.2] — 2026-05-13

Polygolem parity commit:
`07145d557738d576d2fb16bfa6a45fa5dffeea5d`.

### Changed

- Updated the Polygolem reference to a small upstream `.gitignore` cleanup so
  tracked reference files are no longer reported as gitignored during Dart
  package validation.
- Kept the hosted package archive filtered to the Dart SDK surface while
  preserving `lib/src/**` implementation files.

### Verified

- `dart pub publish --dry-run` now validates with 0 warnings.

## [0.1.0-alpha.1] — 2026-05-13

Polygolem parity commit:
`5220881a08d512d58d31faca98f17fa184148407`.

### Added

- Public alpha package metadata and release archive filtering for the hosted
  Dart package.
- Flutter app readiness documentation, source-pinned install options, lifecycle
  notes, wallet adapter guidance, and Flutter Web constraints.
- Errors: sealed `PolydartException` hierarchy with stable `ErrorCode`.
- Logging: `Logger` interface, silent default, console sink.
- Type primitives: `Decimal`, `NumericString`, `StringOrArray`,
  `NormalizedDateTime`, enums (`Side`, `OrderType`, `SignatureType`).
- CLOB / Gamma data classes (read-side subset).
- Transport: `HttpTransport` with retry, timeout, rate limit, circuit
  breaker, redaction helpers.
- Config: `PolydartConfig.fromEnv` + Go-style duration parser.
- Modes: `PolydartMode` enum + `requireLive` / `requirePaperOrLive`
  guards.
- Gamma client: `health`, `search`, `markets`, `marketById`,
  `marketBySlug`.
- CLOB client: `health`, `serverTime`, `markets`, `market`, `orderBook`,
  `orderBooks`, `price`, `midpoint`, `spread`, `lastTradePrice`,
  `tickSize`, `pricesHistory`.
- Pagination: `CursorPager`, `OffsetPager` with `Stream<T>` access.
- BookReader: top-of-book, midpoint, spread, depth aggregation.
- MarketResolver: slug / id → `ResolvedMarket` with token id helpers.
- MarketDiscovery: Gamma + CLOB enrichment with parallel CLOB fan-out.
- Top-level `Polydart` client with `readOnly` and `paper` factories that
  share transports across sub-clients.
- Live credential discovery: `LiveCredentialService`, `CredentialStore`, and
  `MemoryCredentialStore` for wallet-mediated CLOB L2 API key create/derive
  plus CLOB builder-fee key and Relayer V2 API-key creation without raw EOA
  private keys.
- Deposit-wallet readiness can consume `LiveCredentialReadiness` directly,
  build a Relayer V2 client from the relayer key, and return a blocked
  machine-readable state when credentials are incomplete.
- Deposit-wallet readiness now checks the six V2 pUSD/CTF approvals plus CLOB
  `balance-allowance` with `signature_type=3`, returning `needsApproval`,
  `needsFunding`, or `ready`.
- Deposit-wallet limit-order placement now derives the deposit wallet from the
  EOA signer, signs the ERC-7739 `TypedDataSign` envelope, posts
  `signatureType=3`, and keeps CLOB HMAC auth EOA-bound.
- Deposit-wallet market-order placement now supports Polygolem-compatible buy
  market orders with explicit price or book-discovered fill price, using
  `signatureType=3` and EOA-bound CLOB HMAC auth.
- EOA pUSD funding route planning now reads the EOA pUSD balance, builds a
  direct wallet transaction for `pUSD.transfer(depositWallet, amount)`, and
  reports full, partial, or unavailable funding state without submitting funds.
- CI workflow: format, analyze, test (network tests opt-in).

### Changed

- Order salt generation uses web-safe 32-bit bounds so Flutter Web consumers do
  not hit Dart-to-JavaScript integer precision limits.
- Public documentation now treats `WalletSigner` as the app-owned approval
  boundary for any EOA/deposit-wallet operation.

### Verified

- A Flutter Web consumer smoke path can depend on Polydart, request a
  wallet-mediated deposit-wallet order signature, and send the resulting order
  payload through a local mock CLOB endpoint.

### Known Gaps

- Alpha APIs remain unstable and may change before `1.0.0`.
- Live write paths remain lower-level and require explicit live mode,
  `liveTradingEnabled`, user approval through `WalletSigner`, and readiness
  checks.
- Browser SIWE cookie login and Relayer V2 API-key minting are not directly
  portable to Flutter Web because browsers do not expose `Set-Cookie` to app
  code or allow arbitrary `Cookie` request headers.
- Remaining parity gaps are tracked in
  `docs/POLYDART-POLYGOLEM-COVERAGE.md`.
