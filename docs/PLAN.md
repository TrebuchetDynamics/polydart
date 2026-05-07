# Polydart Implementation Plan

Companion to `PRD.md`. Translates the PRD into concrete modules, ordering, and acceptance criteria.

> **Reference repo:** [`TrebuchetDynamics/polygolem`](https://github.com/TrebuchetDynamics/polygolem) (commit `a481200` at time of writing, mirrored locally under `.reference/polygolem/`).

---

## 1. Architectural Decisions

### AD-1 — Pure-Dart core, no Flutter dependency in `polydart`
The PRD lists `reown_appkit`, `shared_preferences`, and `hive` as dependencies. Pulling those into the SDK forces a Flutter-only consumer story and prevents reuse from CLI tools, server agents, or pure-Dart bots.

**Decision:** `polydart` is a pure-Dart package. Wallet signing, wallet-connect transport, and persistent storage are abstracted as interfaces (`WalletSigner`, `KeyValueStore`, …). A separate `polydart_flutter` package will provide Reown/Hive adapters when phase 2 begins. Until then no consumer is blocked: read-only, paper, and pre-built-order flows do not need a wallet.

### AD-2 — Mirror layout, not slavish copy
`polygolem/internal/<module>/` maps to `lib/src/<module>/`. Module **names** match exactly so the parity check is mechanical. File-level layout can diverge — Dart idioms (sealed classes, extension methods, async streams) differ from Go.

### AD-3 — Shared test vectors, separate test runners
A `tests/parity/` directory holds JSON fixtures (typed-data hashes, CREATE2 addresses, sample orderbooks). Both repos read the same fixtures. Polygolem owns the generator; polydart owns its own assertions.

### AD-4 — Builder credentials never in the SDK
Per PRD §5. The SDK exposes a `RelayerProxyClient` that targets a user-supplied URL. Direct relayer endpoints are off the public API. CI verifies no builder secret string ever ships in compiled artifacts.

### AD-5 — Strict mode by default
`analysis_options.yaml` enables `strict-casts`, `strict-inference`, `strict-raw-types`, and `lints: recommended`. CI fails on `dart analyze` warnings, not just errors.

### AD-6 — Version lockstep with polygolem MAJOR.MINOR
Polydart MAJOR.MINOR mirrors polygolem. Patch versions diverge for Dart-specific fixes. Each release notes the polygolem commit it parities against.

---

## 2. Module Mapping (polygolem → polydart)

| polygolem | polydart | Phase | Notes |
|-----------|----------|-------|-------|
| `internal/polytypes` | `lib/src/types` | 1 | Pure data classes; JSON via `json_serializable`. |
| `internal/transport` | `lib/src/transport` | 1 | HTTP client w/ retry + rate limit + circuit breaker. |
| `internal/config` | `lib/src/config` | 1 | Env binding, validation, redaction. |
| `internal/errors` | `lib/src/errors` | 1 | Sealed error hierarchy. |
| `internal/output` | `lib/src/output` | 1 | Structured logging façade. |
| `internal/gamma` | `lib/src/gamma` | 1 | Read-only market discovery. |
| `internal/clob` (read) | `lib/src/clob` (read paths) | 1 | Book/trades/prices/spread. |
| `pkg/bookreader` | `lib/src/bookreader` | 1 | Order book aggregation helper. |
| `pkg/pagination` | `lib/src/pagination` | 1 | Cursor + offset pagers. |
| `internal/marketdiscovery` | `lib/src/marketdiscovery` | 1 | Composes gamma + clob. |
| `pkg/marketresolver` | `lib/src/marketresolver` | 1 | Slug/id/condition resolution. |
| `internal/modes` | `lib/src/modes` | 1 | Read-only / paper / live gates. |
| `internal/auth` | `lib/src/auth` | 2 | EIP-712, POLY_1271, ERC-7739. |
| `internal/wallet` | `lib/src/wallet` | 2 | CREATE2 derivation, status, batch. |
| `internal/orders` | `lib/src/orders` | 2 | Builder API + validation. |
| `internal/clob` (write) | `lib/src/clob` (write paths) | 2 | create-order, cancel, update-balance. |
| `internal/preflight` | `lib/src/preflight` | 2 | Balance/allowance/nonce checks. |
| `internal/relayer` | `lib/src/relayer` | 3 | Builder relayer proxy client. |
| `internal/paper` | `lib/src/paper` | 3 | Local sim state via injectable store. |
| `internal/stream` | `lib/src/stream` | 3 | WebSocket orderbook stream. |
| `internal/risk` | `lib/src/risk` | 3 | Per-trade caps, daily loss limits. |
| `internal/execution` | `lib/src/execution` | 3 | High-level order execution surface. |
| `internal/dataapi` | `lib/src/dataapi` | 4 | Positions, volume, leaderboards. |
| `pkg/bridge` | `lib/src/bridge` | 4 | Supported assets, deposit addresses. |
| `internal/cli` | _n/a_ | — | Polygolem-only (Cobra CLI). |
| `internal/rpc` | _maybe_ | 4 | Only if needed for direct RPC reads. |

`example/` (Phase 4) replaces polygolem's `cmd/polygolem`.

---

## 3. Phase 1 — Foundation (target v0.1.0-alpha)

Goal: a consumer can construct `Polydart.readOnly()` and read markets, books, prices, and trades from Polymarket without a wallet.

### 3.1 Tasks (in order)

1. **`lib/src/errors/`** — `PolydartException` sealed root + `TransportError`, `ApiError`, `ValidationError`. Mirrors `internal/errors` sentinel set.
2. **`lib/src/output/`** — `Logger` interface + `NullLogger` default + `ConsoleLogger`. No `print` calls anywhere else in src.
3. **`lib/src/types/`** — Port `internal/polytypes/*.go` records:
   - `clob.dart` — `Order`, `OrderBook`, `Trade`, `Price`, `Spread`, `BookLevel`.
   - `market.dart` — `GammaMarket`, `Event`, `Tag`, `Series`.
   - `normalize.dart` — datetime/string-or-array tolerant decoders.
   - All immutable, `==`/`hashCode`, JSON via `json_serializable`.
4. **`lib/src/transport/`**:
   - `http_client.dart` — wrapper around `package:http` with timeout, retry-with-jitter, idempotency keys.
   - `rate_limit.dart` — token-bucket per host.
   - `circuit_breaker.dart` — closed/open/half-open state machine; ports `internal/transport/circuitbreaker.go`.
5. **`lib/src/config/`** — `PolydartConfig` immutable record; `fromEnv(Map<String,String>)`; redaction for `toString`/logs.
6. **`lib/src/gamma/`** — `GammaClient` with `search`, `markets`, `events`, `tags`, `series`. Tolerant decoders only here.
7. **`lib/src/clob/`** (read only) — `ClobClient.readOnly(...)` with `getOrderBook`, `getPrice`, `getSpread`, `getTrades`, `getMidpoint`.
8. **`lib/src/pagination/`** — `CursorPager<T>`, `OffsetPager<T>`. Reusable from gamma/clob/dataapi.
9. **`lib/src/bookreader/`** — pure helper that aggregates book levels and computes top-of-book / depth.
10. **`lib/src/marketresolver/`** — slug ↔ market id ↔ condition id resolution; deterministic, no I/O beyond gamma reads.
11. **`lib/src/marketdiscovery/`** — composes `GammaClient` + `MarketResolver` for "find me liquid btc 5m markets" flows.
12. **`lib/src/modes/`** — `Mode.readOnly`, `Mode.paper`, `Mode.live`; gate functions reject auth-only calls in non-live modes.
13. **`lib/polydart.dart`** — barrel + `Polydart.readOnly()` factory.

### 3.2 Acceptance Criteria

- `dart analyze` clean under strict mode.
- `dart test` green for every module's unit tests.
- Parity fixture suite (Phase 1 subset) passes: gamma normalization, book-aggregation math, pagination cursors.
- One end-to-end smoke test against live Polymarket Gamma + CLOB read endpoints (network-tagged, opt-in).
- README example compiles and runs:
  ```dart
  final c = Polydart.readOnly();
  final results = await c.gamma.search(query: 'btc 5m', limit: 3);
  print(results);
  ```

### 3.3 First-week task list (Phase 1 kickoff)

- [ ] `errors/`, `output/` skeletons + tests.
- [ ] `types/clob.dart` + `types/market.dart` with `json_serializable` + golden JSON fixtures from polygolem `polytypes_test.go`.
- [ ] `transport/http_client.dart` with retry + timeout. Defer rate limit and circuit breaker to week 2.
- [ ] `gamma/client.dart` — `search` + `markets` only.
- [ ] CI workflow: `dart pub get`, `dart analyze`, `dart test`, `dart format --output=none --set-exit-if-changed .`.

---

## 4. Phase 2 — Authentication (target v0.2.0-alpha)

Goal: build, sign, and submit POLY_1271 orders via an injected `WalletSigner`.

Highlights:
- `auth/eip712.dart` — port `internal/auth/eip712.go`. Cross-validate every typed-data hash against polygolem fixtures.
- `auth/poly1271.dart` — append `0x03` signature type byte; verify with shared vectors.
- `auth/erc7739.dart` — context wrapping for chain id + verifying contract.
- `auth/create2.dart` — deposit-wallet address prediction; cross-check against polygolem `auth_test.go`.
- `wallet/deposit_wallet.dart` — `derive`, `status`, `deploy` (delegates to `RelayerProxyClient`).
- `orders/order_builder.dart` — fluent API matching PRD §4.6.
- `clob/` write paths gated by `Mode.live`.
- New `WalletSigner` interface; **no concrete Reown impl yet** — that lives in `polydart_flutter`.

Acceptance: shared parity fixtures for EIP-712 hash, POLY_1271 signature roundtrip, CREATE2 address all pass against polygolem-generated vectors.

---

## 5. Phase 3 — Full Trading (target v0.3.0-alpha)

- `relayer/proxy_client.dart` — talks to a user-deployed proxy URL. No builder creds in source.
- `paper/` — local sim using injected `KeyValueStore` interface.
- `stream/orderbook_stream.dart` — `web_socket_channel` + reconnect with exponential backoff + dedupe by message nonce.
- `risk/limits.dart` — per-trade caps, daily loss caps; stateful, persisted via `KeyValueStore`.
- `execution/executor.dart` — orchestrates preflight → build → sign → submit → confirm.

Acceptance: full paper-mode loop runs offline; live-mode loop runs against staging with a mock signer.

---

## 6. Phase 4 — Polish (target v0.4.0-alpha)

- `dataapi/` — positions, volume, leaderboards.
- `bridge/` — supported assets, deposit addresses (mirrors `pkg/bridge`).
- `polydart_flutter/` — sibling package: Reown adapter for `WalletSigner`, Hive adapter for `KeyValueStore`.
- `example/arenaton_demo/` — minimal Flutter app demonstrating read-only + paper + live (mock) flows.
- Docs site (mkdocs or docusaurus, parity with polygolem `docs-site/`).
- pub.dev publish dry-run, then real publish for `polydart` (non-Flutter) and `polydart_flutter`.

---

## 7. Parity Strategy

- **Fixture directory:** `tests/parity/` (committed).
- **Generator:** polygolem ships `cmd/parityfixgen` (to be added) that emits JSON for hashes, addresses, sample books.
- **Polydart consumes** the JSON in `test/parity/*_test.dart`. Failure modes are surfaced with the polygolem commit hash.
- **Drift check:** weekly CI job pulls latest polygolem and re-runs the parity suite. A drift opens an issue, not a CI failure on PRs.

---

## 8. Testing

Mirrors PRD §10:

| Layer | Tool | Scope |
|-------|------|-------|
| Unit | `package:test` | One file per `lib/src/<module>` source file. |
| Property | `package:glados` (eval Phase 2) | Order validation, price/size bounds. |
| Parity | `package:test` reading `tests/parity/` | Cross-language hashes/addresses. |
| Integration | `package:test` w/ `@Tags(['network'])` | Live Polymarket reads, opt-in. |
| End-to-end | _Phase 4_ | Example app exercise of all three modes. |

`coverage` target: 80% line coverage by end of Phase 1; 90% by Phase 3.

---

## 9. CI/CD

GitHub Actions (`.github/workflows/`):

- `ci.yaml` — on push/PR: `dart pub get`, `dart format --set-exit-if-changed`, `dart analyze --fatal-warnings`, `dart test`.
- `parity.yaml` — weekly cron + manual: pull polygolem main, run parity suite, open issue on drift.
- `publish.yaml` — manual on tag `vX.Y.Z`: `dart pub publish --dry-run` (publish gated until Phase 4).

No secrets in repo. Builder creds checked by a CI grep step against the source tree.

---

## 10. Security Checklist (Phase 2+)

- [ ] No private keys ever stored, logged, or transmitted by the SDK.
- [ ] `WalletSigner` interface returns signatures only — never raw key material.
- [ ] HTTPS-only by config default; certificate pinning hook for Flutter consumers.
- [ ] Redaction in `Logger` for fields tagged `@redacted`.
- [ ] Risk module enforced before any live submission.
- [ ] Circuit breaker halts on N consecutive auth/transport failures.

---

## 11. Open Questions (proposed resolutions)

| # | PRD Question | Proposed Answer | Confidence |
|---|--------------|-----------------|------------|
| 1 | Reown vs WalletConnect v3 | Reown (it _is_ WalletConnect v3 rebranded; arenaton-flutter already uses `reown_appkit`). | High |
| 2 | Server proxy language | Dart, ~50 LOC, runs on shelf. Keeps stack count low; reuses polydart types. Polygolem can also expose its own. | Medium |
| 3 | Paper-state storage | Inject `KeyValueStore`. Default in-memory; Flutter consumers wire `hive`; CLI consumers wire file-backed. | High |
| 4 | Flutter min version | `polydart` is pure Dart (no Flutter pin). `polydart_flutter` targets Flutter 3.19+. | High |
| 5 | Null safety | Dart 3 strict mode. No legacy concerns; no migrations. | High |

Pinned for review; happy to flip any of these on user input.

---

## 12. Out of Scope (for now)

- Polymarket-style UI components (those live in `arenaton-flutter`).
- Automated market-maker strategies (consumer concern, not SDK).
- ZK-proof or alternative privacy layers.
- iOS-specific tooling beyond what `flutter` already provides via `polydart_flutter`.

---

## 13. Risks (delta from PRD §11)

| Risk | Mitigation in this plan |
|------|-------------------------|
| `web3dart` lacks first-class EIP-712 | Phase 2 includes a thin internal `eip712.dart` built on `pointycastle` + manual encoding, validated against polygolem vectors. |
| Polymarket API drift | Weekly parity job (§9) catches schema/normalization drift early. |
| Builder credential leak | AD-4 + CI grep + relayer proxy boundary. |
| CREATE2 mismatch | Phase 2 acceptance gates on shared address vector. |

---

## 14. Done When

The success criteria from PRD §12 hold **and**:
- Polygolem and polydart parity suites are green for the same commit pair.
- A Flutter consumer (arenaton-flutter or the example app) imports `polydart` + `polydart_flutter`, performs a read-only search, a paper buy, and a live-mode mock-signed order, with no Polymarket secrets in the consumer's source tree.

---

*Document status: living. Edit as phases progress; record dated entries in `CHANGELOG.md`.*
