# polydart

Dart-native Polymarket SDK — peer implementation to [polygolem](https://github.com/TrebuchetDynamics/polygolem).

> **Status:** pre-alpha. APIs unstable. Not yet published to pub.dev.

## What it is

A spec-for-spec mirror of polygolem in Dart. Brings the full Polymarket protocol stack (CLOB, Gamma, Data API, Builder relayer, deposit-wallet lifecycle, EIP-712 / POLY_1271 / ERC-7739 signing, paper mode, risk gates) to Dart and Flutter.

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

## Modes

| Factory | Mode | Wallet | Live writes |
|---------|------|--------|-------------|
| `Polydart.readOnly()` | `readOnly` | none | blocked |
| `Polydart.paper(eoaAddress: ...)` | `paper` | EOA only | simulated |
| `Polydart.live(...)` | `live` | Reown / WalletSigner | real (Phase 2) |

Risk gates (`requireLive`, `requirePaperOrLive`) refuse calls that don't
match the active mode and require `liveTradingEnabled=true` for any real
order submission.

## Documents

- `docs/PRD.md` — product requirements
- `docs/PLAN.md` — implementation plan
- `CHANGELOG.md` — release log

## Mirror commitment

Polygolem is the reference. Every protocol module, signing scheme, and API client in polygolem has a Dart twin here. Versions track in lockstep.

## License

MIT. See `LICENSE`.
