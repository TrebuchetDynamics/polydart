# Polydart-Polygolem Coverage Matrix

This matrix tracks Polydart completion against upstream Polygolem. Polygolem is
the protocol source of truth; Polydart may intentionally diverge on public SDK
custody architecture as described in `docs/adr/0001-wallet-mediated-eoa-signing.md`.

- Canonical upstream source: `polygolem/`
- Last scaffolded Polygolem commit: `2b7cde7`
- Last fidelity sync commit: `21f1982`
- Scaffold command: `python3 skills/polydart/scripts/polygolem_inventory.py --root .`
- Upstream delta after `21f1982`: Gamma comment profiles normalization, market
  trades Data API, batch orderbooks exposure, and market metadata are ported.
  Polygolem `91876cf` added `pkg/orderfills`; Polydart now covers public
  models, validation, reader interfaces, and read-only Polygon JSON-RPC log
  decoding with mocked RPC tests.

Status values: `implemented`, `partial`, `missing`, `intentional Dart
divergence`, `not applicable`.

`implemented` means behavior, public API/export story, tests or fixtures,
safety gates where relevant, user docs where needed, and upstream commit are
all accounted for.

## Priority Blockers

| Feature | Polygolem Path | Polydart Path | Status | Tests/Fixtures | Safety Review | Upstream Commit | Next Action |
|---|---|---|---|---|---|---|---|
| Wallet-mediated EOA custody | internal/auth, internal/wallet | lib/src/auth, lib/src/wallet | intentional Dart divergence | test/auth, test/wallet | required | 2b7cde7 | Enforce ADR 0001 in signing and wallet work |
| Deposit-wallet live semantics | internal/wallet, internal/relayer, internal/clob | lib/src/wallet, lib/src/relayer, lib/src/clob, lib/src/credentials, lib/src/orders, lib/src/funding | partial | test/wallet, test/relayer, test/clob, test/credentials, test/orders, test/funding | required | 5220881a | Deposit-wallet readiness, limit-order placement, batch limit-order placement, buy market-order placement, cancellation auth, EOA pUSD funding route planning, and post-funding confirmation now cover sigtype-3 approval/funding checks, ERC-7739 wrapped signing, deposit-wallet maker/signer fields, EOA-bound CLOB HMAC auth, direct `pUSD.transfer` wallet transaction planning, wallet-submitted tx receipt polling, CLOB collateral refresh, market amount truncation, book price discovery, typed CLOB live error bodies, and Polygolem-matched batch/cancel request shapes; continue Flutter example/demo wiring |
| EIP-712 / ERC-7739 / POLY_1271 signing | internal/auth, internal/clob/orders.go | lib/src/auth, lib/src/orders | partial | test/auth, test/orders | required | 2b7cde7 | Expand byte-level parity vectors |
| Relayer and enable-trading surfaces | pkg/relayer, pkg/enabletrading, internal/enabletrading | lib/src/relayer, lib/src/enabletrading | partial | test/relayer, test/enabletrading | required | 2b7cde7 | Relayer V2 API-key headers, transaction object/list responses, poll defaults, and allowlist classification covered; continue live submission UX docs |
| CLOB write responses and order results | internal/clob, pkg/orderresults | lib/src/clob, lib/src/orders, lib/src/orderresults | partial | test/clob, test/orders, test/orderresults | required | 5220881a | Order response casing, batch create, EOA-bound batch/cancel `POLY_ADDRESS`, cleaned cancel IDs, cancel body casing, heartbeat, typed live error DTO fields, and order-results report builder covered; continue authenticated read/write edge cases |
| Data API live V2 field shapes | internal/dataapi, pkg/data | lib/src/dataapi | implemented | test/dataapi | not_required | f4d0443 | Current-position, closed-position, trade, holder, open-interest, volume, leaderboard, aggregate object/list decoding, and current endpoint routing covered; monitor upstream |

## Surface Inventory

| Feature | Polygolem Path | Polydart Path | Status | Tests/Fixtures | Safety Review | Upstream Commit | Next Action |
|---|---|---|---|---|---|---|---|
| pkg/bridge | polygolem/pkg/bridge | lib/src/bridge | implemented | test/bridge | not_required | 2b7cde7 | HTTP-only bridge client covered |
| pkg/builder | polygolem/pkg/builder | lib/src/builder | implemented | test/builder | not_required | 2b7cde7 | Local and remote builder signer surfaces covered |
| pkg/clob | polygolem/pkg/clob | lib/src/clob, lib/src/credentials | partial | test/clob, test/credentials | required | 2b7cde7 | Wallet-mediated CLOB L2 create/derive and builder-fee key orchestration covered; continue authenticated write parity |
| pkg/contracts | polygolem/pkg/contracts | lib/src/contracts | implemented | test/contracts | not_required | 2b7cde7 | Contract registry and eth_getCode readiness covered |
| pkg/ctf | polygolem/pkg/ctf | lib/src/ctf | implemented | test/ctf | not_required | 2b7cde7 | CTF calldata and ID helpers covered |
| pkg/data | polygolem/pkg/data | lib/src/dataapi | implemented | test/dataapi | not_required | f4d0443 | Current Data API wrapper methods, endpoints, and DTO decoding covered; monitor upstream |
| pkg/enabletrading | polygolem/pkg/enabletrading | lib/src/enabletrading | partial | test/enabletrading | required | 2b7cde7 | Wallet-mediated ClobAuth and approval batch planning covered; live submission stays app-owned/gated |
| pkg/experimental | polygolem/pkg/experimental |  | not applicable |  | not_required | 2b7cde7 | Revisit only if promoted upstream |
| pkg/funding | polygolem/pkg/funding | lib/src/funding | intentional Dart divergence | test/funding | required | 2b7cde7 | EOA pUSD balance route planning and direct wallet transaction request covered; raw live transfer submission intentionally omitted |
| pkg/gamma | polygolem/pkg/gamma | lib/src/gamma | partial | test/gamma | not_required | 2b7cde7 | Profile creation helper covered; continue endpoint and DTO coverage |
| pkg/marketdata | polygolem/pkg/marketdata | lib/src/marketdata | implemented | test/marketdata | not_required | 2b7cde7 | Market-data tracker covered |
| pkg/marketresolver | polygolem/pkg/marketresolver | lib/src/marketresolver | partial | test/marketresolver | not_required | 2b7cde7 | Compare resolver semantics |
| pkg/orderbook | polygolem/pkg/orderbook | lib/src/orderbook | implemented | test/orderbook | not_required | 21f1982 | ClobOrderBookReader (single + batch fetches), ValidationException on empty tokenId, empty-skip behavior, BookReader integration, and 5 mock HTTP tests covered; matches polygolem Reader/BatchReader interfaces |
| pkg/orderbook (bookreader) | polygolem/pkg/bookreader | lib/src/bookreader | implemented | test/bookreader | not_required | 2b7cde7 | BookReader compute class (sorted bids/asks, midpoint, spread, depth) covered |
| pkg/orderresults | polygolem/pkg/orderresults | lib/src/orderresults | implemented | test/orderresults | not_required | 2b7cde7 | Report builder covered; CLOB inclusion uses ApiKey reader instead of raw private key |
| pkg/orderfills | polygolem/pkg/orderfills | lib/src/orderfills | implemented | test/orderfills | not_required | 91876cf | Public Fill/Market/Query, validation, reader interfaces, default exchange filters, buy/sell log decoding, market filtering, timestamp lookup, and latest-block reader covered with mocked Polygon JSON-RPC tests |
| pkg/pagination | polygolem/pkg/pagination | lib/src/pagination | implemented | test/pagination | not_required | 2b7cde7 | Cursor/offset stream, collect, and batch helpers covered |
| pkg/plugins | polygolem/pkg/plugins | lib/src/plugins | implemented | test/plugins | not_required | 2b7cde7 | Plugin interfaces covered |
| pkg/relayer | polygolem/pkg/relayer | lib/src/relayer | partial | test/relayer | required | 2b7cde7 | V2 auth headers, transaction response shapes, poll defaults, and allowlist rejection classifier covered; continue endpoint parity |
| pkg/settlement | polygolem/pkg/settlement | lib/src/settlement | partial | test/settlement | required | 2b7cde7 | Read-only redeem discovery, call planning, and readiness checks covered; live relay submission gated out |
| pkg/stream | polygolem/pkg/stream | lib/src/stream | implemented | test/stream | not_required | 2b7cde7 | Default URL, config payload, reconnect resubscribe, dedupe, and lifecycle events covered |
| pkg/types | polygolem/pkg/types | lib/src/types | partial | test/types | not_required | 2b7cde7 | Market DTO now covers Polygolem `marketType`, `umaResolutionStatus`, `readyTimestamp`, `rewardsMinSize`, `rewardsMaxSpread`, and `negRiskFeeBips`; Event DTO now covers `subtitle`, `subcategory`, `sortBy`, `isTemplate`, `templateVariables`, `createdBy`, `updatedBy`, `competitive`, `featuredImage`, `imageOptimized`, `iconOptimized`, `featuredImageOptimized`, `disqusThread`, `parentEvent`, `isNew`, `cyom`, `showAllOutcomes`, `showMarketImages`, and `negRiskFeeBips`; continue broad DTO field/casing comparison |
| pkg/universal | polygolem/pkg/universal | lib/src/universal | partial | test/universal | not_required | 2b7cde7 | Read-only universal facade covered; authenticated raw-key write methods intentionally excluded from default public surface |
| pkg/wallet | polygolem/pkg/wallet | lib/src/wallet | partial | test/wallet | required | 2b7cde7 | Port protocol behavior without raw EOA keys |
| internal/auth | polygolem/internal/auth | lib/src/auth | partial | test/auth | required | 2b7cde7 | Expand signing parity vectors |
| internal/clob | polygolem/internal/clob | lib/src/clob, lib/src/credentials | partial | test/clob, test/credentials | required | 5220881a | CLOB L2 credential create/derive reuses one wallet-approved ClobAuth signature across fallback; builder-fee key creation preserves partial readiness; deposit-wallet batch placement and cancellation use EOA-bound HTTP auth; CLOB write 4xx bodies map to structured `ClobException.upstream`; continue authenticated read/write edge cases |
| internal/config | polygolem/internal/config | lib/src/config | implemented | test/config | not_required | 21f1982 | PolydartConfig with defaults, fromEnv (prefix support), copyWith, redacted toString, parseDuration, and 10 tests covered; YAML file loading intentionally omitted (CLI-only concern in Go) |
| internal/dataapi | polygolem/internal/dataapi | lib/src/dataapi | implemented | test/dataapi | not_required | f4d0443 | Current-position, closed-position, trade, holder, open-interest, volume, leaderboard, aggregate object/list fields, and endpoint names covered; monitor upstream |
| internal/enabletrading | polygolem/internal/enabletrading | lib/src/enabletrading | partial | test/enabletrading | required | 2b7cde7 | Wallet-mediated typed-data builders covered; no raw EOA key submission surface |
| internal/errors | polygolem/internal/errors | lib/src/errors | implemented | test/errors | not_required | 21f1982 | All 20 ErrorCode values match 1:1 (NET-*, AUTH-*, CLOB-*, VAL-*, SAFETY-*, GAMMA-*); typed exception hierarchy (TransportException, AuthException, ClobException, ValidationException, SafetyException, GammaException) with 10 tests; ClobErrorResponse structured decoding covered |
| internal/execution | polygolem/internal/execution | lib/src/execution | implemented | test/execution | not_required | 21f1982 | Executor interface, PaperExecutor with Place/Cancel/GetOrder/ListOrders, PaperOrderEntry, PaperFillEntry, and 10 tests covered; maps executor semantics to polydart's paper/live/read-only boundaries |
| internal/gamma | polygolem/internal/gamma | lib/src/gamma | partial | test/gamma | not_required | 2b7cde7 | Profile creation helper covered; continue search/event/tag/series/profile DTO parity |
| internal/marketdiscovery | polygolem/internal/marketdiscovery | lib/src/marketdiscovery | partial | test/marketdiscovery | not_required | 2b7cde7 | Compare enrichment behavior |
| internal/modes | polygolem/internal/modes | lib/src/modes | implemented | test/modes | not_required | 2b7cde7 | Parse defaults and live-gate validation covered |
| internal/orders | polygolem/internal/orders | lib/src/orders | partial | test/orders | required | 5220881a | Deposit-wallet single and batch placement helpers covered; compare remaining rounding, validation, expiration |
| internal/output | polygolem/internal/output |  | not applicable |  | not_required | 2b7cde7 | CLI output formatting; no public SDK surface planned |
| internal/paper | polygolem/internal/paper | lib/src/paper | implemented | test/paper | not_required | 2b7cde7 | Local paper state covered |
| internal/polytypes | polygolem/internal/polytypes | lib/src/types | partial | test/types | not_required | 2b7cde7 | Market metadata DTO parity expanded with market type, UMA status, ready timestamp, rewards, and neg-risk fee fields; Event metadata DTO parity expanded with subtitle, subcategory, sort hint, template flag/variables, creator/updater, competitive score, featured image, optimized image/icon/featured-image DTOs, Disqus thread, parent event, new-event flag, CYOM flag, show-all-outcomes flag, show-market-images flag, and neg-risk fee bips; continue using upstream DTO fixtures to drive type parity |
| internal/preflight | polygolem/internal/preflight | lib/src/preflight | implemented | test/preflight | not_required | 2b7cde7 | Async preflight runner covered |
| internal/relayer | polygolem/internal/relayer | lib/src/relayer, lib/src/credentials, lib/src/wallet | partial | test/relayer, test/credentials, test/wallet | required | 2b7cde7 | SIWE cookie login, Relayer V2 API-key minting, submit, auth headers, object/list transaction responses, allowlist classification, readiness consumption, and approval/funding readiness covered; continue live submission UX |
| internal/risk | polygolem/internal/risk | lib/src/risk | implemented | test/risk | not_required | 2b7cde7 | Local risk breaker covered |
| internal/rpc | polygolem/internal/rpc | lib/src/rpc | partial | test/rpc, test/funding | not_required | 2b7cde7 | Read-only code/approval/allowance/balance helpers covered; live transfer/swap submission still gated out |
| internal/stream | polygolem/internal/stream | lib/src/stream | implemented | test/stream | not_required | 2b7cde7 | Message parsing, lifecycle events, reconnect resubscribe, and custom-feature subscription covered |
| internal/telemetry | polygolem/internal/telemetry | lib/src/telemetry | implemented | test/telemetry | not_required | 2b7cde7 | Request/retry/rate-limit/circuit-open telemetry and redaction covered |
| internal/transport | polygolem/internal/transport | lib/src/transport | implemented | test/transport | not_required | 21f1982 | CircuitBreaker (3-state closed/open/halfOpen, maxFailures=5, resetTimeout=60s, halfOpenMaxRequests=3), RateLimiter (token bucket, tryAcquire/acquire/stop), HttpTransport (GET/POST with retry on 5xx/429, no-retry on POST/4xx, circuit breaker + rate limiter integration, timeout, redaction), and 38 tests covered; matches polygolem behavior |
| internal/wallet | polygolem/internal/wallet | lib/src/wallet | partial | test/wallet | required | 2b7cde7 | Compare derive/deploy/status/batch semantics |
| cli/* | polygolem/internal/cli |  | not applicable |  | mixed | 2b7cde7 | Port behavior only when it maps to public SDK APIs |

## Tracked Non-Protocol Cleanup

| Item | Status | Next Action |
|---|---|---|
| Retire legacy extra Polygolem checkout compatibility | implemented | Canonical upstream is the read-only `polygolem/` submodule |
