# Polydart Context

Polydart is a Dart SDK for Polymarket protocol access that treats Polygolem as the protocol reference while fitting Dart, Flutter, web, and headless-user needs. This context keeps parity, signer, and safety language unambiguous.

## Language

**Twin Parity**:
Polydart mirrors Polygolem's public protocol architecture and feature surfaces, with documented Dart-specific divergences where platform or signer constraints differ. Polygolem is the older-brother reference for protocol bytes, request shapes, fixtures, and safety posture; Polydart does not need byte-identical internal package layout.
_Avoid_: Identical implementation, blind port, feature-ish parity

**EOA Signer Compatibility**:
Normal Polydart app usage goes through an EOA Signer with ReownWallet or an equivalent wallet-provider signer. Explicit private-key EOA signers are special-case tools for CLI tests, alpha/test apps, headless users who do not want an interactive wallet, and generated paper-mode wallets; signer APIs must keep key material out of logs and diagnostics.
_Avoid_: Wallet-only signing, no-private-keys-ever, private-key-default custody, private-key-normal app flow

**EOA Signer with ReownWallet**:
The preferred normal-app signer language for Polydart: a user-controlled EOA reached through ReownWallet / WalletConnect or an equivalent wallet-provider adapter that can produce MetaMask-style `eth_signTypedData_v4` and `personal_sign` signatures. It is the UI-facing signer shape for Flutter, web, and mobile apps.
_Avoid_: Browser-only signer, custody signer, server key, raw private-key signer

**Explicit Private-Key EOA Signer**:
An opt-in local EOA signer constructed from private-key material for special cases: CLI tests, alpha/test apps, headless flows without interactive sign-in, server automation, or generated paper-mode wallets. It is allowed in Polydart, but must be explicit and redacted rather than the normal app path.
_Avoid_: Hidden key signer, default private-key custody, unsafe signer, normal app signer

**Paper Wallet**:
A generated EOA identity used only for paper-mode or no-sign-in app trials. A Paper Wallet must not be upgraded into live custody, funded deposits, or live trading; live mode requires a wallet-provider signer or an explicit private-key EOA signer chosen with live-use intent.
_Avoid_: Temporary live account, upgradeable test key, disposable funded wallet

**Safety-Gated Mutation**:
A Polydart operation that could trade, approve, transfer, withdraw, deploy, or otherwise mutate protocol state must remain explicit, test-covered, and gated by caller intent. Read-only parity does not imply permission for live mutation.
_Avoid_: Live-by-default action, implicit approval, read method with side effects

## Example dialogue — Twin parity and signers

Developer: "Should Polydart copy Polygolem's local private-key signer?"
Domain expert: "Polydart should preserve EOA Signer Compatibility: support wallet-provider signers and explicit private-key EOA signers, but do not make private-key custody implicit."

Developer: "Does Twin Parity mean the Dart folders must match Go folders exactly?"
Domain expert: "No. Twin Parity means public protocol surfaces, request shapes, fixtures, safety semantics, and user-facing capabilities line up. Dart can organize modules differently when the parity matrix documents the mapping."

Developer: "Can a no-sign-in generated key become the user's live trading wallet later?"
Domain expert: "No. That is a Paper Wallet: useful for paper-mode UX trials, but not a live custody identity. Live mode needs wallet-provider signing or an explicit private-key EOA signer chosen for live use."

Developer: "Can a read-only MCP or opportunity scanner submit a trade if the signer exists?"
Domain expert: "No. That crosses into Safety-Gated Mutation and needs an explicit mutation path, tests, and user intent."
