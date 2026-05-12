# ADR 0001: Wallet-Mediated EOA Signing

## Status

Accepted

## Context

Polydart is a public Dart SDK that mirrors Polygolem protocol semantics for
Polymarket clients. Polygolem may use local private keys in CLI or server
contexts, but Flutter and mobile consumers need a safer default custody model.
Future agents porting from Polygolem could accidentally copy local-key custody
patterns into Polydart unless the boundary is explicit.

## Decision

Polydart's default public SDK signing architecture must not handle raw EOA
private keys.

EOA authority flows through consumer-provided wallet signing abstractions, such
as `WalletSigner`, and user-approved signing flows. `WalletSigner` may request
signatures, but it must not expose key material.

Polygolem local-key behavior is a protocol-byte reference for hashes, typed
data, request bodies, and signatures. It is not the custody architecture for
Polydart.

Private-key signer support, if ever added, requires a separate explicit design
decision outside the default public SDK flow.

## Consequences

- Signing parity tests use fake signers, public vectors, or sanitized fixtures.
- Code paths that ask for, store, log, derive from, or transmit raw EOA private
  keys are blockers.
- Protocol parity and custody parity are separate concerns.
- ADRs override blind Polygolem porting when Dart product constraints differ.
