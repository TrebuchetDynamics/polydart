# Polymarket API, ABI transactions, and smart wallets for Polydart

## Method and limits

Standard-depth retrieval was run with ResearchForge (`rforge v0.1.3`) across OpenAlex, Crossref, Semantic Scholar, and arXiv for six query variants, then expanded citations for four relevant DOI seeds. Source coverage: OpenAlex 72 records, Crossref 101, Semantic Scholar 6, arXiv 120; 240 unique DOIs. I also retrieved Polymarket developer documentation pages and OpenAPI specs for CLOB, Relayer, Data, Gamma, Bridge, and RFQ APIs. No copyrighted full text was downloaded.

Local Polydart context came from `README.md`, `docs/POLYDART-POLYGOLEM-PARITY.md`, `docs/POLYDART-POLYGOLEM-COVERAGE.md`, and current source files under `lib/src/contracts`, `lib/src/ctf`, `lib/src/relayer`, and `lib/src/wallet`.

## Bottom line

Polydart’s current objectives match Polymarket’s live architecture: public reads are safe/no-auth; trading uses CLOB L2 API credentials plus user-signed EIP-712 orders; gasless/deposit-wallet mutations are relayed as signed wallet transactions and must stay safety-gated. The most important near-term parity risks are documentation/spec drift around `signatureType=3` (`POLY_1271` deposit wallets), relayer response casing/shape drift, and ABI-call planning for approvals, pUSD transfers, CTF split/merge/redeem, and wallet batches.

## Main themes

### 1. API surface split: read APIs vs authenticated trading

Polymarket docs state that Gamma, Data, and CLOB read endpoints such as orderbook/prices/spreads require no authentication, while CLOB trading endpoints require `POLY_*` L2 HTTP headers. The retrieved CLOB OpenAPI spec confirms production CLOB server `https://clob.polymarket.com`, `POST /order`, `POST /orders`, cancel endpoints, market data endpoints, and auth endpoints including `/auth/api-key`, `/auth/api-keys`, and `/auth/derive-api-key`.

For Polydart this supports the existing architecture in `README.md`: `Polydart.readOnly()` should remain credential-free; CLOB writes should remain explicit lower-level/live-gated paths, not hidden inside the universal read facade.

### 2. Two-level CLOB auth and order signing

Polymarket documentation describes CLOB as using L1 wallet authentication to create/derive API credentials and L2 API-key headers for authenticated trading requests. The CLOB OpenAPI spec says `/auth/api-key` uses `polyAddress`, `polySignature`, `polyTimestamp`, and `polyNonce`; order submission uses `polyApiKey`, `polyAddress`, `polySignature`, `polyPassphrase`, and `polyTimestamp`.

Important implementation point: even with L2 headers, docs say methods that create user orders still require the user to sign the order payload. The `Order` schema has `maker`, `signer`, `tokenId`, `makerAmount`, `takerAmount`, `side`, `expiration`, `timestamp`, `builder`, `signature`, `salt`, and `signatureType`. This aligns with Polydart’s `orders.amounts_signing`, `auth.erc7739_poly1271`, `clob.write_responses`, and signer abstraction work.

### 3. Signature types and smart-wallet/deposit-wallet drift

Polymarket docs list:

- `EOA = 0`: standalone wallet, EOA funds and pays POL gas.
- `POLY_PROXY = 1`: legacy Polymarket proxy wallet.
- `GNOSIS_SAFE = 2`: existing Safe flow.
- `POLY_1271 = 3`: deposit-wallet flow for new API users; funder is the deposit wallet address and orders are validated through ERC-1271.

The CLOB OpenAPI `Order.signatureType` and `/balance-allowance` descriptions still show enum `0,1,2` in the fetched spec, while the developer docs and Relayer `/deployed` docs mention deposit wallets/signature type `3`. Polydart should continue accepting and testing `3` explicitly, and treat upstream spec docs as inconsistent rather than authoritative enough to remove `POLY_1271`.

### 4. Relayer API and gasless transaction flow

The Relayer OpenAPI spec confirms production server `https://relayer-v2.polymarket.com`. `POST /submit` accepts a signed transaction payload with `from`, `to`, `proxyWallet`, `data`, `nonce`, `signature`, `signatureParams`, and `type` (`SAFE` or `PROXY`), returning `transactionID` and `state`. `GET /transaction?id=...` is the polling path for `transactionHash` after broadcast.

The spec also has:

- `/nonce?address=...&type=PROXY|SAFE`
- `/relay-payload?address=...&type=PROXY|SAFE`
- `/deployed?address=...&type=SAFE|WALLET`, where `WALLET` is deposit wallet/signature type `3`
- relayer API-key headers `RELAYER_API_KEY` and `RELAYER_API_KEY_ADDRESS`

This validates Polydart’s current `RelayerClient`, nonce/deployed DTO alias tolerance, transaction polling, relayer API key auth, and live mutation gates.

### 5. ABI transaction planning and contract registry

Polydart’s local registry names Polygon chain `137` and key Polymarket contracts:

- Deposit wallet factory: `0x00000000000Fb5C9ADea0298D729A0CB3823Cc07`
- Proxy factory: `0xaB45c5A4B0c941a2F231C04C3f49182e1A254052`
- Gnosis Safe factory: `0xaacFeEa03eb1561C4e67d661e40682Bd20E3541b`
- CTF Exchange V2: `0xE111180000d2663C0091e4f400237545B87B996B`
- Neg Risk Exchange V2: `0xe2222d279d744050d28e00520010520000310F59`
- Neg Risk Adapter V2: `0xd91E80cF2E7be2e162c6513ceD06f1dD0dA35296`
- pUSD: `0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB`
- CTF: `0x4D97DCd97eC945f40cF65F87097ACe5EA0476045`
- USDC.e: `0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174`

`lib/src/ctf/ctf.dart` builds calldata for `splitPosition(address,bytes32,bytes32,uint256[],uint256)`, `mergePositions(address,bytes32,bytes32,uint256[],uint256)`, and `redeemPositions(address,bytes32,bytes32,uint256[])`; comments correctly state these helpers encode calldata and compute IDs only, not submit transactions. That is the right boundary for Flutter/product safety.

### 6. Academic/context evidence

The retrieval found Polymarket-specific market-structure work, including `The Anatomy of a Blockchain Prediction Market: Polymarket in the 2024 U.S. Presidential Election` (SSRN DOI `10.2139/ssrn.6336679`) and `The Anatomy of a Decentralized Prediction Market: Microstructure Evidence from the Polymarket Order Book` (arXiv result without DOI in the retrieved search file). It also found broader DeFi/AMM context: `SoK: Decentralized Exchanges (DEX) with Automated Market Maker (AMM) Protocols` (ACM DOI `10.1145/3570639`) and `Automated market makers and decentralized exchanges: a DeFi primer` (Journal of Financial Innovation DOI `10.1186/s40854-021-00314-5`). These papers are useful background for market microstructure and settlement design, but the Polydart implementation details should be driven by Polymarket docs/specs and Polygolem parity fixtures, not by academic abstractions.

## Performance claims hygiene

Do not claim latency, fill quality, safety, or profitability from these sources without naming the exact paper or endpoint measurement. For Polydart docs/tests, prefer precise implementation claims: endpoint covered, DTO casing tolerated, calldata byte-for-byte vector matched, relayer transaction state parsed, or live submission blocked by safety gate. Avoid claims like “gasless trading is safe” or “orders settle instantly”; say “Relayer `POST /submit` returns `transactionID`; `GET /transaction` can later expose `transactionHash` after broadcast,” matching the Relayer spec.

## Evidence gaps

- Polymarket docs and OpenAPI currently disagree on `signatureType=3` support in some CLOB schemas; local tests should preserve `POLY_1271` coverage and monitor upstream spec changes.
- Retrieved docs did not provide full Solidity ABIs or audited contract source in a stable machine-readable bundle; Polydart should continue using minimal ABI selectors plus golden vectors instead of broad, unverified ABI assumptions.
- Citation expansion for DOI `10.48550/arxiv.2510.15612` produced an effectively empty graph from OpenAlex; keep it as a search result, not a citation-backed anchor.
- Live relayer/wallet behavior remains environment-dependent; no live approvals, deployments, trades, or transfers were executed.

## Implications for Polydart objectives

1. Keep `readOnly` and `UniversalClient` read-oriented. Do not let authenticated writes leak into the default facade.
2. Continue treating live mutations as safety-gated: CLOB order placement, relayer submission, approvals, pUSD transfers, settlement redemption, and wallet deployment need explicit owner/user intent.
3. Make `POLY_1271`/deposit-wallet behavior a first-class test path despite OpenAPI enum drift.
4. Prioritize fixture/golden conformance for EIP-712, ERC-7739/POLY_1271, CTF calldata, relayer request bodies, and response alias tolerance.
5. For Flutter, prefer wallet-provider/remote signer seams; do not store funded private keys or API secrets in app code. Client-side apps should not directly hold CLOB API secret material unless the owner has accepted that custody/security design.
