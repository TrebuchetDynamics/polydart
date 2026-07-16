# Polydart

Dart-native Polymarket SDK for Dart, Flutter, web, CLI, and server apps.
Polydart is the Dart peer of [polygolem](https://github.com/TrebuchetDynamics/polygolem): it mirrors Polymarket protocol surfaces while keeping Dart/Flutter ergonomics, explicit signer boundaries, and safety-gated mutation paths.

> **Status:** alpha-ready, not finished. Public reads, paper-mode, and guarded protocol-building blocks are available now; Polydart is not yet a stable production-live-trading SDK. APIs may change before a stable release. Live trading paths are explicit, signer-mediated, and gated.

## Capability taxonomy

[`capabilities.json`](capabilities.json) shares operation IDs and semantics with
Polyrover, using Polymarket CLI commit `9b18b5f` as a read-only naming
reference. Its statuses are `implemented`, `dtoOnly`, `unsupported`, and
`planned`. Taxonomy parity does not imply implementation parity. Polygolem
remains the protocol-behavior reference for authenticated and execution work.

## What you can build today

- Read public Gamma markets, events, profiles, tags, curated Polymarket category feeds, and search results.
- Read CLOB books, prices, spreads, trades, tick sizes, and market metadata.
- Read Data API positions, trades, holders, open interest, leaderboards, and wallet intelligence.
- Read Polygon Chainlink USD price feeds for supported assets.
- Build Flutter read-only repositories without adding Flutter as a dependency to Polydart.
- Use paper-mode primitives and read-only order-book simulation for local no-funds experiments.
- Prepare deposit-wallet, relayer, funding, approval, settlement, order-result, and POLY_1271 market-order preview flows with typed safety checks.
- Integrate wallet-provider signing through `WalletSigner` adapters such as ReownWallet / WalletConnect.

## Install

Published release:

```yaml
dependencies:
  polydart: ^0.1.0-alpha.2
```

Pinned Git release or commit:

```yaml
dependencies:
  polydart:
    git:
      url: https://github.com/TrebuchetDynamics/polydart.git
      ref: v0.1.0-alpha.2
```

Local checkout while developing an app:

```yaml
dependencies:
  polydart:
    path: ../polydart
```

Then run:

```sh
dart pub get
# or: flutter pub get
```

## Quick start: read public markets

```dart
import 'package:polydart/polydart.dart';

Future<void> main() async {
  final client = Polydart.readOnly();
  try {
    final search = await client.gamma.search(
      const SearchParams(query: 'btc', limitPerType: 3),
    );

    final firstEvent = search.events.isEmpty ? null : search.events.first;
    final firstMarket = firstEvent?.markets.isNotEmpty ?? false
        ? firstEvent!.markets.first
        : null;
    if (firstMarket == null) return;

    final resolved = await client.resolver.resolveBySlug(firstMarket.slug);
    final tokenId = resolved?.tokenIds.isEmpty ?? true
        ? null
        : resolved!.tokenIds.first;
    if (tokenId == null) return;

    final midpoint = await client.clob.midpoint(tokenId);
    print('${firstMarket.question}: midpoint=$midpoint');
  } finally {
    client.close();
  }
}
```

Run the bundled read-only example:

```sh
dart run example/read_only.dart
```

## Choose your integration path

| Goal | Start here | Safety profile |
| --- | --- | --- |
| Read public markets from Dart | `dart run example/read_only.dart` | No wallet or credentials. |
| Use Polydart in Flutter | [`docs/FLUTTER-APP-READINESS.md`](docs/FLUTTER-APP-READINESS.md) | App owns lifecycle, state, and storage. |
| Build a Flutter read-only repository | [`example/flutter_read_only.dart`](example/flutter_read_only.dart) | No wallet required. |
| Adapt Reown/WalletConnect signing | [`example/flutter_wallet_signer.dart`](example/flutter_wallet_signer.dart) | Wallet-provider signer; no private keys in app code. |
| Smoke-test deposit-wallet order signing | [`example/flutter_deposit_wallet_order.dart`](example/flutter_deposit_wallet_order.dart) | Mock-only; no live funds or submissions. |
| Understand live deposit-wallet readiness | [`docs/DEPOSIT-WALLET-READINESS-CHECKLIST.md`](docs/DEPOSIT-WALLET-READINESS-CHECKLIST.md) | Explicit deploy/approval/funding states. |
| Study random private-key smart-wallet E2E | [`docs/RANDOM-PRIVATE-KEY-SMART-WALLET-E2E.md`](docs/RANDOM-PRIVATE-KEY-SMART-WALLET-E2E.md) | Default mocked; live relayer proof is opt-in only. |

## Operating modes

| Factory / path | Mode | Wallet | Live writes |
| --- | --- | --- | --- |
| `Polydart.readOnly()` | `readOnly` | none | blocked |
| `Polydart.paper(eoaAddress: ...)` | `paper` | EOA identity for simulation | simulated only |
| Lower-level live clients | `live` | app-owned EOA signer | requires live mode, live flag, credentials, confirmation, and preflight |

Risk gates such as `requireLive` and `requirePaperOrLive` reject calls that do not match the active mode. Real order submission also requires `liveTradingEnabled=true`.

## Wallet and live-safety rules

- Normal Flutter/mobile/web apps should use an EOA Signer with ReownWallet, WalletConnect, or an equivalent wallet-provider adapter.
- Do **not** store raw private keys, seed phrases, or funded wallet secrets in app code, examples, assets, or logs.
- `LocalEoaSigner` exists for CLI tests, headless/server automation, alpha/test apps, and paper-mode trials; it is not the normal Flutter live path.
- Generated paper wallets must not be upgraded into live custody.
- Live trading, approvals, transfers, and wallet deployment are safety-gated mutations. Keep them behind explicit app-level user intent and confirmation.

## Flutter notes

Polydart is plain Dart and does not depend on Flutter. Flutter apps can use it from Provider, Riverpod, bloc, `State`, or any other state model. Your app owns:

- wallet connection and session UX;
- secure storage choices for non-secret credentials;
- lifecycle (`client.close()` when no longer needed);
- user-facing confirmations for live actions;
- platform-specific browser/mobile constraints.

Start with [`docs/FLUTTER-APP-READINESS.md`](docs/FLUTTER-APP-READINESS.md).

## End-user docs

Start with the [end-user guide](docs/END-USER-GUIDE.md) for install choices, safe read-only usage, Flutter patterns, signer rules, and example paths.

User-facing references:

- [Flutter integration notes](docs/FLUTTER-APP-READINESS.md)
- [Deposit-wallet readiness checklist](docs/DEPOSIT-WALLET-READINESS-CHECKLIST.md)
- [Random private-key smart-wallet E2E](docs/RANDOM-PRIVATE-KEY-SMART-WALLET-E2E.md)
- [End-user guide](docs/END-USER-GUIDE.md)
- [Changelog](CHANGELOG.md)

Project/reference docs:

- [Product requirements](docs/PRD.md)
- [Implementation plan](docs/PLAN.md)
- [Polygolem parity coverage](docs/POLYDART-POLYGOLEM-COVERAGE.md)
- [Polydart ↔ Polygolem parity matrix](docs/POLYDART-POLYGOLEM-PARITY.md)

## For contributors: mirror commitment

Polygolem is the older-brother reference. Every protocol module, signing scheme, API client, safety gate, fixture family, and user-facing feature in polygolem has a Dart twin here. Polydart keeps a similar layered architecture—clients, DTOs, signers, transport, safety gates, tests, and docs—while using Dart/Flutter-native package boundaries where platform or signer constraints differ.

Before protocol-package work, refresh a local upstream reference checkout:

```sh
if [ -d polygolem/.git ]; then
  git -C polygolem pull --ff-only origin main
else
  git clone https://github.com/TrebuchetDynamics/polygolem.git polygolem
fi
```

Then port from that fresh `polygolem` commit into Dart and update parity tests/fixtures with the commit hash used. Do not develop live CLOB, deposit-wallet, relayer, or signing behavior from memory or stale docs. Treat any local `polygolem/` checkout as a read-only upstream reference.

## License

MIT. See [`LICENSE`](LICENSE).
