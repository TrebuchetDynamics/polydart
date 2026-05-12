---
name: polydart-api-client
description: Add or change Polydart Polymarket API clients and endpoint methods. Use when implementing Gamma, CLOB, Data API, relayer, stream, bridge, settlement, or market-discovery wire behavior.
---

# Polydart API Client

Match Polygolem wire behavior while keeping Dart clients idiomatic and testable.
Follow the shared operating model in `../references/operating-model.md`.

## Before Coding

1. Find the Polygolem source endpoint and tests.
2. Find the matching Polydart module under `lib/src/*`.
3. Identify whether the endpoint is read-only, paper-only, or live-write.
4. For live writes, invoke protocol-safety checks before implementation.
5. Add a red test through `polydart-tdd` before changing code.

## Implementation Rules

- Test path, method, query params, repeated keys, body shape, headers, and
  response decoding with fake transports.
- Keep tolerant decoders close to API clients when upstream payloads are messy.
- Preserve numeric strings when precision matters.
- Do not silently drop response fields that Polygolem exposes.
- Keep pagination semantics explicit: cursor, offset, page size, and stop
  conditions.
- Keep network tests tagged and opt-in.
- Update `docs/POLYDART-POLYGOLEM-COVERAGE.md` when endpoint parity status
  changes.

## Common Drift Points

Watch for:

- snake_case versus camelCase response fields.
- string-or-number values.
- string-or-array fields.
- wrapped response envelopes.
- empty list versus missing field behavior.
- compact JSON bodies for HMAC or signing.

## Verification

Run the focused endpoint test and then `dart analyze --fatal-warnings`.
