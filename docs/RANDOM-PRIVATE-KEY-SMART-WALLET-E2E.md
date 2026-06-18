# Random Private-Key Smart-Wallet E2E

This note documents two E2E paths:

- `test/e2e/random_private_key_smart_wallet_e2e_test.dart` — default-safe,
  offline protocol-shape E2E with mocked transports.
- `test/e2e/live_relayer_wallet_create_opt_in_e2e_test.dart` — skipped by
  default, live opt-in `WALLET-CREATE` proof against Polymarket relayer.

The default-safe goal is "as real as possible" without crossing into live
mutation: use real Polydart cryptographic/signing code, real Polygon/Polymarket
contract constants, and real wire payload shapes, but replace every network
transport with a mock and never broadcast. The live opt-in test removes the
relayer mock only when the caller explicitly acknowledges the deployment risk.

## Which path should I run?

| Need | Run | Network? | Mutation risk |
| --- | --- | --- | --- |
| Verify SDK wiring, signing, calldata, relayer/CLOB body shapes | `dart test test/e2e/random_private_key_smart_wallet_e2e_test.dart` | none | none |
| Prove live Polymarket relayer accepts `WALLET-CREATE` for one controlled EOA | `live_relayer_wallet_create_opt_in_e2e_test.dart` with all live env gates | Gamma, relayer, Polygon RPC | can create a real deposit-wallet deployment tx |
| Observe already-existing wallet behavior | same live test with `POLYDART_LIVE_RELAYER_REPEAT_CREATE=1` and a key whose deposit wallet already has bytecode | Gamma, relayer, Polygon RPC | may submit another relayer request; use sparingly |

Default CI should run only the first path. The live path is an operator tool,
not a regression test to run repeatedly.

## What the offline test proves

Given a freshly generated explicit private-key EOA, Polydart can locally build
Polymarket smart-wallet artifacts without broadcasting anything:

1. create a `LocalEoaSigner` from a random private-key scalar;
2. derive the deterministic Polymarket deposit wallet for that EOA;
3. build and submit, through a mocked relayer transport, the `WALLET-CREATE`
   deploy request shape;
4. build the direct EOA `pUSD.transfer(depositWallet, amount)` wallet
   transaction request;
5. build Enable Trading approval calls, sign the `DepositWallet.Batch` typed
   data with the same explicit private-key EOA, and submit the mocked relayer
   `WALLET` batch body;
6. sign a `signatureType=3` deposit-wallet limit order with ERC-7739 /
   POLY_1271 wrapping and post the mocked CLOB `/order` body.

The test checks that the order body uses the derived deposit wallet as both
`maker` and `signer`, while HTTP authentication remains EOA-bound through
`POLY_ADDRESS`. It also checks concrete protocol details: relayer submissions
hit the DepositWallet factory target, pUSD funding calldata is exact
`transfer(address,uint256)` ABI data, Enable Trading approval calls target the
expected pUSD/USDC.e contracts and spenders, and the resulting deposit-wallet
order contains a 317-byte POLY_1271 wrapped signature.

## What the offline test intentionally does not do

The test does **not**:

- call Polymarket, Polygon RPC, or any live network;
- broadcast a deployment, approval, funding transfer, order, or settlement;
- store the generated private key;
- imply production live-trading readiness.

All transports are mocked. The produced transaction and order payloads are
protocol-shape evidence only. The private key is generated in memory by
`Random.secure()` and is never persisted.

## Research / protocol mapping

Polydart treats the Polymarket smart wallet as the deterministic deposit wallet
used for `signatureType=3` orders. The E2E maps SDK helpers to protocol
surfaces as follows:

| Step | Polydart helper | Protocol artifact |
| --- | --- | --- |
| EOA identity | `LocalEoaSigner` | explicit private-key EOA signer |
| Smart wallet address | `deriveDepositWallet(owner)` | deterministic deposit wallet |
| Wallet deploy | `RelayerClient.submitWalletCreate` | relayer `WALLET-CREATE` submit body |
| Funding | `buildEoaPusdTransferPlan` | wallet-provider `pUSD.transfer` tx request with `a9059cbb` selector, deposit-wallet recipient, amount, `value=0x0`, and `chainId=0x89` |
| Enable Trading | `buildEnableTradingApprovalCalls` + `signEnableTradingApprovalBatchTypedData` | deposit-wallet approval batch typed data and relayer `WALLET` submit body for pUSD/USDC.e approvals |
| Deposit-wallet order | `createDepositWalletLimitOrder` | CLOB `POST /order` with `signatureType=3`, `maker == signer == depositWallet`, `orderType=GTC`, and POLY_1271 wrapped signature |

## Realism checks in the E2E

The E2E deliberately asserts the parts most likely to drift from Polymarket's
wire protocol:

- relayer deploy body: `type=WALLET-CREATE`, `from=<EOA>`,
  `to=DepositWalletFactory`;
- pUSD funding transaction: `to=PUSD`, `value=0x0`, `chainId=0x89`, and exact
  ERC-20 transfer calldata;
- Enable Trading approval calls: targets are `PUSD` and `USDCE`, with spender
  words for `CTF` and `CollateralOnramp`;
- approval batch submission: relayer `WALLET` body includes deposit wallet,
  nonce, deadline, calls, and a 65-byte EOA signature;
- order placement: CLOB body uses `signatureType=3`, deposit wallet maker and
  signer fields, and a 636-character 0x-prefixed POLY_1271 signature.

## Live relayer WALLET-CREATE proof

`test/e2e/live_relayer_wallet_create_opt_in_e2e_test.dart` is intentionally not
part of normal CI. It SIWE-logs in to Polymarket Gamma, mints a V2 relayer API
key, checks on-chain bytecode for the derived deposit wallet, calls the real
relayer `WALLET-CREATE` endpoint only when code is absent, polls the relayer
transaction, and verifies deployment with Polygon `eth_getCode`.

Polygolem safety research matters here: its `deposit-wallet deploy` command
checks on-chain code before submitting `WALLET-CREATE`, and its safety docs say
relayer `/deployed` is advisory while Polygon `eth_getCode` is the source of
truth. Polydart's opt-in live test follows that rule to avoid repeat deploy
spam and ban risk.

### Live preflight checklist

Before running the live test, confirm all of the following:

- You are okay creating a real relayer transaction for the chosen EOA.
- You have a reliable Polygon RPC URL; public unauthenticated RPCs may reject
  `eth_getCode` or rate-limit.
- You are using `POLYDART_LIVE_PRIVATE_KEY` for a controlled account unless you
  deliberately want a brand-new random EOA.
- You understand that repeated fresh random-key runs can look like relayer spam.
- You will not paste private keys or relayer API keys into terminal output,
  issue comments, or logs.

Run it with a controlled private key and reliable Polygon RPC URL:

```bash
POLYDART_LIVE_PRIVATE_KEY=0x... \
POLYDART_LIVE_RPC_URL=https://your-polygon-rpc.example \
POLYDART_LIVE_RELAYER_WALLET_CREATE=1 \
POLYDART_LIVE_RELAYER_WALLET_CREATE_ACK=I_UNDERSTAND_THIS_CAN_DEPLOY_A_POLYMARKET_SMART_WALLET \
dart test test/e2e/live_relayer_wallet_create_opt_in_e2e_test.dart \
  --reporter=expanded
```

Fresh random-key deploys are deliberately behind an extra gate because every
run can create another live relayer transaction and a new derived deposit-wallet
address:

```bash
POLYDART_LIVE_RANDOM_PRIVATE_KEY=1 \
POLYDART_LIVE_RPC_URL=https://your-polygon-rpc.example \
POLYDART_LIVE_RELAYER_WALLET_CREATE=1 \
POLYDART_LIVE_RELAYER_WALLET_CREATE_ACK=I_UNDERSTAND_THIS_CAN_DEPLOY_A_POLYMARKET_SMART_WALLET \
dart test test/e2e/live_relayer_wallet_create_opt_in_e2e_test.dart \
  --reporter=expanded
```

### Environment variables

| Variable | Required? | Purpose |
| --- | --- | --- |
| `POLYDART_LIVE_RELAYER_WALLET_CREATE=1` | yes | Enables the skipped live test. |
| `POLYDART_LIVE_RELAYER_WALLET_CREATE_ACK=I_UNDERSTAND_THIS_CAN_DEPLOY_A_POLYMARKET_SMART_WALLET` | yes | Explicit acknowledgement that this can create live relayer/deploy activity. |
| `POLYDART_LIVE_RPC_URL` | yes | Polygon RPC used for `eth_getCode`; this is the deployment source of truth. |
| `POLYDART_LIVE_PRIVATE_KEY` | recommended | Controlled EOA private key. Prefer this over random-key mode when debugging. |
| `POLYDART_LIVE_RANDOM_PRIVATE_KEY=1` | optional, dangerous | Generates a new in-memory EOA and may create a new live relayer transaction. |
| `POLYDART_LIVE_RELAYER_REPEAT_CREATE=1` | optional, dangerous | After code exists, probes what happens if `WALLET-CREATE` is submitted again. |
| `POLYDART_LIVE_RELAYER_POLL_ATTEMPTS` / `POLYDART_LIVE_RELAYER_POLL_SECONDS` | optional | Controls relayer transaction polling. |
| `POLYDART_LIVE_DEPLOYED_POLL_ATTEMPTS` / `POLYDART_LIVE_DEPLOYED_POLL_SECONDS` | optional | Controls on-chain bytecode polling after relayer mining. |

To observe what Polymarket relayer does when the wallet already exists, use a
private key whose derived deposit wallet already has on-chain bytecode and add:

```bash
POLYDART_LIVE_RELAYER_REPEAT_CREATE=1
```

The repeat-create branch accepts and prints either observed behavior:

- an idempotent/accepted relayer transaction, or
- a structured rejection mentioning an existing/deployed wallet.

Do not paste private keys into logs. The test prints only the EOA, expected
deposit wallet, transaction ids, relayer states, relayer `/deployed`, and
on-chain code status.

### Operator do / don't

Do:

- run the offline E2E first;
- use a controlled private key when investigating live behavior;
- use a reliable paid/team Polygon RPC URL for `eth_getCode`;
- save transaction ids and the derived deposit-wallet address for audit;
- stop after one live proof unless there is a new owner-approved question.

Don't:

- run random-key live deploys in a loop;
- use CI, cron, or retry bots for `WALLET-CREATE`;
- treat relayer `/deployed=false` as proof that deploy failed;
- submit repeat-create probes against fresh wallets;
- paste private keys, SIWE bearer tokens, cookies, or relayer API keys into logs.

### Why `eth_getCode` wins over relayer `/deployed`

Polygolem's deposit-wallet safety docs and CLI use Polygon bytecode as the
deployment source of truth. Relayer `/deployed` is useful diagnostics, but can
return `false` while a wallet already has bytecode or while relayer indexing is
behind. Polydart therefore uses this order in the live test:

1. derive deposit wallet locally;
2. check `eth_getCode(depositWallet)`;
3. skip `WALLET-CREATE` when bytecode already exists;
4. submit `WALLET-CREATE` only when bytecode is absent;
5. poll the relayer transaction;
6. verify bytecode again with `eth_getCode`;
7. log relayer `/deployed` only as advisory state.

### Troubleshooting live outcomes

| Observation | Meaning | Safe next action |
| --- | --- | --- |
| Test is skipped | One or more live env gates are absent. | This is expected for CI/default runs. Set gates only for an intentional live proof. |
| SIWE login fails | Gamma rejected nonce/login, signer chain is wrong, or upstream auth changed. | Stop; do not retry in a loop. Inspect status codes and headers without logging secrets. |
| `WALLET-CREATE` returns `STATE_NEW` then `STATE_MINED` | Relayer accepted and mined its tracked transaction. | Check `eth_getCode` for the derived deposit wallet. |
| `STATE_MINED` but relayer `/deployed=false` | Relayer status/indexing can be stale or advisory. | Use `eth_getCode` as source of truth; do not immediately resubmit. |
| `eth_getCode` RPC returns 401/403 | RPC provider rejected unauthenticated access or disabled the endpoint. | Use `POLYDART_LIVE_RPC_URL` with a reliable Polygon RPC key. |
| `eth_getCode` remains empty after polling | The deploy may not have produced wallet bytecode, or the wrong wallet address/RPC/network was used. | Stop and inspect the relayer transaction id out-of-band; do not keep creating fresh wallets. |
| Repeat create is accepted | Relayer may treat duplicate create as idempotent/tracked. | Record the behavior; avoid further probes. |
| Repeat create is rejected as existing/deployed | This is also acceptable already-existing behavior. | Record the structured error and stop. |

### Live observations so far

A live random-key run on 2026-06-17 successfully SIWE-logged in, minted a V2
relayer key, submitted real `WALLET-CREATE`, and observed `STATE_MINED` for
transaction ids like `019ed5e8-4cd9-7e25-be3c-56c4eef560c1`. However,
relayer `/deployed` still returned `false` immediately afterwards. A follow-up
on-chain check must use a reliable RPC URL; public unauthenticated Polygon RPCs
may reject with 401/403. Because of ban/spam risk, do not keep retrying random
fresh keys just to probe eventual consistency.

## Safety posture

This E2E uses an **Explicit Private-Key EOA Signer**, which `CONTEXT.md`
defines as a special-case tool for tests, headless flows, server automation, or
paper-mode trials. Normal app UX should use an EOA signer with ReownWallet /
WalletConnect or another wallet-provider adapter.

Live mutation remains a **Safety-Gated Mutation**. Consumers that choose to
broadcast the planned payloads must own wallet prompts, relayer credentials,
funding, gas/risk controls, and user confirmation outside this mocked test.
