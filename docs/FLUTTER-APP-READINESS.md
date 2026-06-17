# Flutter App Readiness

Polydart is consumable from a Flutter app as a normal Dart package. The
package does not depend on Flutter, does not import `package:flutter`, and does
not declare `sdk: flutter`.

Status for this repository snapshot:

- Dart SDK constraint: `>=3.10.0 <4.0.0`.
- Direct runtime dependencies are Dart packages: `collection`, `convert`,
  `crypto`, `http`, `meta`, `pointycastle`, and `web_socket_channel`.
- `lib/` has no direct `dart:io`, `dart:html`, `dart:ui`, `dart:ffi`, or
  `dart:mirrors` imports. It uses cross-platform Dart libraries such as
  `dart:async`, `dart:convert`, `dart:math`, and `dart:typed_data`.
- WebSockets use conditional platform adapters under
  `lib/src/stream/transport/`: the IO `web_socket_channel` adapter is selected
  on VM/mobile/desktop and the HTML adapter is selected on Flutter Web.

## Install in a Flutter App

If you are consuming a published release from pub.dev, use the package version for that release:

```yaml
dependencies:
  flutter:
    sdk: flutter
  polydart: ^0.1.0-alpha.2
```

For the current repository state, use the public repository tag or a pinned commit:

```yaml
dependencies:
  flutter:
    sdk: flutter

  polydart:
    git:
      url: https://github.com/TrebuchetDynamics/polydart.git
      ref: v0.1.0-alpha.2 # or pin a commit SHA
```

For a local checkout:

```yaml
dependencies:
  flutter:
    sdk: flutter

  polydart:
    path: ../polydart
```

Then run:

```sh
flutter pub get
```

## Platform Notes

Android, iOS, macOS, Windows, Linux, and Dart VM use the IO WebSocket adapter.
Flutter Web uses the browser WebSocket adapter. The public HTTP clients use
`package:http`, so the selected transport follows the app's compilation target.

Flutter Web remains subject to browser rules. CORS, CSP, blocked third-party
requests, and wallet-provider availability are controlled by the browser,
hosting setup, and upstream services. Polydart does not call `Platform.is...`
or require `dart:io` at runtime on the web path.

SIWE cookie login and Relayer V2 API-key minting are not browser-portable as
currently exposed: browsers do not expose `Set-Cookie` to application code and
do not allow arbitrary `Cookie` request headers. Use those flows from
VM/mobile/desktop runtimes where the HTTP client can manage headers directly,
or place a backend/proxy boundary in front of them for Flutter Web.

`LiveCredentialService.ensure()` now covers the VM/mobile/desktop flow end to
end: CLOB L2 credential create/derive, CLOB builder-fee key creation, SIWE
cookie login, and Relayer V2 API-key minting. Flutter apps should back
`CredentialStore` with secure per-EOA storage and still keep signing prompts
inside the app-provided wallet adapter.

After credentials are available, call
`DepositWalletReadinessService.checkWithCredentials(...)`. It builds the
Relayer V2 client from the relayer key, checks deploy state, verifies the six
V2 pUSD/CTF approvals, and reads CLOB `balance-allowance` with
`signature_type=3`. It returns `blocked`, `needsDeploy`,
`needsApprovalCheck`, `needsApproval`, `needsFunding`, or `ready` without
making the app infer protocol state from exceptions.

When readiness returns `ready`, use `createDepositWalletLimitOrder(...)` for
live limit orders, `createDepositWalletLimitOrders(...)` for batch limit
orders, or `createDepositWalletMarketOrder(...)` for buy market orders. These
helpers derive the deposit wallet from `signer.address`, ask the app-owned EOA
Signer with ReownWallet (adapted through `WalletSigner`) to approve each
ERC-7739 `TypedDataSign` payload, post `signatureType=3`, and keep private-key
signing out of the normal Flutter live path. Cancellations
use the same EOA-bound CLOB auth address through the `polyAddress` argument on
`ClobWrites`. If the CLOB rejects a write with a 4xx JSON body, Polydart throws
`ClobException` with `upstream` set to a `ClobErrorResponse` containing the
original status, code/type fields, message, details map, and raw body.

When readiness returns `needsFunding`, use `planEoaPusdFundingRoute(...)` to
read EOA-held pUSD and build the direct wallet transaction for
`pUSD.transfer(depositWallet, amount)`. The app must present that transaction
to the user and submit it through the wallet provider; Polydart only returns
the transaction request and full/partial/unavailable funding state.

After the wallet provider returns a transaction hash, call
`waitForDepositWalletFundingReadiness(...)`. It polls
`eth_getTransactionReceipt`, then refreshes deposit-wallet readiness until CLOB
collateral moves to `ready` or the returned
`DepositWalletFundingConfirmationStatus` says the transaction is still pending,
failed, or another readiness action remains. In the normal Flutter
wallet-provider path, Polydart still performs no wallet submission and stores no
private key material.

Signature flows assume Polygon mainnet unless a lower-level helper documents a
different chain. Wallet-backed signing should verify `chainId == 137` before
asking the user to sign Polymarket payloads.

## Lifecycle and Disposal

Do not create a Polydart client in a widget `build` method. Create it in a
repository, provider, bloc, service, or `State.initState`, then dispose it when
that owner is torn down.

- `Polydart.close()` closes the Gamma and CLOB HTTP transports it owns.
- `UniversalClient.close()` closes only clients it created internally.
- `MarketClient.close()` is async and closes the WebSocket, reconnect timer,
  subscription, and broadcast streams.

In Flutter, call `client.close()` from `dispose`. For streams, await
`marketClient.close()` from the owner that started the stream; if `dispose`
cannot be async, start cleanup without blocking UI teardown and handle errors in
that owner.

## Read-Only App Pattern

Use `Polydart.readOnly()` for screens that search markets, resolve slugs, show
order books, or display CLOB prices. This mode needs no wallet and does not
submit orders.

See [`example/flutter_read_only.dart`](../example/flutter_read_only.dart) for a
plain-Dart repository class that can be owned by a Flutter provider or widget
state.

## EOA Signer with ReownWallet Adapter Pattern

Normal Flutter app usage goes through an EOA Signer with ReownWallet or an
equivalent wallet-provider adapter. The Flutter app owns the actual wallet
integration and adapts ReownWallet, WalletConnect, embedded-wallet, hardware
bridge, or platform-channel RPC calls to Polydart's `WalletSigner` interface:

- `eth_signTypedData_v4` for EIP-712 typed data.
- `personal_sign` for SIWE and other EIP-191 messages.

The adapter must return a 65-byte secp256k1 signature with `v` normalized to 27
or 28. It should also verify the connected account and chain before prompting
the user.

See [`example/flutter_wallet_signer.dart`](../example/flutter_wallet_signer.dart)
for a compiling adapter skeleton. It deliberately has no Flutter imports and no
wallet package dependency; wire the `walletRequest` callback to the wallet SDK
used by the Flutter app.

For a mock-only deposit-wallet readiness plus limit-order smoke path, see
[`example/flutter_deposit_wallet_order.dart`](../example/flutter_deposit_wallet_order.dart).
It uses a fake wallet signer, mock CLOB/relayer transports, and mock RPC reads
so Flutter consumers can validate the readiness-to-`signatureType=3` order path
without live endpoints, funds, or product-specific code. The example checks
deploy state, approvals, CLOB collateral, and deposit-wallet pUSD balance before
posting the mock order. If an alpha app wants a no-sign-in trial, generate a
Paper Wallet for paper-mode only; do not upgrade that generated key into live
custody.

## Safety Boundaries

- Normal Flutter live flows should use an EOA Signer with ReownWallet or an
  equivalent wallet-provider adapter.
- Do not put raw private keys, seed phrases, or funded test secrets in Flutter
  code, assets, environment files, or examples. `LocalEoaSigner` is for CLI
  tests, alpha/test apps, headless users, server automation, and generated
  paper-mode wallets — not the normal Flutter live path.
- The bundled Flutter examples do not submit orders, cancel orders, fund
  wallets, transfer tokens, or request live API-key creation.
- `Polydart.readOnly()` has no wallet and live writes are blocked.
- `Polydart.paper(...)` is for simulated/paper workflows.
- Live trading code must use explicit live mode and the live-trading safety
  flag. Keep that wiring outside read-only UI examples and behind app-level
  user confirmation.

## Verification Used for This Readiness Pass

The current pass inspected:

```sh
rg -n "^import ['\"]dart:|^export ['\"]dart:|^part ['\"]dart:" lib
rg -n "dart:(io|html|js|js_interop|ffi|mirrors|ui)|package:flutter|sdk:\s*flutter|dependency_overrides|platforms:" lib pubspec.yaml analysis_options.yaml README.md example -g '*.dart' -g '*.yaml' -g '*.md'
```

It also created a temporary Flutter Web consumer app with:

- `polydart` from this local path.
- `web3dart: ^3.0.2`.
- `pointycastle: ^4.0.0`.
- `web_socket_channel: ^3.0.0`.

The compatibility app passed:

```sh
flutter pub get
flutter analyze
flutter build web
```

The package has no Flutter dependency and no direct forbidden Flutter Web
imports in `lib/`.
