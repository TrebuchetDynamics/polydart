---
title: Flutter Quickstart
description: Add Polydart to a Flutter app and read public market data safely.
sidebar:
  order: 1
---

This page shows a minimal Flutter integration that keeps Polydart in a repository/service object, closes HTTP transports when the feature is disposed, and avoids wallet or live-write setup.

## Add The Dependency

```yaml
dependencies:
  flutter:
    sdk: flutter
  polydart:
    git:
      url: https://github.com/TrebuchetDynamics/polydart.git
```

Run:

```bash
flutter pub get
```

## Create A Read Repository

Keep the SDK client outside widgets so transport lifetime is explicit.

```dart
import 'package:polydart/polydart.dart';

final class MarketDataRepository {
  MarketDataRepository()
      : _client = Polydart.readOnly(
          config: const PolydartConfig(
            requestTimeout: Duration(seconds: 15),
          ),
        );

  final Polydart _client;

  Future<List<EnrichedMarket>> search(String query) {
    return _client.discovery.searchAndEnrich(query, limit: 5);
  }

  Future<ResolvedMarket?> resolveSlug(String slug) {
    return _client.resolver.resolveBySlug(slug);
  }

  Future<OrderBook> orderBook(String tokenId) {
    return _client.clob.orderBook(tokenId);
  }

  void dispose() => _client.close();
}
```

## Use It From Flutter

The SDK returns Dart futures and plain model objects, so it works with any state management approach.

```dart
final repo = MarketDataRepository();

Future<void> loadMarkets() async {
  final markets = await repo.search('bitcoin');
  for (final market in markets) {
    final question = market.market.question;
    final midpoint = market.midpoint ?? 'n/a';
    print('$question midpoint=$midpoint');
  }
}
```

Call `repo.dispose()` from your provider, bloc, controller, or widget teardown path.

## Configure With Dart Defines

Flutter apps can pass public endpoint overrides with `--dart-define` and bind them into `PolydartConfig`.

```dart
import 'package:polydart/polydart.dart';

const gammaBaseUrl = String.fromEnvironment(
  'POLYMARKET_GAMMA_BASE_URL',
  defaultValue: PolydartConfig.defaultGammaBaseUrl,
);

const clobBaseUrl = String.fromEnvironment(
  'POLYMARKET_CLOB_BASE_URL',
  defaultValue: PolydartConfig.defaultClobBaseUrl,
);

final client = Polydart.readOnly(
  config: const PolydartConfig(
    gammaBaseUrl: gammaBaseUrl,
    clobBaseUrl: clobBaseUrl,
  ),
);
```

## Add Wallets Later

Do not put wallet keys in Flutter configuration. When you need signing, implement `WalletSigner` as an adapter around the wallet provider your app already uses, then pass typed-data requests to that provider. The signing model is covered in [wallet-mediated signing](/protocol-safety/wallet-signing/).

Flutter Web can use the read-only client and wallet-mediated signing prompts,
but cookie-backed SIWE login and Relayer V2 API-key minting require a
VM/mobile/desktop runtime or an application backend/proxy because browsers do
not expose `Set-Cookie` or permit custom `Cookie` request headers.

For VM/mobile/desktop Flutter targets, `LiveCredentialService.ensure()` can
create CLOB L2 credentials, CLOB builder-fee credentials, and Relayer V2 API
keys through that wallet adapter. Store the returned credentials in app-owned
secure storage through `CredentialStore`.

Pass those credentials into
`DepositWalletReadinessService.checkWithCredentials(...)` before prompting for
deploy or approval actions. The readiness result stays machine-readable:
`needsDeploy`, `needsApprovalCheck`, `needsApproval`, `needsFunding`, `ready`,
or `blocked`.

After a `ready` result, use `createDepositWalletLimitOrder(...)` for live limit
orders. It derives the deposit wallet from the connected EOA, prompts the
app-owned `WalletSigner` for the ERC-7739 typed-data approval, and posts
`signatureType=3`.

For a `needsFunding` result, call `planEoaPusdFundingRoute(...)`. It reads the
EOA pUSD balance and returns the direct wallet transaction request for
`pUSD.transfer(depositWallet, amount)` when funds are available.

After your wallet provider submits that transaction, pass its hash to
`waitForDepositWalletFundingReadiness(...)`. Polydart waits for the receipt and
then refreshes readiness until CLOB collateral is `ready` or the confirmation
status reports that the transaction is still pending, failed, or another
readiness action remains.
