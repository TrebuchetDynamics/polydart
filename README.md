# polydart

Dart-native Polymarket SDK — peer implementation to [polygolem](https://github.com/TrebuchetDynamics/polygolem).

> **Status:** alpha. APIs unstable; live trading paths are explicit,
> signer-mediated, and gated.

## What it is

A spec-for-spec mirror of polygolem in Dart. Polydart currently provides
tested public market reads, Data API reads, wallet intelligence research
helpers, paper-mode primitives, EOA signer helpers, guarded CLOB write helpers,
stream clients, and relayer/readiness building blocks for Dart and Flutter
applications.

## Install

If you are consuming a published release from pub.dev, use the package version for that release:

```yaml
dependencies:
  polydart: ^0.1.0-alpha.2
```

For the current repository state, use the public repository tag or a pinned commit:

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
the normal-app **EOA Signer with ReownWallet** adapter pattern.

## Modes

| Factory | Mode | Wallet | Live writes |
|---------|------|--------|-------------|
| `Polydart.readOnly()` | `readOnly` | none | blocked |
| `Polydart.paper(eoaAddress: ...)` | `paper` | EOA only | simulated |
| lower-level live clients | `live` | EOA Signer with ReownWallet (or explicit advanced signer) | explicitly gated |

Risk gates (`requireLive`, `requirePaperOrLive`) refuse calls that don't
match the active mode and require `liveTradingEnabled=true` for any real
order submission.

The package root currently exposes `Polydart.readOnly()` and
`Polydart.paper(...)`. Live paths are available through lower-level clients and
must be wired by the application with an EOA Signer with ReownWallet or an
equivalent wallet-provider signer, explicit live configuration, confirmation,
and preflight checks. `LocalEoaSigner` is available for special CLI/test,
headless, alpha-app, and server automation cases; generated no-sign-in keys
belong to paper-mode trials, not live custody.

## Documents

Start with the [end-user guide](https://github.com/TrebuchetDynamics/polydart/blob/main/docs/END-USER-GUIDE.md) for install choices, safe read-only usage, Flutter patterns, signer rules, and example paths.

User-facing references:

- [Flutter integration notes](https://github.com/TrebuchetDynamics/polydart/blob/main/docs/FLUTTER-APP-READINESS.md)
- [Deposit-wallet readiness checklist](https://github.com/TrebuchetDynamics/polydart/blob/main/docs/DEPOSIT-WALLET-READINESS-CHECKLIST.md)
- `CHANGELOG.md` — release log

Project/reference docs:

- [Product requirements](https://github.com/TrebuchetDynamics/polydart/blob/main/docs/PRD.md)
- [Implementation plan](https://github.com/TrebuchetDynamics/polydart/blob/main/docs/PLAN.md)
- [Polygolem parity coverage](https://github.com/TrebuchetDynamics/polydart/blob/main/docs/POLYDART-POLYGOLEM-COVERAGE.md)

## Mirror commitment

Polygolem is the older-brother reference. Every protocol module, signing scheme, API client, safety gate, fixture family, and user-facing feature in polygolem has a Dart twin here. Polydart keeps a similar layered architecture—clients, DTOs, signers, transport, safety gates, tests, and docs—while using Dart/Flutter-native package boundaries where platform or signer constraints differ. Versions track in lockstep.

Before any protocol-package work, refresh a local upstream reference checkout:

```sh
if [ -d polygolem/.git ]; then
  git -C polygolem pull --ff-only origin main
else
  git clone https://github.com/TrebuchetDynamics/polygolem.git polygolem
fi
```

Then port from that fresh `polygolem` commit into Dart and update parity tests/fixtures with the commit hash used. Do not develop live CLOB, deposit-wallet, relayer, or signing behavior from memory or stale docs. Treat any local `polygolem/` checkout as a read-only upstream reference.

## License

MIT. See `LICENSE`.
