---
title: Polydart SDK
description: Public SDK docs for using Polydart from Dart and Flutter applications.
sidebar:
  order: 1
---

Polydart is a Dart-native SDK for Polymarket data, protocol planning, and guarded trading workflows. Start here if you want a Flutter or Dart app to read public markets, resolve CLOB token ids, plan wallet-mediated signatures, or run paper-mode simulations.

The default path is read-only. Live order submission is not shown in these docs and is gated by explicit mode, configuration, confirmation, and preflight checks.

## Install

Use the hosted alpha release once it is published:

```yaml
dependencies:
  polydart: ^0.1.0-alpha.2
```

For source-pinned consumers, use the public repository tag:

```yaml
dependencies:
  polydart:
    git:
      url: https://github.com/TrebuchetDynamics/polydart.git
      ref: v0.1.0-alpha.2
```

Then import the public SDK surface:

```dart
import 'package:polydart/polydart.dart';
```

## First Read-Only Client

`Polydart.readOnly()` wires the Gamma and CLOB public clients and does not require credentials.

```dart
import 'package:polydart/polydart.dart';

Future<void> main() async {
  final client = Polydart.readOnly();

  try {
    final search = await client.gamma.search(
      const SearchParams(query: 'bitcoin', limitPerType: 3),
    );

    Market? firstMarket;
    for (final event in search.events) {
      for (final market in event.markets) {
        if (market.active && market.enableOrderBook) {
          firstMarket = market;
          break;
        }
      }
      if (firstMarket != null) break;
    }

    if (firstMarket == null) return;

    final resolved = await client.resolver.resolveBySlug(firstMarket.slug);
    final yesTokenId = resolved?.yesTokenId;
    if (yesTokenId == null) return;

    final midpoint = await client.clob.midpoint(yesTokenId);
    final spread = await client.clob.spread(yesTokenId);

    print('${firstMarket.question}: midpoint=$midpoint spread=$spread');
  } finally {
    client.close();
  }
}
```

## Operating Modes

Polydart exposes three operating modes:

| Mode | Constructor or API | Purpose |
| --- | --- | --- |
| `read-only` | `Polydart.readOnly()` | Public Gamma, CLOB, resolver, and discovery reads. |
| `paper` | `Polydart.paper(eoaAddress: ...)` plus `PaperState` | Local simulation state and paper fills. |
| `live` | `PolydartMode.live` gates and live-only lower-level clients | Explicitly gated write workflows. |

Read paths do not need a wallet. Signing paths use a caller-provided `WalletSigner`; the SDK does not ask for raw private keys.

## Common Flow

Most applications follow this order:

1. Search or list markets with `GammaClient`.
2. Resolve a market slug to condition and token ids with `MarketResolver`.
3. Read order books, midpoint, spread, tick size, and recent prices with `ClobClient`.
4. If simulating, record fills in `PaperState`.
5. If preparing live access, build wallet typed-data plans and evaluate live gates before any submission path is available.

## Next Pages

- Flutter setup: [Flutter quickstart](/flutter/quickstart/)
- Market data: [Read-only market data](/api/read-only-market-data/)
- Wallet model: [Wallet-mediated signing](/protocol-safety/wallet-signing/)
- Safety gates: [Live safety gates](/protocol-safety/live-safety-gates/)
- Public surface: [API module map](/reference/api-module-map/)
