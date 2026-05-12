---
title: Polygolem Fidelity
description: How Polydart tracks Polygolem behavior while preserving Dart and Flutter safety boundaries.
sidebar:
  order: 1
---

Polydart is a Dart peer implementation of Polygolem. The goal is behavioral fidelity for public API clients, protocol encoding, typed-data construction, error categories, transport behavior, and safety gates.

## Fidelity Rules

For each ported surface, Polydart tracks:

- Public method shape and naming appropriate for Dart.
- Wire query parameters, request bodies, and response decoding.
- Numeric string handling for prices, sizes, and amounts.
- Protocol constants, chain ids, verifying contracts, and type hashes.
- Tests or fixtures that cover the ported behavior.
- Safety review for signing, relayer, settlement, CLOB writes, and funding flows.

## Intentional Dart Divergence

Polydart diverges where mobile custody requires a different public SDK boundary:

| Area | Polygolem pattern | Polydart pattern |
| --- | --- | --- |
| Wallet custody | Local key material can be used by server or CLI workflows. | Public SDK signing goes through `WalletSigner`. |
| Enable Trading | Go workflows can own more execution detail. | Dart builds typed-data and approval plans for wallet-mediated confirmation. |
| Funding and settlement | Server-side flows can combine signing and submission. | Dart exposes call planning and readiness helpers, with live submission kept behind gates. |
| Live writes | Bot and server workflows can run direct write loops. | Flutter-facing docs keep live writes out of quickstarts and require explicit gates. |

## Current Public Coverage

| Surface | Polydart modules | Fidelity status |
| --- | --- | --- |
| Gamma market discovery | `GammaClient`, `GetMarketsParams`, `SearchParams` | Public read endpoints and common DTOs are implemented. |
| CLOB reads | `ClobClient`, `BookParams`, `PriceHistoryParams`, `BookReader` | Books, prices, midpoint, spread, tick size, market listing, and batch reads are implemented. |
| Data API reads | `DataApiClient` and data DTOs | Public user, position, trade, activity, holder, interest, and leaderboard reads are implemented. |
| Market resolution | `MarketResolver`, `ResolvedMarket` | Slug and id resolution map Gamma markets to condition ids and CLOB token ids. |
| Paper state | `PaperState`, `PaperOrder`, `PaperFill`, `PaperPosition` | Local paper fills and JSON state are implemented. |
| Modes and gates | `PolydartMode`, `validateLiveGates`, `runPreflight` | Read-only, paper, and live gate semantics are implemented. |
| Wallet signing | `WalletSigner`, EIP-712, ERC-7739, POLY_1271 helpers | Protocol primitives are implemented with wallet-mediated public signing boundaries. |
| Enable Trading | `buildEnableTrading*`, `signEnableTrading*` | Typed-data and approval planning are implemented; submission is application-owned. |

## Compatibility Guidance

When Polygolem adds or changes a protocol surface, Polydart should add the Dart equivalent with:

1. A public export from `lib/polydart.dart` when the surface is part of the SDK.
2. A read-only or planning-first API where possible.
3. A `WalletSigner` boundary for signatures.
4. A live-gate check before any live write.
5. Tests or fixtures that prove wire and hash parity.

If a server-oriented behavior does not fit Flutter custody, document the divergence and keep the safer public SDK boundary.
