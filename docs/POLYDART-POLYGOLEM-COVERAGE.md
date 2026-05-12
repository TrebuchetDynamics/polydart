# Polydart-Polygolem Coverage Matrix

This matrix tracks Polydart completion against upstream Polygolem. Polygolem is
the protocol source of truth; Polydart may intentionally diverge on public SDK
custody architecture as described in `docs/adr/0001-wallet-mediated-eoa-signing.md`.

- Canonical upstream source: `polygolem/`
- Last scaffolded Polygolem commit: `2b7cde7`
- Legacy reference commit at scaffold time: `2b7cde7`
- Scaffold command: `python3 skills/polydart/scripts/polygolem_inventory.py --root .`

Status values: `implemented`, `partial`, `missing`, `intentional Dart
divergence`, `not applicable`.

`implemented` means behavior, public API/export story, tests or fixtures,
safety gates where relevant, user docs where needed, and upstream commit are
all accounted for.

## Priority Blockers

| Feature | Polygolem Path | Polydart Path | Status | Tests/Fixtures | Safety Review | Upstream Commit | Next Action |
|---|---|---|---|---|---|---|---|
| Wallet-mediated EOA custody | internal/auth, internal/wallet | lib/src/auth, lib/src/wallet | intentional Dart divergence | test/auth, test/wallet | required | 2b7cde7 | Enforce ADR 0001 in signing and wallet work |
| Deposit-wallet live semantics | internal/wallet, internal/relayer, internal/clob | lib/src/wallet, lib/src/relayer, lib/src/clob | partial | test/wallet, test/relayer, test/clob | required | 2b7cde7 | Verify `signatureType=3`, maker/signer/funder separation, pUSD routing |
| EIP-712 / ERC-7739 / POLY_1271 signing | internal/auth, internal/clob/orders.go | lib/src/auth, lib/src/orders | partial | test/auth, test/orders | required | 2b7cde7 | Expand byte-level parity vectors |
| Relayer and enable-trading surfaces | pkg/relayer, pkg/enabletrading, internal/enabletrading | lib/src/relayer, lib/src/enabletrading | partial | test/relayer, test/enabletrading | required | 2b7cde7 | Enable-trading typed data and relayer allowlist classification covered; continue Relayer V2 API-key endpoint parity |
| CLOB write responses and order results | internal/clob, pkg/orderresults | lib/src/clob, lib/src/orders, lib/src/orderresults | partial | test/clob, test/orders, test/orderresults | required | 2b7cde7 | Order-results report builder covered with ApiKey reader; continue CLOB response DTO/error fields |
| Data API live V2 field shapes | internal/dataapi, pkg/data | lib/src/dataapi | partial | test/dataapi | not_required | 2b7cde7 | Current-position, closed-position, and trade camelCase decoding covered; add order-result decoding |

## Surface Inventory

| Feature | Polygolem Path | Polydart Path | Status | Tests/Fixtures | Safety Review | Upstream Commit | Next Action |
|---|---|---|---|---|---|---|---|
| pkg/bridge | polygolem/pkg/bridge | lib/src/bridge | implemented | test/bridge | not_required | 2b7cde7 | HTTP-only bridge client covered |
| pkg/builder | polygolem/pkg/builder | lib/src/builder | implemented | test/builder | not_required | 2b7cde7 | Local and remote builder signer surfaces covered |
| pkg/clob | polygolem/pkg/clob | lib/src/clob | partial | test/clob | required | 2b7cde7 | Compare read/write public API |
| pkg/contracts | polygolem/pkg/contracts | lib/src/contracts | implemented | test/contracts | not_required | 2b7cde7 | Contract registry and eth_getCode readiness covered |
| pkg/ctf | polygolem/pkg/ctf | lib/src/ctf | implemented | test/ctf | not_required | 2b7cde7 | CTF calldata and ID helpers covered |
| pkg/data | polygolem/pkg/data | lib/src/dataapi | partial | test/dataapi | not_required | 2b7cde7 | Map public Data API wrapper |
| pkg/enabletrading | polygolem/pkg/enabletrading | lib/src/enabletrading | partial | test/enabletrading | required | 2b7cde7 | Wallet-mediated ClobAuth and approval batch planning covered; live submission stays app-owned/gated |
| pkg/experimental | polygolem/pkg/experimental |  | not applicable |  | not_required | 2b7cde7 | Revisit only if promoted upstream |
| pkg/funding | polygolem/pkg/funding | lib/src/funding | intentional Dart divergence | test/funding | required | 2b7cde7 | Wallet-mediated pUSD transfer call planning covered; direct raw-EOA live transfer intentionally omitted |
| pkg/gamma | polygolem/pkg/gamma | lib/src/gamma | partial | test/gamma | not_required | 2b7cde7 | Profile creation helper covered; continue endpoint and DTO coverage |
| pkg/marketdata | polygolem/pkg/marketdata | lib/src/marketdata | implemented | test/marketdata | not_required | 2b7cde7 | Market-data tracker covered |
| pkg/marketresolver | polygolem/pkg/marketresolver | lib/src/marketresolver | partial | test/marketresolver | not_required | 2b7cde7 | Compare resolver semantics |
| pkg/orderbook | polygolem/pkg/orderbook | lib/src/bookreader | partial | test/bookreader | required | 2b7cde7 | Confirm naming divergence and behavior parity |
| pkg/orderresults | polygolem/pkg/orderresults | lib/src/orderresults | implemented | test/orderresults | not_required | 2b7cde7 | Report builder covered; CLOB inclusion uses ApiKey reader instead of raw private key |
| pkg/pagination | polygolem/pkg/pagination | lib/src/pagination | implemented | test/pagination | not_required | 2b7cde7 | Cursor/offset stream, collect, and batch helpers covered |
| pkg/plugins | polygolem/pkg/plugins | lib/src/plugins | implemented | test/plugins | not_required | 2b7cde7 | Plugin interfaces covered |
| pkg/relayer | polygolem/pkg/relayer | lib/src/relayer | partial | test/relayer | required | 2b7cde7 | Allowlist rejection classifier covered; continue V2 auth headers, transaction response shapes, and endpoint parity |
| pkg/settlement | polygolem/pkg/settlement | lib/src/settlement | partial | test/settlement | required | 2b7cde7 | Read-only redeem discovery, call planning, and readiness checks covered; live relay submission gated out |
| pkg/stream | polygolem/pkg/stream | lib/src/stream | partial | test/stream | not_required | 2b7cde7 | Verify reconnect and dedupe behavior |
| pkg/types | polygolem/pkg/types | lib/src/types | partial | test/types | not_required | 2b7cde7 | Compare DTO field names and casing |
| pkg/universal | polygolem/pkg/universal | lib/src/universal | partial | test/universal | not_required | 2b7cde7 | Read-only universal facade covered; authenticated raw-key write methods intentionally excluded from default public surface |
| pkg/wallet | polygolem/pkg/wallet | lib/src/wallet | partial | test/wallet | required | 2b7cde7 | Port protocol behavior without raw EOA keys |
| internal/auth | polygolem/internal/auth | lib/src/auth | partial | test/auth | required | 2b7cde7 | Expand signing parity vectors |
| internal/clob | polygolem/internal/clob | lib/src/clob | partial | test/clob | required | 2b7cde7 | Compare order placement, cancellation, responses |
| internal/config | polygolem/internal/config | lib/src/config | partial | test/config | not_required | 2b7cde7 | Verify redaction and env mapping |
| internal/dataapi | polygolem/internal/dataapi | lib/src/dataapi | partial | test/dataapi | not_required | 2b7cde7 | Current-position, closed-position, and trade V2 fields covered; continue order results |
| internal/enabletrading | polygolem/internal/enabletrading | lib/src/enabletrading | partial | test/enabletrading | required | 2b7cde7 | Wallet-mediated typed-data builders covered; no raw EOA key submission surface |
| internal/errors | polygolem/internal/errors | lib/src/errors | partial | test/errors | not_required | 2b7cde7 | Compare error categories and codes |
| internal/execution | polygolem/internal/execution | lib/src/paper, lib/src/modes | partial | test/paper, test/modes | required | 2b7cde7 | Map executor semantics to paper/live/read-only boundaries |
| internal/gamma | polygolem/internal/gamma | lib/src/gamma | partial | test/gamma | not_required | 2b7cde7 | Profile creation helper covered; continue search/event/tag/series/profile DTO parity |
| internal/marketdiscovery | polygolem/internal/marketdiscovery | lib/src/marketdiscovery | partial | test/marketdiscovery | not_required | 2b7cde7 | Compare enrichment behavior |
| internal/modes | polygolem/internal/modes | lib/src/modes | implemented | test/modes | not_required | 2b7cde7 | Parse defaults and live-gate validation covered |
| internal/orders | polygolem/internal/orders | lib/src/orders | partial | test/orders | required | 2b7cde7 | Compare rounding, validation, expiration |
| internal/output | polygolem/internal/output |  | not applicable |  | not_required | 2b7cde7 | CLI output formatting; no public SDK surface planned |
| internal/paper | polygolem/internal/paper | lib/src/paper | implemented | test/paper | not_required | 2b7cde7 | Local paper state covered |
| internal/polytypes | polygolem/internal/polytypes | lib/src/types | partial | test/types | not_required | 2b7cde7 | Use upstream DTO fixtures to drive type parity |
| internal/preflight | polygolem/internal/preflight | lib/src/preflight | implemented | test/preflight | not_required | 2b7cde7 | Async preflight runner covered |
| internal/relayer | polygolem/internal/relayer | lib/src/relayer | partial | test/relayer | required | 2b7cde7 | Signing, submit, and allowlist classification covered; continue Relayer V2 response/auth parity |
| internal/risk | polygolem/internal/risk | lib/src/risk | implemented | test/risk | not_required | 2b7cde7 | Local risk breaker covered |
| internal/rpc | polygolem/internal/rpc | lib/src/rpc | partial | test/rpc | not_required | 2b7cde7 | Read-only code/approval/allowance helpers covered; live transfer/swap still gated out |
| internal/stream | polygolem/internal/stream | lib/src/stream | partial | test/stream | not_required | 2b7cde7 | Compare stream message handling |
| internal/telemetry | polygolem/internal/telemetry | lib/src/telemetry | implemented | test/telemetry | not_required | 2b7cde7 | Request/retry/rate-limit/circuit-open telemetry and redaction covered |
| internal/transport | polygolem/internal/transport | lib/src/transport | partial | test/transport | not_required | 2b7cde7 | Compare retry, rate limit, circuit breaker |
| internal/wallet | polygolem/internal/wallet | lib/src/wallet | partial | test/wallet | required | 2b7cde7 | Compare derive/deploy/status/batch semantics |
| cli/* | polygolem/internal/cli |  | not applicable |  | mixed | 2b7cde7 | Port behavior only when it maps to public SDK APIs |

## Tracked Non-Protocol Cleanup

| Item | Status | Next Action |
|---|---|---|
| Retire legacy `.reference/polygolem` compatibility | partial | Keep pulling both during transition; remove legacy references only after setup docs and workflows no longer need them |
