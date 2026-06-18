# Wide E2E Coverage Matrix

Most tests here are mocked end-to-end journeys: they cross public SDK feature seams without live network calls, signing with real funds, approvals, deposits, or trade submission. Files named `live_*_opt_in_*` are skipped by default and require explicit environment variables before they can call live services.

| Feature family | Wide E2E coverage |
| --- | --- |
| Read-only Gamma/CLOB/Data API composition, market resolver, market discovery, market detail bundle | `read_only_market_journey_e2e_test.dart` |
| Live credential creation, SIWE session flow, deposit-wallet readiness, signatureType 3 order posting safety path | `live_deposit_wallet_mock_e2e_test.dart` |
| Random explicit private-key EOA to Polymarket smart-wallet artifacts: deploy request, pUSD funding tx plan, enable-trading batch, and signatureType 3 order body | `random_private_key_smart_wallet_e2e_test.dart` |
| Opt-in live proof for random private-key EOA relayer `WALLET-CREATE`, deployed status, and repeat-create observation | `live_relayer_wallet_create_opt_in_e2e_test.dart` |
| Wallet intelligence dossiers, alerts, leaderboard, market flow | `wallet_intel_e2e_test.dart` |
| Bridge funding/deposit reads, Relayer V2 reads, settlement call planning, order-results reports, opportunities, preflight, MCP, RFQ safety, OpenAPI | `wide_feature_matrix_e2e_test.dart` |
| Local SDK surfaces: config/modes, auth headers and redaction, book reader, market-data tracker, stream dedup/stats, pagination, paper trading, plugins, risk breaker, order amount math, telemetry | `wide_local_surfaces_e2e_test.dart` |
| Protocol planning surfaces: builder signatures, Gamma profile creation payload, CTF IDs/calldata, enable-trading approvals, pUSD funding, RPC helpers, order fills, universal client | `wide_protocol_planning_e2e_test.dart` |

Completion rule: every public feature family exported by `lib/polydart.dart` should be represented by one of the rows above or by an existing focused E2E journey. Focused unit tests still own edge-case exhaustiveness; these wide E2E tests prove multi-feature wiring and safety gates.

See `docs/RANDOM-PRIVATE-KEY-SMART-WALLET-E2E.md` for the mocked random-private-key smart-wallet journey, the skipped-by-default live relayer proof, and the safety boundary.
