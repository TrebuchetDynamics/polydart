---
title: Credential Boundaries
description: Keep wallet signatures, browser cookies, relayer keys, and live submission credentials behind explicit application-owned boundaries.
sidebar:
  order: 4
---

Polydart separates signing authority, cookie-backed SIWE sessions, relayer API keys, and live write access. Treat those as distinct contracts so an application can audit where each credential is created, stored, and used.

## Boundary Contracts

| Boundary | Polydart contract | Application responsibility |
| --- | --- | --- |
| Wallet signatures | `WalletSigner` | Own wallet sessions, account selection, chain switching, and user prompts. |
| SIWE cookie session | `SIWESession` | Run in a Dart VM, mobile, desktop, test, backend, or proxy context that can read `Set-Cookie` and send `Cookie` headers. |
| Relayer API key | `CredentialStore` with `LiveCredentialService.ensure()` | Store minted keys through an app-owned store and avoid exposing them to browser JavaScript. |
| Live writes | `LiveGateInput`, `LiveGateResult`, and `requireLive()` | Make environment, configuration, user confirmation, and preflight checks pass before write paths are reachable. |

## Browser Cookie Boundary

Browser JavaScript cannot read `Set-Cookie` headers or manually send `Cookie` headers. Flutter Web apps should keep wallet prompts in the frontend and put cookie-backed SIWE or relayer-key minting behind a backend/proxy boundary unless they provide a browser-native credential flow approved by the upstream service.

VM, mobile, desktop, tests, and backend/proxy code can use the cookie-backed helpers directly because those runtimes can preserve the session cookie needed to mint a Relayer V2 API key.

## Relayer Key Storage

`LiveCredentialService.ensure()` asks the app-provided `WalletSigner` for SIWE `personal_sign`, captures the session cookie, mints the relayer key, and stores the result only through the app-provided `CredentialStore`.

```dart
import 'package:polydart/polydart.dart';

Future<RelayerCredentials> ensureRelayerCredentials({
  required LiveCredentialService credentials,
  required WalletSigner signer,
}) {
  return credentials.ensure(signer: signer);
}
```

Do not treat a relayer key as a wallet key. It authorizes relayer API requests, so keep it scoped to the application-owned live path and rotate or discard it with the same care as other API credentials.

## Submission Boundary

Credential creation does not imply permission to submit live writes. Pair any relayer-backed submission path with [live safety gates](/protocol-safety/live-safety-gates/) and keep the wallet flow described in [wallet-mediated signing](/protocol-safety/wallet-signing/) as the only place user signatures are requested.
