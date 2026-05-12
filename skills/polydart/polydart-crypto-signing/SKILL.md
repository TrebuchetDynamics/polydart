---
name: polydart-crypto-signing
description: Port and review Polydart cryptographic signing behavior. Use when changing EIP-712, POLY_1271, ERC-7739, CREATE2, SIWE, CLOB L1/L2 auth, HMAC canonicalization, wallet batch signing, or deposit-wallet signing.
---

# Polydart Crypto Signing

Treat signing changes as high risk. A compiling implementation can still be
protocol-wrong.
Follow the shared operating model in `../references/operating-model.md`.

## Required Inputs

Before implementation, identify:

- Polygolem source file and test/vector.
- Chain id and verifying contract.
- Exact EIP-712 domain, primary type, field order, and numeric encoding.
- Whether the signer is EOA, deposit wallet, relayer key, or CLOB API key.
- Expected output hash, signature, header, address, or wrapped payload.
- Whether the change conflicts with `docs/adr/0001-wallet-mediated-eoa-signing.md`.

## Rules

- Add or update a failing parity test first.
- Keep body compaction stable for HMAC inputs.
- Preserve hex casing and `0x` handling deliberately.
- Verify `contentsType` and ERC-7739 wrap lengths byte-for-byte.
- Verify `signatureType=3` for POLY_1271 order signing.
- Do not implement Flutter/mobile signing by adding raw EOA private-key custody.
  Use `WalletSigner`, fake signers, and public vectors.
- Never add tests that require a real private key.
- Never log signatures, private material, HMAC secrets, or relayer keys.

## Useful Commands

```sh
dart run tool/compute_typehash.dart
dart run tool/compute_hmac.dart
dart test test/auth --reporter=expanded
dart test test/orders --reporter=expanded
dart test test/wallet --reporter=expanded
```

If Dart and Go disagree, assume the fixture, field order, or encoding is wrong
until the exact byte-level input is compared.
