---
name: polydart-protocol-safety
description: Review and implement Polydart live-trading safety boundaries. Use when work touches orders, relayer calls, deposit-wallet lifecycle, signing, credential handling, paper mode, risk gates, or any possible live write.
---

# Polydart Protocol Safety

Default to read-only. Treat any signing, relayer, order, approval, funding, or
cancel behavior as live-risk work until proven otherwise.
Follow the shared operating model in `../references/operating-model.md`.

## Non-Negotiables

- No private keys in source, tests, logs, fixtures, prompts, or examples.
- No SDK-owned raw EOA private-key storage in the default public SDK signing
  architecture.
- EOA authority flows through `WalletSigner` or consumer-provided
  wallet-mediated approval.
- Live writes require `PolydartMode.live` and `liveTradingEnabled=true`.
- Paper mode is local simulation only.
- Read-only mode never signs, submits, approves, funds, or cancels.
- Do not retry non-idempotent live writes after uncertain failures.
- Redact CLOB credentials, builder credentials, relayer API keys, and HMAC
  material.

## Review Checklist

Check affected code for:

- `requireLive` or equivalent gates on every live write.
- Clear separation between CLOB L2 auth, builder attribution code, builder
  relayer credentials, and Relayer V2 API keys.
- Deposit-wallet semantics: `signatureType=3`, deposit wallet signer/maker,
  pUSD on the deposit wallet, and ERC-7739 wrapping where required.
- Fake-transport tests for write paths.
- No default test or example that places a live order.
- No secret-bearing values in `toString`, errors, debug output, or snapshots.
- No code path that asks for, stores, logs, derives from, or transmits a raw
  EOA private key.

## Escalate

Stop and ask the user before running anything that could deploy, approve, fund,
place, cancel, or submit to a live upstream service.
Stop implementation entirely when custody, signer/maker/funder separation,
mode gates, or redaction cannot be proven from code and tests.
