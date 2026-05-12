---
name: polydart-polygolem-fidelity
description: Own completion of Polygolem features in Polydart and keep behavior faithful to upstream Polygolem. Use when syncing upstream Polygolem, inventorying missing features, porting Go behavior to Dart, comparing protocol surfaces, updating parity tests, reviewing API drift, or deciding whether a Dart divergence is intentional.
---

# Polydart Polygolem Fidelity

Polygolem is the semantic source of truth. This skill owns the work of making
Polydart complete against Polygolem: discover every upstream feature, classify
what is missing, port it to Dart, and prove parity with tests.
Follow the shared operating model in `../references/operating-model.md`.

## Start

Pull upstream Polygolem first unless the user explicitly asked for a specific
commit or offline comparison:

```sh
git -C polygolem pull --ff-only origin main
```

Record local and upstream commits after syncing:

```sh
git rev-parse --short HEAD
git -C polygolem rev-parse --short HEAD
```

If the pull fails, stop and report the failure before doing fidelity work.
Never edit, patch, or commit inside `polygolem/`.

## Completion Mandate

For each upstream Polygolem release or main-branch sync:

1. Inventory all stable `pkg/*`, protocol-critical `internal/*`, CLI-exposed
   behavior, docs, tests, and changelog entries.
2. Map each feature to Polydart: `implemented`, `partial`, `missing`,
   `intentional Dart divergence`, or `not applicable`.
3. Turn every `missing` or `partial` feature into a concrete Polydart task with
   module path, tests, fixtures, safety checks, and upstream commit.
4. Implement Polydart features until the inventory has no unexplained gaps.
5. Keep the inventory current when Polygolem changes again.

Use `../scripts/polygolem_inventory.py` to scaffold the inventory. Maintain
`docs/POLYDART-POLYGOLEM-COVERAGE.md` as the canonical matrix. Route concrete
work to specialist skills using the operating-model routing table.

## Source Priority

When Polygolem sources disagree, prefer:

1. Code and tests.
2. Changelog and live-capture notes.
3. Architecture, safety, and contract docs.
4. Older narrative docs.

Flag contradictions instead of copying them into Dart.

## Fidelity Checklist

Verify:

- Module mapping from `internal/*` or `pkg/*` to `lib/src/*`.
- Public names, DTOs, enum labels, JSON field casing, and error codes.
- Deposit-wallet-only live semantics: `signatureType=3`,
  `maker=signer=depositWallet`, pUSD routing, and ERC-7739 wrapping.
- Credential separation: CLOB L1/L2 auth, builder code, builder credentials,
  and relayer API keys are not collapsed.
- API wire behavior: paths, methods, query params, compact JSON bodies,
  pagination, response casing, retries, and batch limits.
- Order behavior: side/type normalization, tick validation, rounding,
  expiration, post-only rules, cancel limits, and liquidity failures.
- Tests: each protocol-critical behavior has a Polygolem-backed vector or
  fake-transport test; network tests stay opt-in.
- ADRs: intentional Dart divergences, especially wallet-mediated EOA signing,
  override blind Polygolem porting.

## Output

Classify each difference as `blocker`, `parity gap`, or `intentional Dart
divergence`, and record the Polygolem commit used.
When a gap is code-related, produce a red-test-first task stub instead of a
free-form note.
