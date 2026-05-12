---
title: Paper Mode
description: Use Polydart paper mode and PaperState for local simulated fills.
sidebar:
  order: 2
---

Paper mode separates market reads from local simulated execution. It is useful for UX testing, portfolio modeling, and strategy rehearsal without submitting orders.

## Create A Paper Client

`Polydart.paper()` records the EOA address that owns the simulated account. It still exposes the same read surfaces as the read-only client.

```dart
import 'package:polydart/polydart.dart';

Future<void> openPaperClient() async {
  final client = Polydart.paper(
    eoaAddress: const String.fromEnvironment('WALLET_ADDRESS'),
  );

  try {
    final markets = await client.discovery.searchAndEnrich('bitcoin', limit: 3);
    print('paper mode=${client.mode.label} markets=${markets.length}');
  } finally {
    client.close();
  }
}
```

## Track Local Paper Cash And Fills

`PaperState` is a local state object. Buying a `PaperOrder` updates cash, positions, and fills in memory.

```dart
import 'package:polydart/polydart.dart';

final state = PaperState.newState('ppUSD', 1000);

final fill = state.buy(
  const PaperOrder(
    marketId: 'demo-market',
    tokenId: 'demo-token',
    price: 0.42,
    size: 10,
  ),
);

print('cash=${state.cash}');
print('position=${state.positions[fill.tokenId]?.size}');
print('live=${fill.live}');
```

The fill has `live: false` and has no effect on Polymarket.

## Persist Paper State

`PaperState.toJson()` and `PaperState.fromJson()` let an app choose its own storage layer.

```dart
import 'package:polydart/polydart.dart';

Map<String, Object> encodePaper(PaperState state) => state.toJson();

PaperState decodePaper(Map<String, Object?> json) {
  return PaperState.fromJson(json);
}
```

Flutter apps can store this JSON in their preferred local storage system.

## Gate Simulated Submission

Use `requirePaperOrLive()` for code paths that should not run in read-only mode.

```dart
import 'package:polydart/polydart.dart';

void ensureSimulationAllowed(Polydart client) {
  requirePaperOrLive(client.mode);
}
```

This keeps read-only browsing paths separate from simulated or live execution paths.
