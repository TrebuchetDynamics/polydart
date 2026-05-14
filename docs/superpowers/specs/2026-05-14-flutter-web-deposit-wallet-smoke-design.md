# Flutter Web Deposit-Wallet Smoke Design

## Goal

Add a public, mock-only smoke path proving that Polydart's deposit-wallet
limit-order flow can be driven from a Flutter Web app boundary without raw EOA
private keys.

The smoke path should be plain Dart like the existing Flutter-oriented examples:
no `package:flutter` dependency, no wallet SDK dependency, and no live network
submission. A Flutter app should be able to copy the ownership pattern into a
provider, bloc, service, or `State` object.

## Selected Approach

Use an example plus a behavior test:

- `example/flutter_deposit_wallet_order.dart` demonstrates the app-owned flow.
- `test/example/flutter_deposit_wallet_order_test.dart` exercises the example
  through its public facade and asserts the produced order payload is
  `signatureType=3`.

This is preferred over a full Flutter app example because Polydart is a Dart
package, not a Flutter package. A real Flutter app can own UI, wallet packages,
and dependency injection while Polydart keeps the reusable protocol surface.

Alternatives considered:

- Full Flutter sample app: closer to product UX, but adds Flutter SDK ownership
  and package churn to Polydart.
- Docs-only recipe: cheaper, but it does not protect the smoke path from
  regressions.

## Public Flow

The example introduces a small `FlutterDepositWalletOrderSmoke` facade with a
`run()` method. It accepts injected dependencies:

- a `WalletSigner`
- deterministic market/order input
- mock CLOB transport
- mock readiness/funding state as needed

The smoke path performs:

1. Derive or use the deposit-wallet maker from the wallet signer.
2. Confirm readiness is modeled as an explicit app-visible state.
3. Ask the injected wallet signer to approve typed data.
4. Build a deposit-wallet limit order through Polydart.
5. Submit only to the mock CLOB transport.
6. Return the captured request body for app display or assertions.

## Safety Boundaries

- No raw private keys, seed phrases, funded credentials, or live API keys.
- No private product names or private repository paths.
- No live HTTP endpoint submission by default.
- User rejection from the fake signer is represented as an app-visible failure,
  not swallowed.
- The example keeps wallet approval at the `WalletSigner` boundary required by
  ADR 0001.

## Testing

The test should verify observable behavior:

- the smoke facade returns a successful mocked order response;
- the captured order body contains `signatureType: 3`;
- the maker is the derived deposit-wallet address, not the EOA address;
- the CLOB auth address remains EOA-bound where exposed in headers/body;
- a rejecting signer produces a typed failure the app can surface.

Run release-grade checks after implementation:

```sh
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-warnings
dart test --reporter=expanded
dart pub publish --dry-run
```

## Out of Scope

- Real wallet SDK wiring.
- Real Flutter widgets.
- Relayer API-key minting in browser.
- Live funding, approval, order submission, or cancellation.
- Any dependency on a private app or private server.
