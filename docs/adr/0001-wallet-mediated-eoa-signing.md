# ADR 0001: EOA Signer Compatibility

## Status

Accepted

## Context

Polydart is a public Dart SDK that mirrors Polygolem protocol semantics for
Polymarket clients. Polygolem may use local private keys in CLI or server
contexts, while Flutter, web, and mobile consumers often use wallet-provider
signing standards such as MetaMask, Reown / WalletConnect, or equivalent EOA
signer interfaces.

Some Polydart users also need local/private-key EOA signing for tests,
headless tools, and server-side automation. Future agents porting from
Polydart must preserve both needs without making one signer style block the
other.

## Decision

Polydart must accept standard EOA signer abstractions for browser/mobile wallet
flows, including MetaMask-style `eth_signTypedData_v4` / `personal_sign` and
Reown / WalletConnect-backed signers.

Polydart may also provide private-key EOA signer adapters for users who need
headless operation, local testing, or server-side automation. Private-key
support is allowed when it is explicit, opt-in, testable, and redacts key
material from diagnostics.

Protocol parity and signer-provider compatibility are both goals: Polygolem
local-key behavior remains a protocol-byte reference for hashes, typed data,
request bodies, and signatures, while Polydart should expose compatible EOA
signer seams for wallet-provider and private-key implementations.

## Consequences

- Signing parity tests may use fake signers, public vectors, sanitized
  fixtures, or explicit local/private-key signer adapters.
- Private-key APIs must be opt-in and must not log or expose raw key material.
- Wallet-provider EOA signing remains a first-class path for Flutter, web, and
  mobile consumers.
- Protocol parity and custody/provider choices are related but separable
  concerns.
- ADRs override blind Polygolem porting when Dart product constraints differ.
