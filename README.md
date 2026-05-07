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
  final result = await client.gamma.search(
    const SearchParams(query: 'btc 5m', limitPerType: 5),
  );
  print('${result.events.length} events');
  client.close();
}
```

Run the bundled example:

```sh
dart run example/read_only.dart
```

## Documents

- `docs/PRD.md` — product requirements
- `docs/PLAN.md` — implementation plan
- `CHANGELOG.md` — release log

## Mirror commitment

Polygolem is the reference. Every protocol module, signing scheme, and API client in polygolem has a Dart twin here. Versions track in lockstep.

## License

MIT. See `LICENSE`.
