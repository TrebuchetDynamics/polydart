# polydart

Dart-native Polymarket SDK — peer implementation to [polygolem](https://github.com/TrebuchetDynamics/polygolem).

> **Status:** alpha. APIs unstable; live trading paths are explicit,
> wallet-mediated, and gated.

## What it is

A spec-for-spec mirror of polygolem in Dart. Polydart currently provides
tested public market reads, Data API reads, paper-mode primitives,
wallet-mediated signing helpers, guarded CLOB write helpers, stream clients,
and relayer/readiness building blocks for Dart and Flutter applications.

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

## Quick start (read-only)

```dart
import 'package:polydart/polydart.dart';

Future<void> main() async {
  final client = Polydart.readOnly();
  // Search Gamma.
  final search = await client.gamma.search(
    const SearchParams(query: 'btc 5m', limitPerType: 5),
  );
  // Resolve a market slug to token ids.
  final resolved = await client.resolver.resolveBySlug('btc-100k-eoy');
  // Enrich a market with CLOB data (tick size, midpoint, spread, book).
  if (search.events.isNotEmpty) {
    final m = search.events.first.markets.first;
    final enriched = await client.discovery.enrichMarket(m);
    print('midpoint=${enriched.midpoint}');
  }
  client.close();
}
```

Run the bundled example:

```sh
dart run example/read_only.dart
```

## Flutter app readiness

Polydart is a Dart package that can be consumed by Flutter apps without adding
Flutter as a dependency to Polydart itself. See
[`docs/FLUTTER-APP-READINESS.md`](https://github.com/TrebuchetDynamics/polydart/blob/main/docs/FLUTTER-APP-READINESS.md)
for install snippets, platform notes, lifecycle guidance, read-only usage, and
the `WalletSigner` adapter pattern.

## Modes

| Factory | Mode | Wallet | Live writes |
|---------|------|--------|-------------|
| `Polydart.readOnly()` | `readOnly` | none | blocked |
| `Polydart.paper(eoaAddress: ...)` | `paper` | EOA only | simulated |
| lower-level live clients | `live` | app-owned `WalletSigner` | explicitly gated |

Risk gates (`requireLive`, `requirePaperOrLive`) refuse calls that don't
match the active mode and require `liveTradingEnabled=true` for any real
order submission.

The package root currently exposes `Polydart.readOnly()` and
`Polydart.paper(...)`. Live paths are available through lower-level clients and
must be wired by the application with wallet-mediated user approval, explicit
live configuration, confirmation, and preflight checks.

## Documents

- [Product requirements](https://github.com/TrebuchetDynamics/polydart/blob/main/docs/PRD.md)
- [Implementation plan](https://github.com/TrebuchetDynamics/polydart/blob/main/docs/PLAN.md)
- [Deposit-wallet readiness checklist](https://github.com/TrebuchetDynamics/polydart/blob/main/docs/DEPOSIT-WALLET-READINESS-CHECKLIST.md)
- [Flutter integration notes](https://github.com/TrebuchetDynamics/polydart/blob/main/docs/FLUTTER-APP-READINESS.md)
- [Polygolem parity coverage](https://github.com/TrebuchetDynamics/polydart/blob/main/docs/POLYDART-POLYGOLEM-COVERAGE.md)
- `src/content/docs/` — Astro Starlight documentation source
- `CHANGELOG.md` — release log

Build the Starlight docs with:

```sh
npm ci
npm run build
```

## Mirror commitment

Polygolem is the reference. Every protocol module, signing scheme, and API client in polygolem has a Dart twin here. Versions track in lockstep.

Before any protocol-package work, refresh the upstream reference:

```sh
git -C polygolem pull --ff-only origin main
```

Then port from that fresh `polygolem` commit into Dart and update parity tests/fixtures with the commit hash used. Do not develop live CLOB, deposit-wallet, relayer, or signing behavior from memory or stale docs. Treat `polygolem/` as a read-only upstream reference.

## License

MIT. See `LICENSE`.
