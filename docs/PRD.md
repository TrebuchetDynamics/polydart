# Polydart PRD — Standalone Polymarket Dart SDK for Flutter

> **Status:** Draft — awaiting implementation plan  
> **Date:** 2026-05-07  
> **Owner:** TrebuchetDynamics  
> **License:** MIT (public)

---

## 1. Vision

Polydart is the **official Dart-native Polymarket SDK** — a peer implementation to `polygolem` that brings the full Polymarket protocol stack to Flutter applications. It enables Flutter developers to build self-contained trading apps that interact directly with Polymarket APIs, with minimal or zero server dependency.

**Polydart will always mirror the polygolem repository.** Every protocol module, API client, signing scheme, and safety boundary in polygolem has a corresponding Dart implementation in polydart. When polygolem evolves, polydart evolves in lockstep.

---

## 2. Relationship to Polygolem

| Aspect | Polygolem (Go) | Polydart (Dart) |
|--------|----------------|-----------------|
| **Purpose** | Server/bot SDK and CLI | Flutter/mobile SDK |
| **Architecture** | Cobra CLI + internal packages | Flutter package + Dart internals |
| **Protocol parity** | Reference implementation | **Mirror — spec-for-spec** |
| **Crypto** | Go `crypto/ecdsa`, `go-ethereum` | Dart `web3dart`, `pointycastle` |
| **HTTP** | `net/http` with custom retry | `http` package with interceptor stack |
| **WebSocket** | Gorilla + custom reconnect | `web_socket_channel` with reconnect |
| **State** | File-based paper state | `shared_preferences` / `hive` |
| **Signing** | Local private key | Reown/WalletConnect to MetaMask |

**Synchronization rule:** When polygolem adds a new protocol client, signing scheme, or API endpoint, polydart adds the equivalent within the same release cycle. Both repos share the same version numbering.

---

## 3. Architecture

```
polydart/
├── lib/
│   ├── src/
│   │   ├── auth/               # EIP-712, POLY_1271, ERC-7739, CREATE2
│   │   ├── clob/               # CLOB V2 client (read + write)
│   │   ├── gamma/              # Gamma API client
│   │   ├── dataapi/            # Data API client
│   │   ├── relayer/            # Builder relayer client
│   │   ├── wallet/             # Deposit wallet lifecycle
│   │   ├── orders/             # OrderIntent, builders, validation
│   │   ├── stream/             # WebSocket market streams
│   │   ├── transport/          # HTTP retry, rate limit, circuit breaker
│   │   ├── types/              # Protocol types (mirrors internal/polytypes)
│   │   ├── config/             # Configuration, validation, redaction
│   │   ├── modes/              # Read-only / paper / live gates
│   │   ├── risk/               # Per-trade caps, daily loss limits
│   │   ├── paper/              # Local simulation state
│   │   └── execution/          # Order execution surface
│   └── polydart.dart           # Public SDK surface
├── test/
│   ├── unit/
│   ├── integration/
│   └── fixtures/               # Shared test vectors with polygolem
├── example/
│   └── arenaton_demo/          # Demo Flutter app
└── pubspec.yaml
```

---

## 4. Core Modules

### 4.1 `auth` — Cryptographic Primitives

**Mirrors:** `internal/auth`

| Capability | Dart Implementation |
|-----------|---------------------|
| EIP-712 typed data signing | `web3dart` `Credentials.signTypedData` |
| POLY_1271 order signatures | Custom — appends `0x03` signature type byte |
| ERC-7739 context | Custom — wraps order hash with chain/verifying contract |
| Deposit wallet CREATE2 | Keccak-256 + `eth_call` to factory |
| Address derivation | `ecdsa` pubKey → keccak → last 20 bytes |

**Key constraint:** No private key storage. All signing flows through Reown/WalletConnect.

### 4.2 `clob` — CLOB V2 Client

**Mirrors:** `internal/clob`

- **Read endpoints** (no auth): book, trades, prices, spread, orders
- **Write endpoints** (signing required): create-order, cancel, update-balance
- **Signature type:** `POLY_1271` (deposit wallet) only — EOA/proxy/Safe blocked

### 4.3 `gamma` — Market Discovery

**Mirrors:** `internal/gamma`

- Search, markets, events, tags, series, sports
- Read-only, no credentials
- Handles Gamma API quirks (inconsistent datetime, string-or-array fields)

### 4.4 `relayer` — Builder Relayer

**Mirrors:** `internal/relayer`

- WALLET-CREATE (deploy)
- WALLET batch (approve + fund)
- Nonce polling
- Builder attribution headers

**Note:** Builder credentials live in a minimal server proxy, not in the app.

### 4.5 `wallet` — Deposit Wallet Lifecycle

**Mirrors:** `internal/wallet`

- `derive(eoaAddress)` → predict CREATE2 address
- `deploy()` → server proxy calls relayer
- `status()` → on-chain check
- `batch(calls)` → EIP-712 sign via Reown → submit

### 4.6 `orders` — Order Building

**Mirrors:** `internal/orders`

```dart
final order = await client.orders
  .buy(tokenId: '123...')
  .atPrice(0.5)
  .forSize(10)
  .withBuilder('0x...')
  .build();
```

### 4.7 `stream` — Real-Time Data

**Mirrors:** `internal/stream`

- WebSocket orderbook updates
- Auto-reconnect with exponential backoff
- Deduplication by message nonce

---

## 5. Security Model (Reown/WalletConnect)

### 5.1 Threat Model

| Threat | Mitigation |
|--------|-----------|
| Private key exposure | **Eliminated** — keys never leave MetaMask |
| Builder credential leak | **Minimized** — creds in server proxy only |
| Man-in-the-middle | HTTPS + certificate pinning |
| Malicious signing requests | User sees full transaction in MetaMask |
| App compromise | Damage limited to current session orders |

### 5.2 Key Flow

```
User MetaMask (holds private key)
    ↑
    │ WalletConnect / Reown
    │
Flutter App (Polydart)
    │
    │ HTTP / WebSocket
    ↓
Polymarket APIs (CLOB, Gamma, Relayer)
    ↑
    │ (for deploy/batch only)
Tiny Server Proxy (builder creds)
    ↓
Builder Relayer
```

### 5.3 Server Proxy (Minimal)

~50 lines of Go or Dart. Only handles:
- `POST /relay/deploy` — forwards with builder headers
- `POST /relay/batch` — forwards with builder headers

Everything else is client-direct.

---

## 6. Public API Surface

### 6.1 Read-Only Mode (default)

```dart
import 'package:polydart/polydart.dart';

// No credentials needed
final client = Polydart.readOnly();

final markets = await client.gamma.search(query: 'btc 5m', limit: 5);
final book = await client.clob.getOrderBook(tokenId: '123...');
final price = await client.clob.getPrice(tokenId: '123...');
```

### 6.2 Paper Mode

```dart
final client = await Polydart.paper(
  eoaAddress: '0x...',
);

// Simulated orders — local state only
final order = await client.orders.buy(tokenId: '...').atPrice(0.5).forSize(10).build();
await client.paper.submit(order);
```

### 6.3 Live Mode

```dart
final client = await Polydart.live(
  reownProvider: walletConnectProvider,
  eoaAddress: '0x...',
  serverProxyUrl: 'https://your-relayer-proxy.com',
);

// Real signing via MetaMask
final order = await client.orders.buy(tokenId: '...').atPrice(0.5).forSize(10).build();
await client.clob.submit(order); // prompts MetaMask
```

---

## 7. Mode System

**Mirrors:** `internal/modes`

| Mode | Private Key | Server Proxy | Authenticated APIs |
|------|------------|--------------|-------------------|
| **Read-only** | Not needed | Not needed | Blocked |
| **Paper** | EOA address only | Not needed | Blocked (local sim) |
| **Live** | Reown provider | Required for deploy/batch | Full access |

**Gates:**
- Live mode requires `preflight` checks (balance, allowance, nonce)
- `risk` module enforces per-trade caps and daily loss limits
- `circuit breaker` halts trading on repeated errors

---

## 8. Implementation Phases

### Phase 1 — Foundation (v0.1.0)
- [ ] `types` — all protocol types
- [ ] `gamma` — read-only market discovery
- [ ] `clob` — read-only endpoints
- [ ] `transport` — HTTP client with retry/rate limit
- [ ] `config` — env binding, validation
- [ ] Unit tests for all above

### Phase 2 — Authentication (v0.2.0)
- [ ] `auth` — EIP-712 typed data signing via Reown
- [ ] `wallet` — CREATE2 derivation, status checks
- [ ] `orders` — OrderIntent builder
- [ ] `clob` — write endpoints (create-order, cancel)

### Phase 3 — Full Trading (v0.3.0)
- [ ] `relayer` — builder relayer client
- [ ] `paper` — local simulation state
- [ ] `stream` — WebSocket market data
- [ ] `risk` — per-trade caps, daily limits
- [ ] `execution` — order execution surface

### Phase 4 — Polish (v0.4.0)
- [ ] `dataapi` — positions, volume, leaderboards
- [ ] `bridge` — supported assets, deposit addresses
- [ ] Example Flutter app (Arenaton demo)
- [ ] Documentation site
- [ ] CI/CD with Flutter integration tests

---

## 9. Dependencies

```yaml
dependencies:
  http: ^1.2.0
  web_socket_channel: ^2.4.0
  web3dart: ^2.7.0
  pointycastle: ^3.7.0
  reown_appkit: ^1.0.0  # WalletConnect / Reown
  shared_preferences: ^2.2.0
  hive: ^2.2.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  mockito: ^5.4.0
  flutter_test:
    sdk: flutter
```

---

## 10. Testing Strategy

**Mirrors polygolem test structure.**

| Test Type | Coverage |
|-----------|----------|
| Unit | Every module independently |
| Integration | Against Polymarket testnet/staging |
| Fixtures | Shared EIP-712 hashes, CREATE2 addresses with polygolem |
| Property-based | Order validation, price/size bounds |
| E2E | Full flow: search → build → sign (mock) → submit |

---

## 11. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `web3dart` lacks EIP-712 support | Medium | High | Contribute PR or fork; fallback to manual RLP encoding |
| Mobile signing latency (Reown) | High | Medium | Pre-build orders, queue for batch sign |
| Polymarket API drift | Medium | High | Automated contract tests against live API weekly |
| Builder credential leak | Low | Critical | Server proxy only; rotate monthly; rate limit |
| CREATE2 derivation mismatch | Low | Critical | Cross-validate every address against polygolem Go impl |

---

## 12. Success Criteria

- [ ] All polygolem `pkg/` APIs have polydart equivalents
- [ ] All polygolem `internal/` modules have Dart mirrors
- [ ] Shared test vectors pass in both repos
- [ ] Example app (Arenaton demo) runs with zero server for read-only
- [ ] Server proxy < 100 LOC for deploy/batch
- [ ] CI passes: Dart analysis, tests, integration tests
- [ ] pub.dev package published

---

## 13. Open Questions

1. **Reown vs WalletConnect v3:** Which library is more stable for production?
2. **Server proxy language:** Go (polygolem reuse) or Dart (single stack)?
3. **Paper state storage:** `shared_preferences` vs `hive` vs `drift`?
4. **Flutter minimum version:** 3.16+ or 3.19+?
5. **Null safety:** Dart 3 strict mode — any legacy concerns?

---

*This PRD is a living document. It will be updated as implementation progresses and as polygolem evolves. The mirror commitment is permanent: polygolem is the reference, polydart is the Dart-native twin.*
