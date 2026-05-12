# Changelog

All notable changes documented here. Follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added (Phase 1 — Foundation, read-only protocol surface)
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
- CI workflow: format, analyze, test (network tests opt-in).

## [0.1.0-alpha.1] — TBD

Tag the first alpha once a Flutter consumer has been integrated against this
surface end-to-end.
