# polydart

Dart-native Polymarket SDK — peer implementation to [polygolem](https://github.com/TrebuchetDynamics/polygolem).

> **Status:** pre-alpha. APIs unstable. Not yet published to pub.dev.

## What it is

A spec-for-spec mirror of polygolem in Dart. Brings the full Polymarket protocol stack (CLOB, Gamma, Data API, Builder relayer, deposit-wallet lifecycle, EIP-712 / POLY_1271 / ERC-7739 signing, paper mode, risk gates) to Dart and Flutter.

## Documents

- `docs/PRD.md` — product requirements
- `docs/PLAN.md` — implementation plan
- `CHANGELOG.md` — release log

## Mirror commitment

Polygolem is the reference. Every protocol module, signing scheme, and API client in polygolem has a Dart twin here. Versions track in lockstep.

## License

MIT. See `LICENSE`.
