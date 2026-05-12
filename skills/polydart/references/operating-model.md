# Polydart Skill Operating Model

Polydart skills are repo-local and form a coordinated workflow system. Their
job is to drive the public Polydart SDK toward complete, tested Polygolem
protocol parity while preserving Dart and Flutter/mobile safety constraints.

## Public Repo Language

Do not introduce non-public deployment, customer, or alpha-program names
into public repo artifacts. Use public terms such as `consumer app`,
`Flutter/mobile consumer`, `public SDK`, `WalletSigner`, and `wallet-mediated
signing`.

## Upstream Sources

- `polygolem/` is the canonical upstream submodule.
- The upstream checkout is a read-only reference.
- Allowed operations: read files, run tests/tools, `git fetch`, and
  `git pull --ff-only`.
- Forbidden operations: edit files, apply patches, commit, or locally "fix"
  upstream behavior in the checkout.

Before fidelity work:

```sh
git -C polygolem pull --ff-only origin main
```

If upstream code and docs disagree, prefer code/tests, then changelog and live
capture notes, then architecture/safety/contract docs, then older narrative
docs. ADRs in `docs/adr/` override Polygolem for intentional Dart product
divergences.

## Skill Routing

| Work type | Route |
|---|---|
| Upstream sync, missing feature inventory, coverage matrix | `polydart-polygolem-fidelity` |
| Ambiguous API, custody, release, or product decision | `polydart-grill-me` |
| Endpoint, DTO, pagination, stream, or wire gap | `polydart-api-client` + `polydart-tdd` |
| Hash, typed data, HMAC, SIWE, CREATE2, or signature gap | `polydart-crypto-signing` + `polydart-parity-fixtures` + `polydart-tdd` |
| Live write, wallet, relayer, order, approval, funding, bridge | `polydart-protocol-safety` first |
| Version, changelog, pub.dev, release readiness | `polydart-release` |
| Submodule, staging, commit slicing | `polydart-git` |
| Skill-pack changes | `polydart-skill-manager` |

## Coverage Matrix

The canonical matrix is `docs/POLYDART-POLYGOLEM-COVERAGE.md`. Status values:

- `implemented`
- `partial`
- `missing`
- `intentional Dart divergence`
- `not applicable`

A feature is `implemented` only when matching Dart behavior, public API/export
story, tests or fixtures, safety gates where relevant, user docs where needed,
and the Polygolem source commit are all accounted for.

## Safety Invariants

- The default public SDK signing architecture must not handle raw EOA private
  keys.
- EOA authority flows through consumer-provided wallet signing abstractions and
  user-approved signing flows.
- `WalletSigner` can request signatures; it must not expose key material.
- Polygolem local-key behavior is a protocol-byte reference, not the custody
  architecture for Polydart.
- Private-key signer support, if ever added, requires a separate explicit
  design decision outside the default public SDK flow.
- Live writes require live mode and explicit live-trading enablement.
- Paper mode remains local simulation only.
- Default tests and examples must not perform live writes.

## Verification Defaults

Use focused tests first, then:

```sh
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-warnings
dart test --reporter=expanded
```

Use `dart test --tags network` only for explicit live read smoke checks.
