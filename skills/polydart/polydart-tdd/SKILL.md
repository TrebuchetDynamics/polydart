---
name: polydart-tdd
description: Test-driven Polydart development using Dart package:test, fake transports, parity vectors, and strict analyzer feedback. Use when adding features, fixing bugs, porting Polygolem behavior, or changing public SDK behavior in Polydart.
---

# Polydart TDD

Use red-green-refactor with the narrowest reliable Dart test seam.
Follow the shared operating model in `../references/operating-model.md`.

## Red

1. Identify the behavior: public SDK, module unit, fake transport, parity
   fixture, or opt-in network read.
2. Write the failing test before implementation.
3. Prefer fake transports and deterministic fixtures over live endpoints.
4. For protocol parity, record the Polygolem commit that produced the expected
   behavior.

Every `missing` or `partial` code feature in the coverage matrix needs a red
test before implementation. Docs-only and skill-only changes use validation
instead of code TDD.

Good seams:

- `test/auth/*` for hashes, signatures, SIWE, CREATE2, and HMAC.
- `test/clob/*`, `test/gamma/*`, `test/dataapi/*` for API shape and decoding.
- `test/orders/*` for validation, rounding, and order placement.
- `test/wallet/*` and `test/relayer/*` for deposit-wallet workflows.

## Green

Implement only enough to satisfy the failing test. Keep live writes behind mode
gates and `liveTradingEnabled`.

Run the focused test:

```sh
dart test path/to/test.dart --reporter=expanded
```

## Refactor

Run:

```sh
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-warnings
dart test --reporter=expanded
```

Use `dart test --tags network` only for explicit live read smoke tests. Never
make network or live-write behavior part of the default test path.
