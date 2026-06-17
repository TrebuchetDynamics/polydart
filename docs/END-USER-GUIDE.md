# Polydart End-User Guide

Use this guide when you want to consume Polydart from a Dart or Flutter app. It avoids project-planning detail and focuses on safe first steps.

## Current Status

Polydart is an alpha SDK. Public reads, paper-mode helpers, signer seams, and guarded protocol building blocks are available; APIs may still change before a stable release. Live trading paths are explicit, signer-mediated, and safety-gated.

## Install

If you are consuming a published release from pub.dev, use the package version for that release:

```yaml
dependencies:
  polydart: ^0.1.0-alpha.2
```

For the current repository state, pin the Git repository or a specific commit/tag:

```yaml
dependencies:
  polydart:
    git:
      url: https://github.com/TrebuchetDynamics/polydart.git
      ref: main # prefer a release tag or commit SHA for apps
```

For local app development against a checkout:

```yaml
dependencies:
  polydart:
    path: ../polydart
```

Then run `dart pub get` or `flutter pub get` from your app.

## Choose Your First Path

| Goal | Start here | Notes |
| --- | --- | --- |
| Read public markets from Dart | `dart run example/read_only.dart` | No wallet or credentials required. |
| Use Polydart from Flutter | [`docs/FLUTTER-APP-READINESS.md`](FLUTTER-APP-READINESS.md) | Polydart has no Flutter dependency; your app owns lifecycle and storage. |
| Build a Flutter read-only repository | [`example/flutter_read_only.dart`](../example/flutter_read_only.dart) | Plain Dart pattern for Provider, Riverpod, bloc, or `State`. |
| Adapt Reown/WalletConnect signing | [`example/flutter_wallet_signer.dart`](../example/flutter_wallet_signer.dart) | Skeleton for `WalletSigner`; no private keys. |
| Smoke-test deposit-wallet order signing | [`example/flutter_deposit_wallet_order.dart`](../example/flutter_deposit_wallet_order.dart) | Mock-only; no live endpoints, funds, or submissions. |

## Read-Only Quick Start

```dart
import 'package:polydart/polydart.dart';

Future<void> main() async {
  final client = Polydart.readOnly();
  try {
    final search = await client.gamma.search(
      const SearchParams(query: 'btc', limitPerType: 3),
    );

    final firstEvent = search.events.isEmpty ? null : search.events.first;
    final firstMarket = firstEvent?.markets.isNotEmpty ?? false
        ? firstEvent!.markets.first
        : null;
    if (firstMarket == null) return;

    final resolved = await client.resolver.resolveBySlug(firstMarket.slug);
    final tokenId = resolved?.tokenIds.isEmpty ?? true
        ? null
        : resolved!.tokenIds.first;
    if (tokenId == null) return;

    final midpoint = await client.clob.midpoint(tokenId);
    print('${firstMarket.question}: midpoint=$midpoint');
  } finally {
    client.close();
  }
}
```

## Operating Modes

| Mode | How to enter | Intended use | Live writes |
| --- | --- | --- | --- |
| Read-only | `Polydart.readOnly()` | Market discovery, CLOB reads, streams, analytics reads | Blocked |
| Paper | `Polydart.paper(eoaAddress: ...)` | Local simulation and no-sign-in trials | Simulated only |
| Live | Lower-level live clients plus explicit config | App-owned wallet/provider signing and guarded protocol mutation | Requires live mode, live flag, credentials, confirmation, and preflight |

## Wallet and Live-Safety Rules

- Normal Flutter/mobile/web apps should use an EOA Signer with ReownWallet, WalletConnect, or an equivalent wallet-provider adapter.
- Do not store raw private keys, seed phrases, or funded wallet secrets in app code, examples, assets, or logs.
- `LocalEoaSigner` exists for CLI tests, headless/server automation, alpha/test apps, and paper-mode trials; it is not the normal Flutter live path.
- Generated paper wallets must not be upgraded into live custody.
- Live trading, approvals, transfers, and wallet deployment are safety-gated mutations. Keep them behind explicit app-level user intent and confirmation.

## Relayer and Deposit-Wallet Live UX Checklist

For live deposit-wallet flows, keep the user-facing sequence explicit:

1. Connect an EOA signer and verify Polygon mainnet (`chainId == 137`).
2. Ensure credentials with `LiveCredentialService.ensure(...)`: CLOB L2 key,
   builder-fee key, and Relayer V2 API key are distinct credentials.
3. Check readiness with `DepositWalletReadinessService.checkWithCredentials(...)`.
4. If readiness reports deploy, approval, or funding work, show that action to
   the user before any mutation. Polydart returns typed states; the app owns
   labels, warnings, storage, and confirmations.
5. Only after readiness is `ready`, build/sign/submit a live order through an
   explicit live path with the app-owned wallet signer and live-trading flag.

Flutter Web cannot directly mint Relayer V2 credentials through the current
SIWE cookie flow because browsers do not expose `Set-Cookie` or allow arbitrary
`Cookie` headers to app code. Use VM/mobile/desktop credential flows or an
app-owned backend/proxy boundary for web.

## More Reference Docs

- Flutter integration: [`docs/FLUTTER-APP-READINESS.md`](FLUTTER-APP-READINESS.md)
- Deposit-wallet readiness: [`docs/DEPOSIT-WALLET-READINESS-CHECKLIST.md`](DEPOSIT-WALLET-READINESS-CHECKLIST.md)
- Protocol parity: [`docs/POLYDART-POLYGOLEM-PARITY.md`](POLYDART-POLYGOLEM-PARITY.md)
- Product and planning docs: [`docs/PRD.md`](PRD.md), [`docs/PLAN.md`](PLAN.md)
