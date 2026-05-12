# Deposit Wallet Readiness Checklist

> Status: next implementation slice checklist, 2026-05-08.
> Scope: `polydart` package first; Flutter UI and live order placement later.

## Locked Decisions

- TDD always: one failing public-interface test, verify RED, minimal GREEN, then refactor.
- Pull the local Go reference before protocol work:

```sh
git -C polygolem pull --ff-only origin main
```

- Record the pulled `polygolem` commit in parity fixture or implementation notes.
- Implement the first slice in `polydart`, not in Flutter UI.
- Keep `polydart` pure Dart: no Flutter, Reown, secure-storage, or app-session dependency.
- Consumer Flutter apps store any local credentials safely, keyed by chain id and EOA.
- No separate adapter package now; keep Reown and secure-storage adapters app-local until the live flow works.
- Live trading comes before paper trading.
- Live Polymarket uses v2 deposit wallets only: `signature_type=3`.
- The EOA/Reown/social wallet is the controller signer; the deposit wallet is maker, funder, allowance owner, and buying-power account.
- Polygon mainnet only for the first real readiness slice; use fake transports and fixtures for tests.
- Normal tests use fake transports and parity fixtures. Live network tests are opt-in only.
- Server analytics registration is best-effort only and must never block local readiness.

## Credential Taxonomy

Do not collapse the credential names:

- CLOB L2 API key: created/derived via CLOB auth; used for authenticated CLOB reads/writes.
- CLOB builder-fee key: created via `/auth/builder-api-key`; used for fee attribution, not relayer submit.
- Relayer API key: used by relayer-v2 `/submit`; required for deposit-wallet deploy and approval batches.

Polydart owns credential discovery and creation protocol flows. CLOB L2
credentials, CLOB builder-fee keys, and Relayer V2 API keys are headless
protocol work in non-web Dart runtimes. Consumer apps still own secure
per-EOA storage through `CredentialStore`.

## Current Credential Discovery Slice

`LiveCredentialService.ensure(...)` is the first high-level credential
orchestration surface. It:

- reads an optional app-provided `CredentialStore`
- asks the app-provided `WalletSigner` for one ClobAuth signature
- creates CLOB L2 credentials through `/auth/api-key`
- falls back to `/auth/derive-api-key` with the same wallet-approved signature
- creates CLOB builder-fee credentials through `/auth/builder-api-key`
- asks for SIWE `personal_sign`, captures Gamma cookies, and mints Relayer V2
  credentials through `/relayer/api/auth`
- preserves partial success when CLOB credentials are ready but builder-fee
  or relayer credential creation is blocked
- returns typed readiness states instead of UI copy
- never stores credentials unless the app passes a store

Next live-readiness slices:

- deposit-wallet market-order pricing and live batch/cancel parity
- post-funding confirmation that deposit-wallet CLOB balance updated after a
  wallet-submitted pUSD transfer

## First Public API Target

Start with the product-facing readiness API, while preserving low-level protocol calls:

```dart
final credentials = await LiveCredentialService(...).ensure(signer: signer);
final readiness = await DepositWalletReadinessService.checkWithCredentials(
  eoaAddress: signer.address,
  credentials: credentials,
);
```

Initial machine-readable states:

- `needsDeploy`
- `needsApprovalCheck`
- `blocked`
- `needsApproval`
- `needsFunding`
- `ready`

The readiness object should include:

- `ownerEoa`
- `depositWallet`
- deployed state
- credential readiness provenance
- approval-check provenance
- required approval set
- missing approval set
- CLOB collateral balance/allowance using `signature_type=3`

First live order path:

- `createDepositWalletLimitOrder(...)` derives the deposit wallet from the EOA
  signer.
- The EOA signs the ERC-7739 `TypedDataSign` envelope through `WalletSigner`.
- The posted order uses `signatureType=3` and
  `maker == signer == depositWallet`.
- CLOB HMAC headers stay EOA-bound through `POLY_ADDRESS`.

First funding route:

- `planEoaPusdFundingRoute(...)` reads the owner's pUSD balance with
  `balanceOf(ownerEoa)`.
- `buildEoaPusdTransferPlan(...)` builds a direct wallet transaction:
  `to = pUSD`, `data = transfer(depositWallet, amount)`, `value = 0x0`.
- The route reports `ready`, `partial`, or `unavailable` and never submits the
  transaction. Flutter owns user approval and transaction submission.

Future tests should add:

- deposit-wallet pUSD balance
- post-transfer CLOB collateral refresh and transaction confirmation handling

No UI copy in `polydart`; Flutter owns labels, localization, and warnings.

## First TDD Tracer Bullet

First RED test:

`DepositWalletReadinessService.check returns needsDeploy for an EOA whose deposit wallet is derived but not deployed`

Use:

- fake relayer transport returning `deployed: false`
- parity fixture for deposit-wallet derivation
- no real network calls
- public readiness API only

Only after that passes, add the next behavior.

## Out Of Scope For First Readiness Tracer Bullet

- Live order placement.
- EOA to deposit-wallet pUSD transfer.
- Flutter readiness panel.
- Paper trading.
- Server Trader Intel or AI analysis.
- Server-side user signing or server custody.

## Acceptance

- `dart test` passes for the new readiness behavior.
- `dart analyze` is clean.
- No default test requires network access.
- No app/server code duplicates CLOB, relayer, deposit-wallet, POLY_1271, or ERC-7739 protocol logic outside `polydart`.
