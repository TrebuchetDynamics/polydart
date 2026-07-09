# Headless Builder Keys — Investigation Report

> **Status:** Code-only investigation, 2026-05-08. No production write traffic.
> **Sources:** `/tmp/headless-builder-keys-survey.md` (Polymarket SDK survey),
> `/tmp/polymarket-frontend-analysis.md` (polymarket.com bundle static
> analysis).

## TL;DR

Polymarket's settings page has **two distinct "Create" buttons** for what
gets colloquially called "Builder API Keys", and they call two different
endpoints with two different auth models:

| Button | Endpoint | Auth | Headless? | Gates |
| --- | --- | --- | --- | --- |
| **CLOB Builder Fee Key** | `POST clob.polymarket.com/auth/builder-api-key` | L2 HMAC (POLY_*) | ✅ yes | On-order builder fee attribution |
| **Relayer API Key** | `POST relayer-v2.polymarket.com/relayer/api/auth` | Polymarket session cookie | ❌ no — see § Cookie gate | `relayer-v2/submit` (deposit-wallet deploy, V2 approvals) |

The polygolem `builder auto` flow currently does neither — it only mints
**CLOB L2 creds** via `/auth/api-key` (L1 ClobAuth signature). That's why a
profiled, builder-registered EOA still 401s on `relayer-v2/submit`: it has
the L2 creds but neither flavor of "builder key".

**Practical takeaway:** half the gate is dissolvable today with a 30-line
addition to polydart and polygolem. The other half (the relayer-v2 cookie)
is genuine and needs one more sub-investigation before we can call it
fully headless.

## What the original confusion was

The polygolem doc `BUILDER-AUTO.md` lumped both creds under a single
"Builder API Keys" label and reported that `relayer-v2/submit` 401'd on
auto-minted creds for a profiled EOA, concluding the gate was browser-only.
That's still true *for the relayer flavor* — but the doc missed that the
CLOB-side builder-fee key is **also** called "Builder API Keys" in the UI
and **is** mintable headlessly.

Empirical evidence aligns:

- The user's profiled EOA (`0x33e4aD…Fa76C`) has a builder code registered
  but the settings page reports "Builder Keys: No builder API keys yet."
  That label refers to the **Relayer API Key** row in the UI, not the CLOB
  builder-fee key. The Relayer key is what `submit` validates against.
- Throwaway EOAs and the profiled EOA both 401 on `submit` for the same
  reason: no Relayer API Key minted, regardless of CLOB-side state.

## CLOB Builder Fee Key — `/auth/builder-api-key`

### Wire format

```http
POST https://clob.polymarket.com/auth/builder-api-key
POLY_ADDRESS:    <EOA hex>
POLY_TIMESTAMP:  <unix seconds, decimal>
POLY_API_KEY:    <UUID from /auth/api-key>
POLY_PASSPHRASE: <passphrase from /auth/api-key>
POLY_SIGNATURE:  <HMAC-SHA256 over `${ts}${method}${path}${body?}`>
Content-Type:    application/json

(empty body)
```

Response:

```json
{ "key": "<uuid-shape>", "secret": "<base64>", "passphrase": "<random>" }
```

### What it gates

On-order **builder fee attribution** — the `builder` bytes32 field on V2
orders. This is the protocol-level mechanism that lets a third-party app
(an "integrator") earn a share of CLOB fees on orders routed through it.

### Confirming sources

- `Polymarket/py-clob-client-v2` @ `394ecc1` — `py_clob_client_v2/client.py:1028-1041`
- `Polymarket/clob-client-v2` (TS) @ `9dcc32e` — `src/client.ts:1496-1549`
- `Polymarket/clob-client` (TS v1) @ `f89dea7` — `src/client.ts:1415-1456`
- `Polymarket/rs-clob-client-v2` @ `8ba5008` — `src/clob/client.rs:2486-2530`
- Frontend bundle `06yo__3skxzq9.js` @ ~line 58670: `eE="/auth/builder-api-key"`,
  `eG="POST"`. Settings UI calls `clobClient.createBuilderApiKey()` from the
  bundled `@polymarket/clob-client-v2`.

### Polydart wiring sketch

`lib/src/clob/clob_client.dart` already has `createApiKey` (uses L1 headers)
and `_l2GetList` / `_l2PostJson` style helpers (use L2 headers). The new
method follows the L2 pattern exactly:

```dart
/// Mints a CLOB builder-fee API key via `POST /auth/builder-api-key`.
///
/// Caller must already have an L2 [ApiKey] minted via [createOrDeriveApiKey].
/// The returned triple is the builder-fee key — attach its `key` to the
/// `builder` bytes32 field of V2 orders to claim integrator fees.
///
/// Headless. Same HMAC auth as every other L2 endpoint.
Future<ApiKey> createBuilderApiKey({required ApiKey apiKey}) async {
  final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
  final headers = buildL2Headers(
    apiKey: apiKey,
    timestamp: ts,
    method: 'POST',
    path: '/auth/builder-api-key',
    body: null,
  );
  final body = await _transport.postJson(
    '/auth/builder-api-key',
    const <String, dynamic>{},
    headers: headers,
  );
  return _parseApiKey(body);
}
```

Plus companion methods if we want full parity with the official SDKs:
`getBuilderApiKeys()` (`GET /auth/builder-api-keys`), `revokeBuilderApiKey({String key})`
(`DELETE /auth/builder-api-key/{key}`). The frontend bundle has all three
paths visible.

Polygolem mirror: `internal/clob/client.go` already exposes
`CreateOrDeriveAPIKey`. In Polydart, the equivalent addition must stay
wallet-mediated: accept a `WalletSigner` or prebuilt L1 headers plus the CLOB
`ApiKey`, never local key material.

## Relayer API Key — `/relayer/api/auth`

### Wire format

```http
POST https://relayer-v2.polymarket.com/relayer/api/auth
Cookie: <Polymarket session cookie>
Accept: application/json
Content-Type: application/json

{}
```

The frontend uses a direct `axios.post(url, {}, { withCredentials: true })`
— **no signature, no Authorization header, no payload**. The server
identifies the wallet purely from the session cookie.

### Cookie gate — `/login/internal`

Historical note: this section is superseded by the 2026-05-08 addendum below.
The addendum found that `/login/internal` is not the browser login gate; the
replicable path is Gamma SIWE login followed by Relayer V2 API-key minting.

The session cookie is acquired from `/login/internal`, characterized by
the frontend agent as a "browser-mediated wallet challenge." We have **not**
yet characterized exactly what that challenge looks like:

- Is it a SIWE-style nonce-and-sign flow that any HTTP client + EOA signer
  can replicate? (If yes — fully headless onboarding is achievable.)
- Or is it a multi-step flow with CSRF tokens, browser TLS fingerprinting,
  reCAPTCHA, or other anti-automation? (If yes — this is a genuine gate
  and we accept it.)

This is the **single open question** that determines whether headless
onboarding is fully feasible. Characterizing `/login/internal` is the
recommended next step.

### What it gates

`relayer-v2/submit` — used by:
- `WALLET-CREATE` (deposit-wallet deploy)
- `WALLET` batch (V2 spender approvals)
- Any other relayer-paid transaction we'd issue on the user's behalf.

The relayer client already in `polygolem/internal/relayer` and the
`lib/src/relayer/relayer_client.dart` in polydart can both **use** an
existing Relayer API Key triple. The addendum below documents the cookie path;
Polydart now mints this key through `LiveCredentialService.ensure()`.

## Recommendations

### Short-term (do now)

1. **Wire `/auth/builder-api-key` in polydart** — `lib/src/clob/clob_client.dart`
   gains `createBuilderApiKey`, `getBuilderApiKeys`, `revokeBuilderApiKey`.
   Tests against a `MockClient` that asserts L2 headers and the empty body.
2. **Mirror in polygolem** — `internal/clob/client.go` adds the same three
   methods plus the current `polygolem exchange create-builder-fee-key` CLI
   command.
3. **Update `BUILDER-AUTO.md`** — split the "Builder API Keys" label into
   the two distinct creds. Document that `builder-keys auto` mints L2 creds and
   that `exchange create-builder-fee-key` is an optional follow-up for fee
   attribution.
4. **Persist** — extend the env-file format to support `POLY_BUILDER_*`
   and `POLY_RELAYER_*` separately. Polydart's `BuilderConfig` already
   has the right shape; just rename / clarify field semantics.

### Medium-term (sub-investigation)

5. **Characterize `/login/internal`.** One more focused pass at the
   frontend bundle, looking specifically for the wallet challenge handler.
   Output: endpoint sequence, payload shapes, signature scheme, CSRF or
   other anti-automation. Decision: implement headlessly, or accept the
   browser step and document it cleanly.

### Out of scope for this investigation

- Live HTTP probing of `/login/internal` or `/relayer/api/auth`. Those
  require either a session cookie or a planned write attempt — both
  ruled out by the "code-only, no production calls" constraint.
- Changing how the existing `relayer-v2/submit` client works. It will
  start working as soon as we hand it a Relayer API Key triple — the
  question is just where the triple comes from.

## Open questions

1. Does `/login/internal` reduce to a SIWE-style challenge, or is it
   browser-fingerprinted? — see Recommendation 5.
2. Once we mint a CLOB builder-fee key, do existing V2 orders gain fee
   attribution automatically, or do we need to set the `builder` bytes32
   field explicitly per order? Polydart's `signedOrderPayload.builder`
   currently writes `bytes32Zero` — we need to swap that for the
   builder key when one is present.
3. Are CLOB builder-fee keys revocable per-order, or only globally? Affects
   error-recovery design.

## Addendum — `/login/internal` characterized (2026-05-08)

The original "browser-mediated wallet challenge" framing for `/login/internal`
was a misdiagnosis. A second static-analysis pass over the 49 MB Next.js
bundle (366 chunks from `https://polymarket.com/_next/static/chunks/`,
build `TfctsWXpff2fKS`) found that `/login/internal` is **not** the
user-login flow at all:

- It's an SSR bootstrap function inside the bundled `@polymarket/relayer-client`
  library — class `F.getPolymarketCookies()` at `06yo__3skxzq9.js` byte 1215641
  (10 duplicate copies in sibling chunks).
- It runs **server-side only** (`!isBrowser && !RELAYER_API_KEY` guard).
- Auth is a static **bearer token** read from SDK config; the host comes
  from `config.authUrl`, never hardcoded.
- It never executes in the browser.

### Verdict: SIWE-REPLICABLE

The actual flow that mints the Polymarket session cookie in the browser is
canonical EIP-4361 SIWE against `gamma-api.polymarket.com`. Six steps,
all reproducible from a Go or Dart HTTP client + EOA signer:

1. `GET https://gamma-api.polymarket.com/nonce` (`withCredentials: true`)
   → `{ nonce: "..." }`
2. Build the SIWE message via viem `createSiweMessage` with:
   - `domain: "polymarket.com"`
   - `statement: "Welcome to Polymarket! Sign to connect."`
   - `uri: window.location.origin`
   - `version: "1"`
   - `chainId, nonce, issuedAt`
   - `expirationTime: now + 7d`
   (Found at `06yo__3skxzq9.js` bytes 56500–58300.)
3. `personal_sign` the message with the EOA (wagmi `signMessage`,
   bundle byte 59450).
4. Construct the bearer token:
   `token = base64( JSON.stringify(siweFields) + ":::" + signature )`
5. `GET https://gamma-api.polymarket.com/login`
   - `Authorization: Bearer <token>`
   - `withCredentials: true`
   - Server responds `Set-Cookie: <polymarket session>` and body
     `{ type, address }`.
6. Subsequent `withCredentials: true` calls (including
   `POST relayer-v2.polymarket.com/relayer/api/auth` with body `{}`)
   ride that cookie and mint the Relayer API Key.

Magic-wallet users skip the personal_sign and ship a Magic DID-token
instead — that path remains browser-bound and out of scope.

### Anti-bot scan

Bundle-wide grep across all 49 MB for: `csrfToken`, `x-csrf`, `X-CSRF`,
`captcha`, `recaptcha`, `turnstile`, `hcaptcha`, `datadome`, `kasada`,
`cf_clearance`, `cf-turnstile`, `fingerprint`, `deviceId`, `x-device`,
`akamai`, `X-Magic`, `magic-id-token` → **zero hits**. The transport is
plain `axios.create({ withCredentials: true })`; no request interceptors
inject anti-bot headers.

### Caveats

- **CDN/WAF**: `gamma-api.polymarket.com` sits behind a CDN that may
  TLS-fingerprint or UA-rate-limit non-browser clients. Not visible from
  static JS analysis. We won't know until we try.
- **Magic-signed-up accounts** stay browser-bound (the SIWE step is
  replaced by a Magic-issued DID token from the Magic iframe).
- **Cookie persistence** matters: the Polymarket session cookie has a
  finite lifetime, so the headless flow must either re-run SIWE on
  expiry or persist the cookie alongside the API keys.

### Implication for headless onboarding

The full pipeline is reachable headlessly:

```
WalletSigner user approval
  → /auth/api-key (L1 ClobAuth)            → CLOB L2 creds
  → /auth/builder-api-key (L2 HMAC)         → CLOB Builder Fee Key
  → gamma-api/nonce                         → SIWE nonce
  → personal_sign + base64 token            → bearer
  → gamma-api/login                         → polymarket session cookie
  → relayer-v2/relayer/api/auth (cookie)    → Relayer API Key
  → relayer-v2/submit (Relayer API Key)     → deposit-wallet deploy + approvals
  → /order (sigtype 3)                      → live trade
```

Zero browser interactions. The work to wire it is bounded:

- Polygolem: SIWE message builder + viem-equivalent EIP-4361 spec, base64
  bearer token, transport that holds a cookie jar across `gamma-api/nonce`,
  `gamma-api/login`, and `relayer-v2/relayer/api/auth`.
- Polydart: `SIWESession.login()`, `mintV2APIKey()`, and
  `LiveCredentialService.ensure()` now cover the headless credential path with
  hand-rolled cookie handling and app-owned credential storage.

### Anchored evidence

- Report: `/tmp/login-internal-analysis.md`
- Bundle cache: `/tmp/pm-bundles/chunks2/` (366 files, 49 MB)
- Key chunk: `/tmp/pm-bundles/06yo__3skxzq9.js` (1.6 MB) — relayer-client
  SDK, AuthClient, SIWE builder, RestClient transport, `useSignIn`
  mutation
- Settings page chunk: `/tmp/pm-bundles/07oquscvwratq.js` (270 KB) —
  confirms the relayer-key mint is just
  `axios.post('/relayer/api/auth', {}, { withCredentials: true })`

## Reproducibility

To re-run the investigation:

- Survey: `/tmp/headless-builder-keys-survey.md` (full per-repo writeup
  with file:line citations).
- Frontend: `/tmp/polymarket-frontend-analysis.md` (full bundle trace
  with chunk hashes).
- This synthesis: `polydart/docs/HEADLESS-BUILDER-KEYS-INVESTIGATION.md`
  (you are here).
