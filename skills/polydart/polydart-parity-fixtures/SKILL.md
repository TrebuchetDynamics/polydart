---
name: polydart-parity-fixtures
description: Create, update, and review Polydart cross-language parity fixtures. Use when changing shared vectors for EIP-712, POLY_1271, ERC-7739, CREATE2, wallet batches, HMAC, order books, pagination, or Gamma/Data API normalization.
---

# Polydart Parity Fixtures

Parity fixtures are protocol contracts, not convenience snapshots.
Follow the shared operating model in `../references/operating-model.md`.

## Workflow

1. Record Polydart and Polygolem commits.
2. Generate or inspect the source vector in canonical `polygolem/` first.
3. Store deterministic inputs and expected outputs, not environment secrets.
4. Add or update Dart tests that explain which Polygolem command, test, or
   source file produced the vector.
5. Keep live network responses out of default fixtures unless they are reduced
   to stable sanitized examples.

## Fixture Types

Use parity fixtures for:

- CREATE2 deposit-wallet addresses.
- EIP-712 order and wallet-batch hashes.
- POLY_1271 signature type bytes.
- ERC-7739 wrapped contents and lengths.
- CLOB L1/L2 HMAC canonical bodies and headers.
- Gamma/Data API tolerant decoding examples.
- Order book aggregation, pagination, and numeric-string behavior.

Never edit Polygolem fixture generators locally. If upstream generation is
wrong, record the contradiction and keep the upstream checkout clean.

## Verification

Run the focused parity tests first, then:

```sh
dart analyze --fatal-warnings
dart test --reporter=expanded
```

If a fixture changes because Polygolem changed, mention the Polygolem commit in
the test comment, changelog, or implementation note.
