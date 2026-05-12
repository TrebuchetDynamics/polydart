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
| Relayer and enable-trading surfaces | pkg/relayer, pkg/enabletrading, internal/enabletrading | lib/src/relayer | missing | test/relayer | required | 2b7cde7 | Inventory relayer V2 and enable-trading APIs |
| CLOB write responses and order results | internal/clob, pkg/orderresults | lib/src/clob, lib/src/orders | partial | test/clob, test/orders | required | 2b7cde7 | Compare response DTOs and error fields |
| Data API live V2 field shapes | internal/dataapi, pkg/data | lib/src/dataapi | partial | test/dataapi | not_required | 2b7cde7 | Add camelCase V2 position/order-result decoding |

## Surface Inventory

| Feature | Polygolem Path | Polydart Path | Status | Tests/Fixtures | Safety Review | Upstream Commit | Next Action |
|---|---|---|---|---|---|---|---|
| pkg/bridge | polygolem/pkg/bridge |  | missing |  | required | 2b7cde7 | Classify public SDK bridge scope |
| pkg/builder | polygolem/pkg/builder |  | missing |  | not_required | 2b7cde7 | Classify builder surface |
| pkg/clob | polygolem/pkg/clob | lib/src/clob | partial | test/clob | required | 2b7cde7 | Compare read/write public API |
| pkg/contracts | polygolem/pkg/contracts |  | missing |  | not_required | 2b7cde7 | Decide public constants surface |
| pkg/ctf | polygolem/pkg/ctf |  | missing |  | not_required | 2b7cde7 | Classify CTF helper scope |
| pkg/data | polygolem/pkg/data | lib/src/dataapi | partial | test/dataapi | not_required | 2b7cde7 | Map public Data API wrapper |
| pkg/enabletrading | polygolem/pkg/enabletrading |  | missing |  | required | 2b7cde7 | Port via wallet-mediated signing |
| pkg/experimental | polygolem/pkg/experimental |  | not applicable |  | not_required | 2b7cde7 | Revisit only if promoted upstream |
| pkg/funding | polygolem/pkg/funding |  | missing |  | required | 2b7cde7 | Classify funding and bridge safety model |
| pkg/gamma | polygolem/pkg/gamma | lib/src/gamma | partial | test/gamma | not_required | 2b7cde7 | Verify endpoint and DTO coverage |
| pkg/marketdata | polygolem/pkg/marketdata |  | missing |  | not_required | 2b7cde7 | Classify tracker API scope |
| pkg/marketresolver | polygolem/pkg/marketresolver | lib/src/marketresolver | partial | test/marketresolver | not_required | 2b7cde7 | Compare resolver semantics |
| pkg/orderbook | polygolem/pkg/orderbook | lib/src/bookreader | partial | test/bookreader | required | 2b7cde7 | Confirm naming divergence and behavior parity |
| pkg/orderresults | polygolem/pkg/orderresults |  | missing |  | required | 2b7cde7 | Add order result DTOs if public |
| pkg/pagination | polygolem/pkg/pagination | lib/src/pagination | partial | test/pagination | not_required | 2b7cde7 | Compare cursor/offset behavior |
| pkg/plugins | polygolem/pkg/plugins |  | missing |  | not_required | 2b7cde7 | Decide if public SDK needs plugin hooks |
| pkg/relayer | polygolem/pkg/relayer | lib/src/relayer | partial | test/relayer | required | 2b7cde7 | Compare V2 auth and endpoints |
| pkg/settlement | polygolem/pkg/settlement |  | missing |  | not_required | 2b7cde7 | Classify settlement API scope |
| pkg/stream | polygolem/pkg/stream | lib/src/stream | partial | test/stream | not_required | 2b7cde7 | Verify reconnect and dedupe behavior |
| pkg/types | polygolem/pkg/types | lib/src/types | partial | test/types | not_required | 2b7cde7 | Compare DTO field names and casing |
| pkg/universal | polygolem/pkg/universal |  | missing |  | not_required | 2b7cde7 | Decide whether Polydart needs universal facade |
| pkg/wallet | polygolem/pkg/wallet | lib/src/wallet | partial | test/wallet | required | 2b7cde7 | Port protocol behavior without raw EOA keys |
| internal/auth | polygolem/internal/auth | lib/src/auth | partial | test/auth | required | 2b7cde7 | Expand signing parity vectors |
| internal/clob | polygolem/internal/clob | lib/src/clob | partial | test/clob | required | 2b7cde7 | Compare order placement, cancellation, responses |
| internal/config | polygolem/internal/config | lib/src/config | partial | test/config | not_required | 2b7cde7 | Verify redaction and env mapping |
| internal/dataapi | polygolem/internal/dataapi | lib/src/dataapi | partial | test/dataapi | not_required | 2b7cde7 | Update live V2 field shapes |
| internal/enabletrading | polygolem/internal/enabletrading |  | missing |  | required | 2b7cde7 | Design wallet-mediated port |
| internal/errors | polygolem/internal/errors | lib/src/errors | partial | test/errors | not_required | 2b7cde7 | Compare error categories and codes |
| internal/gamma | polygolem/internal/gamma | lib/src/gamma | partial | test/gamma | not_required | 2b7cde7 | Verify search/event/tag/series parity |
| internal/marketdiscovery | polygolem/internal/marketdiscovery | lib/src/marketdiscovery | partial | test/marketdiscovery | not_required | 2b7cde7 | Compare enrichment behavior |
| internal/modes | polygolem/internal/modes | lib/src/modes | partial | test/modes | not_required | 2b7cde7 | Verify read-only/paper/live gates |
| internal/orders | polygolem/internal/orders | lib/src/orders | partial | test/orders | required | 2b7cde7 | Compare rounding, validation, expiration |
| internal/paper | polygolem/internal/paper |  | missing |  | not_required | 2b7cde7 | Classify paper state model |
| internal/preflight | polygolem/internal/preflight |  | missing |  | not_required | 2b7cde7 | Decide read-only preflight scope |
| internal/relayer | polygolem/internal/relayer | lib/src/relayer | partial | test/relayer | required | 2b7cde7 | Compare signing and relayer V2 calls |
| internal/risk | polygolem/internal/risk |  | missing |  | not_required | 2b7cde7 | Decide public SDK risk API |
| internal/rpc | polygolem/internal/rpc |  | missing |  | not_required | 2b7cde7 | Classify direct RPC support |
| internal/stream | polygolem/internal/stream | lib/src/stream | partial | test/stream | not_required | 2b7cde7 | Compare stream message handling |
| internal/telemetry | polygolem/internal/telemetry |  | missing |  | not_required | 2b7cde7 | Decide public SDK telemetry stance |
| internal/transport | polygolem/internal/transport | lib/src/transport | partial | test/transport | not_required | 2b7cde7 | Compare retry, rate limit, circuit breaker |
| internal/wallet | polygolem/internal/wallet | lib/src/wallet | partial | test/wallet | required | 2b7cde7 | Compare derive/deploy/status/batch semantics |
| cli/* | polygolem/internal/cli |  | not applicable |  | mixed | 2b7cde7 | Port behavior only when it maps to public SDK APIs |

## Tracked Non-Protocol Cleanup

| Item | Status | Next Action |
|---|---|---|
| Retire legacy `.reference/polygolem` compatibility | partial | Keep pulling both during transition; remove legacy references only after setup docs and workflows no longer need them |
