# Polydart Implementation Plan

Companion to `PRD.md`. Translates the PRD into concrete modules, ordering, and acceptance criteria.

> **Reference repo:** [`TrebuchetDynamics/polygolem`](https://github.com/TrebuchetDynamics/polygolem), mirrored locally as a read-only `polygolem/` checkout when protocol work needs upstream evidence.

---

## 1. Architectural Decisions

### AD-1 — Pure-Dart core, no Flutter dependency in `polydart`
The PRD lists `reown_appkit`, `shared_preferences`, and `hive` as dependencies. Pulling those into the SDK forces a Flutter-only consumer story and prevents reuse from CLI tools, server agents, or pure-Dart bots.

**Decision:** `polydart` is a pure-Dart package. EOA signing, ReownWallet / WalletConnect transport, and persistent storage are abstracted as interfaces (`WalletSigner`, `KeyValueStore`, …). Flutter/mobile consumers provide ReownWallet, secure-storage, and app-session adapters in app code. Adapter extraction is deferred until the live flow works. Until then no consumer is blocked: read-only, paper, and pre-built-order flows do not need a wallet.

### AD-2 — Twin architecture, not slavish copy
Polygolem is the older-brother protocol reference. Polydart mirrors Polygolem's public protocol surfaces, request/response DTOs, fixtures, signer seams, safety gates, and major module responsibilities so parity checks stay mechanical. File-level layout can diverge — Dart idioms, Flutter/web signer constraints, sealed classes, extension methods, and async streams differ from Go — but every Polygolem feature must either have a Dart twin, a documented Dart-specific divergence, or a safety-gated omission in the parity matrix.

### AD-3 — Shared test vectors, separate test runners
A `tests/parity/` directory holds JSON fixtures (typed-data hashes, CREATE2 addresses, sample orderbooks). Both repos read the same fixtures. Polygolem owns the generator; polydart owns its own assertions.

### AD-4 — Builder credentials never in the SDK
Per PRD §5. The SDK exposes a `RelayerProxyClient` that targets a user-supplied URL. Direct relayer endpoints are off the public API. CI verifies no builder secret string ever ships in compiled artifacts.

### AD-5 — Strict mode by default
`analysis_options.yaml` enables `strict-casts`, `strict-inference`, `strict-raw-types`, and `lints: recommended`. CI fails on `dart analyze` warnings, not just errors.

### AD-6 — Version lockstep with polygolem MAJOR.MINOR
Polydart MAJOR.MINOR mirrors polygolem. Patch versions diverge for Dart-specific fixes. Each release notes the polygolem commit it parities against.

### AD-7 — Refresh polygolem before package work
A local `polygolem/` checkout is the canonical upstream evidence source for protocol work. Before touching any protocol module, refresh or create it:

```sh
if [ -d polygolem/.git ]; then
  git -C polygolem pull --ff-only origin main
else
  git clone https://github.com/TrebuchetDynamics/polygolem.git polygolem
fi
```

Use the refreshed `polygolem/` commit as the source of truth for CLOB, Gamma, Data API, deposit-wallet, relayer, signing, and safety behavior. Record the commit in the implementation notes or parity fixture update. If the refresh changes a relevant upstream contract, update the Dart code and parity tests together. Do not edit the upstream checkout directly.

---

## 2. Module Mapping (polygolem → polydart)

The mapping is architectural, not byte-for-byte: preserve the same layer responsibilities (clients, DTOs, signers, transport, safety gates, tests, and docs), then choose Dart-native files and adapters where needed.

| polygolem | polydart | Phase | Notes |
|-----------|----------|-------|-------|
| `internal/polytypes` | `lib/src/types` | 1 | Pure data classes; JSON via `json_serializable`. |
| `internal/transport` | `lib/src/transport` | 1 | HTTP client w/ retry + rate limit + circuit breaker. |
| `internal/config` | `lib/src/config` | 1 | Env binding, validation, redaction. |
| `internal/errors` | `lib/src/errors` | 1 | Sealed error hierarchy. |
| `internal/output` | `lib/src/logging` | 1 | Polygolem `output` is CLI-only formatting; SDK exposes a `Logger` instead. |
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
2. **`lib/src/logging/`** — `Logger` interface + `Logger.silent` default + `Logger.console`. No `print` calls anywhere else in src.
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
- New `WalletSigner` interface for normal-app EOA Signer with ReownWallet flows; **no concrete Reown impl in `polydart`** — Flutter/mobile consumers wire Reown or equivalent wallet approval in app code. `LocalEoaSigner` is an explicit advanced signer for CLI tests, alpha/test apps, headless users, server automation, and generated paper-mode wallets.

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
- Consumer app-local adapters for EOA Signer with ReownWallet, secure credential storage, and any persistent `KeyValueStore` wiring needed by live flows. Keep generated no-sign-in keys paper-only.
- `example/` — keep plain-Dart Flutter integration patterns current for read-only, wallet signing, and mock live/deposit-wallet smoke flows.
- pub.dev publish dry-run, then real publish for `polydart` when the API is stable.

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

- [ ] Normal app flows use EOA Signer with ReownWallet or equivalent wallet-provider approval.
- [ ] Explicit private-key EOA signing (`LocalEoaSigner`) is opt-in, redacted, and reserved for CLI tests, alpha/test apps, headless users, server automation, or generated paper-mode wallets.
- [ ] `WalletSigner` interface returns signatures only — never raw key material.
- [ ] HTTPS-only by config default; certificate pinning hook for Flutter consumers.
- [ ] Redaction in `Logger` for fields tagged `@redacted`.
- [ ] Risk module enforced before any live submission.
- [ ] Circuit breaker halts on N consecutive auth/transport failures.

---

## 11. Stable SDK Parity Finish Track

**Finish line:** Polydart reaches Stable SDK Parity when every coverage-matrix row is `implemented`, an explicit intentional Dart divergence, or `not applicable`; generated parity docs are fresh; tests and CI are green; and live mutations remain explicit safety-gated SDK surfaces rather than app-owned production trading guarantees.

**First finish track: Safety-Required Live Mutation Parity.** Close the `Safety Review: required` partial rows before lower-risk DTO polish:

1. Deposit-wallet live semantics — first implementation slice. Finish Flutter/demo wiring, readiness UX examples, and any remaining wallet deployment/approval/funding parity tests without making live mutation implicit. Start from the existing mock live journey and readiness checklist; keep all tests fake-transport/mock-RPC unless explicitly tagged opt-in network.
2. Signing and order construction — close EIP-712, ERC-7739, POLY_1271, wallet-provider, explicit-private-key, and authenticated order edge-case parity.
3. Relayer and enable-trading — finish endpoint parity, V2 auth/readiness coverage, adapter approval planning, and live-submission boundaries.
4. CLOB authenticated reads/writes — finish authenticated read/write edge cases, response-shape drift, cancellation/batch behavior, and structured live-error coverage.
5. Wallet/RPC/settlement live boundaries — close deploy/status/batch semantics and read-only RPC gaps, or document intentional app-owned/gated divergences.

**Second finish track: Broad DTO and facade parity.** After safety-required rows are closed, finish `pkg/types`/`internal/polytypes`, `pkg/universal`, and workflow mapping rows with upstream fixtures and generated parity-doc freshness checks.

**Validation gate for each closure:** update code/tests/docs together, refresh `docs/parity/polydart-polygolem.yaml`, run `dart run tool/generate_parity_docs.dart --check`, `dart analyze --fatal-warnings`, and `dart test`.

## 12. Open Questions (proposed resolutions)

| # | PRD Question | Proposed Answer | Confidence |
|---|--------------|-----------------|------------|
| 1 | ReownWallet vs raw WalletConnect naming | Use the user-facing term EOA Signer with ReownWallet; Reown is WalletConnect v3-era branding, while the SDK boundary remains `WalletSigner`. | High |
| 2 | Optional server proxy | Defer until public SDK hardening. Initial live-readiness work uses app-local relayer credentials injected into `polydart` or minted by `LiveCredentialService.ensure()` in cookie-capable runtimes. | High |
| 3 | Paper-state storage | Inject `KeyValueStore`. Default in-memory; Flutter consumers wire `hive`; CLI consumers wire file-backed. | High |
| 4 | Flutter min version | `polydart` is pure Dart (no Flutter pin). Consumer apps own their own Flutter/Reown version pins. | High |
| 5 | Null safety | Dart 3 strict mode. No legacy concerns; no migrations. | High |

Pinned for review; happy to flip any of these on user input.

---

## 13. Out of Scope (for now)

- Polymarket-style UI components (consumer app concern, not SDK).
- Automated market-maker strategies (consumer concern, not SDK).
- ZK-proof or alternative privacy layers.
- iOS-specific tooling beyond what consumer Flutter apps already own.

---

## 14. Risks (delta from PRD §11)

| Risk | Mitigation in this plan |
|------|-------------------------|
| EIP-712 encoding mismatch | Internal `eip712.dart` uses manual encoding plus `pointycastle` Keccak, validated against polygolem vectors. |
| Polymarket API drift | Weekly parity job (§9) catches schema/normalization drift early. |
| Relayer credential leak | Injected or locally minted credentials only in `polydart`; app-local secure storage in the consumer app; no shared embedded creds; optional proxy later. |
| CREATE2 mismatch | Phase 2 acceptance gates on shared address vector. |

---

## 15. Done When

The success criteria from PRD §12 hold **and**:
- Polygolem and polydart parity suites are green for the same commit pair.
- A Flutter consumer imports `polydart`, wires app-local signing/storage adapters, performs a read-only search, a paper buy, and a live-mode mock-signed order, with no Polymarket secrets in the consumer's source tree.

---

*Document status: living. Edit as phases progress; record dated entries in `CHANGELOG.md`.*
