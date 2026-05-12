---
title: API Module Map
description: Map the public Polydart export surface to common application tasks.
sidebar:
  order: 1
---

Import from the package root unless you are working inside Polydart itself:

```dart
import 'package:polydart/polydart.dart';
```

## Top-Level Client

| API | Use |
| --- | --- |
| `Polydart.readOnly()` | Shared read-only Gamma, CLOB, resolver, and discovery clients. |
| `Polydart.paper(eoaAddress: ...)` | Read surfaces plus a paper-mode marker for simulated execution. |
| `PolydartConfig` | Base URLs, timeout, mode, live flag, and paper state path. |
| `polydartVersion` | SDK version string. |

Polydart does not currently expose a top-level `Polydart.live()` constructor.
Live write paths are lower-level and require explicit `PolydartMode.live`
configuration plus safety gates.

## Market Data

| API | Use |
| --- | --- |
| `GammaClient` | Markets, events, series, tags, teams, comments, search, and public profiles. |
| `GetMarketsParams`, `GetEventsParams`, `SearchParams` | Typed query builders for Gamma endpoints. |
| `ClobClient` | Public CLOB reads and access to the gated write surface. |
| `BookParams`, `PriceHistoryParams` | Batch book/price and price-history request shapes. |
| `BookReader` | Convenience access over an `OrderBook`. |
| `MarketResolver`, `ResolvedMarket` | Resolve slugs or Gamma ids to condition ids, outcomes, and token ids. |
| `MarketDiscovery`, `EnrichedMarket` | Compose Gamma markets with CLOB midpoint, spread, tick, last price, and book reads. |
| `DataApiClient`, `LiveVolumeMarket` | Public positions, trades, activity, holders, open interest, volume, and leaderboard reads. |
| `UniversalClient` | Read facade across Gamma, CLOB, Data API, discovery, streams, and health. |
| `MarketClient`, `StreamConfig`, `NewMarketMessage`, `MarketResolvedMessage` | CLOB WebSocket market stream client, configuration, and lifecycle event DTOs. |

## Wallets, Auth, And Signing

| API | Use |
| --- | --- |
| `WalletSigner` | App-owned wallet signing adapter for EIP-712 and personal-sign messages. |
| `buildClobAuthTypedData`, `hashClobAuth`, `buildL1Headers` | CLOB L1 auth payloads and headers. |
| `ApiKey`, `buildL2Headers`, `signHmac` | CLOB L2 API key headers and HMAC signing. |
| `buildEnableTradingClobAuthTypedData` | Enable Trading control-message typed data. |
| `buildEnableTradingApprovalCalls` | Deterministic deposit-wallet approval call plan. |
| `buildEnableTradingApprovalBatchTypedData` | Deposit-wallet batch typed data for the approval plan. |
| `signEnableTradingClobAuthTypedData`, `signEnableTradingApprovalBatchTypedData` | Wallet-mediated signing helpers. |
| `deriveDepositWallet`, `deriveProxyWallet`, `makerAddressForSignatureType` | Address derivation and maker-address helpers. |
| `buildWalletBatchTypedData`, `signWalletBatch` | Deposit-wallet batch signing primitives. |

## Orders And CLOB Writes

| API | Use |
| --- | --- |
| `OrderBuilder`, `OrderIntent`, `SignedOrder` | Build and represent order intents. |
| `computeAmounts`, `roundToTick`, `validatePriceAgainstTick` | Price, size, tick, and amount helpers. |
| `buildOrderV2TypedData`, `hashOrderV2`, `signOrderV2` | V2 order typed-data, hash, and wallet-mediated signature helpers. |
| `CreateLimitOrderParams`, `CreateMarketOrderParams` | High-level order placement parameter objects. |
| `createLimitOrder`, `createMarketOrder` | High-level placement helpers; require gated live writes. |
| `ClobWrites`, `CreateOrderRequest`, `BatchOrderResponse`, `CancelResponse`, `maxBatchPostSize` | Live-only create, batch create, cancel, and heartbeat surface behind `requireLive()`. |

## Modes, Safety, And Risk

| API | Use |
| --- | --- |
| `PolydartMode` | `read-only`, `paper`, and `live` mode values. |
| `requireLive`, `requirePaperOrLive` | Runtime mode gates. |
| `LiveGateInput`, `LiveGateResult`, `validateLiveGates` | Four-part live gate evaluation. |
| `PreflightCheck`, `PreflightResult`, `runPreflight` | Caller-defined readiness probes. |
| `Breaker`, `Policy`, `RiskStatus` | Local risk breaker primitives. |
| `PolydartException`, `SafetyException`, `ValidationException`, `ErrorCode` | Stable exception and error-code model. |

## Paper And Simulation

| API | Use |
| --- | --- |
| `PaperState` | Local paper cash, positions, and fills. |
| `PaperOrder` | Simulated order input. |
| `PaperFill` | Recorded simulated fill with `live: false`. |
| `PaperPosition` | Aggregated local token position. |

## Protocol And Settlement Planning

| API | Use |
| --- | --- |
| `CTF`, `positionId`, `collectionId`, `splitPositionData`, `mergePositionsData`, `redeemPositionsData` | Conditional Tokens helpers and calldata builders. |
| `contractDeployed`, `depositWalletDeployed`, `redeemAdapterFor` | Contract registry and readiness helpers. |
| `buildPusdTransferCallPlan`, `buildPusdTransferBatchTypedData` | Wallet-mediated pUSD funding call planning. |
| `findRedeemable`, `checkReadiness`, `buildRedeemCall` | Settlement discovery and redeem call planning. |
| `DepositWalletReadinessService`, `DepositWalletReadiness`, `DepositWalletApprovalCheck` | Live deposit-wallet deploy, approval, and funding readiness state. |
| `RelayerClient`, `RelayerError`, `mintV2APIKey`, `buildApprovalCalls` | Relayer and approval primitives for explicitly gated application flows. |

## Transport And Observability

| API | Use |
| --- | --- |
| `HttpTransport`, `TransportConfig` | HTTP base URL, timeout, and transport wrapper. |
| `RateLimiter`, `CircuitBreaker` | Request shaping and circuit state. |
| `TelemetryLogger`, `RedactableValue`, `redactTelemetryValue` | Redacted request and runtime telemetry. |
