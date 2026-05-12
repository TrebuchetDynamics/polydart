---
title: Read-Only Market Data
description: Search Gamma, resolve CLOB token ids, read order books, and use the Data API.
sidebar:
  order: 1
---

Read-only market data uses public Polymarket APIs and does not require credentials. The top-level `Polydart.readOnly()` client shares transports across Gamma, CLOB, resolver, and discovery surfaces.

## Search And Enrich

`MarketDiscovery` composes Gamma markets with CLOB reads. Per-market CLOB failures are non-fatal; missing fields are returned as `null`.

```dart
import 'package:polydart/polydart.dart';

Future<List<EnrichedMarket>> findMarkets(String query) async {
  final client = Polydart.readOnly();
  try {
    return await client.discovery.searchAndEnrich(query, limit: 5);
  } finally {
    client.close();
  }
}
```

## Resolve A Slug To Token Ids

Use `MarketResolver` before reading a book or planning an order. A market is available only when it is accepting orders, not closed, not archived, order-book enabled, and has aligned outcomes and token ids.

```dart
import 'package:polydart/polydart.dart';

Future<String?> resolveYesToken(String slug) async {
  final client = Polydart.readOnly();
  try {
    final resolved = await client.resolver.resolveBySlug(slug);
    if (resolved == null || !resolved.isAvailable) return null;
    return resolved.yesTokenId;
  } finally {
    client.close();
  }
}
```

## Read CLOB Prices And Books

`ClobClient` exposes public reads for order books, midpoint, spread, last trade price, tick size, batch prices, and price history.

```dart
import 'package:polydart/polydart.dart';

Future<void> inspectToken(String tokenId) async {
  final client = Polydart.readOnly();
  try {
    final book = await client.clob.orderBook(tokenId);
    final reader = BookReader(book);

    final midpoint = await client.clob.midpoint(tokenId);
    final spread = await client.clob.spread(tokenId);
    final tickSize = await client.clob.tickSize(tokenId);

    print('best bid=${reader.bestBid?.price ?? "n/a"}');
    print('best ask=${reader.bestAsk?.price ?? "n/a"}');
    print('midpoint=$midpoint spread=$spread tick=${tickSize.tickSize}');
  } finally {
    client.close();
  }
}
```

Batch endpoints use `BookParams`:

```dart
Future<Map<String, String>> readBatchPrices({
  required Polydart client,
  required String yesTokenId,
  required String noTokenId,
}) {
  return client.clob.prices([
    BookParams(tokenId: yesTokenId, side: Side.buy),
    BookParams(tokenId: noTokenId, side: Side.sell),
  ]);
}
```

## Read User-Scoped Public Data

`DataApiClient` reads public position, trade, activity, holder, open-interest, and leaderboard data. It does not require authentication.

```dart
import 'package:polydart/polydart.dart';

Future<void> inspectPublicWallet(String walletAddress) async {
  final data = DataApiClient();
  try {
    final positions = await data.currentPositions(walletAddress, limit: 25);
    final trades = await data.trades(walletAddress, limit: 25);
    final total = await data.totalValue(walletAddress);

    print('positions=${positions.length}');
    print('trades=${trades.length}');
    print('total=${total.value}');
  } finally {
    data.close();
  }
}
```

## Use The Universal Read Facade

`UniversalClient` groups Gamma, read-only CLOB, Data API, discovery, stream construction, and health checks for applications that prefer one read facade.

```dart
import 'package:polydart/polydart.dart';

Future<void> checkPublicApis() async {
  final client = UniversalClient();
  try {
    final health = await client.healthCheck();
    print('gamma=${health.gammaOk} clob=${health.clobOk} data=${health.dataOk}');

    final markets = await client.activeMarkets();
    print('active markets=${markets.length}');
  } finally {
    client.close();
  }
}
```
