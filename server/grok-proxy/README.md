# DayCast Pro — Grok proxy

Cloudflare Worker that forwards xAI requests on behalf of verified DayCast Pro
subscribers. It exists so the xAI key stops shipping inside the app binary.

## How access works

The app sends two things:

| Header | Purpose |
|---|---|
| `Authorization: Bearer <PROXY_SECRET>` | Coarse gate. Shipped in the binary, so **treat it as public** — it stops idle scanning, nothing more. |
| `X-DayCast-Transaction: <JWS>` | The actual credential: a StoreKit 2 signed transaction (`VerificationResult.jwsRepresentation`). |

Every request verifies the JWS from scratch — certificate chain to a pinned copy of
**Apple Root CA - G3**, then the ES256 signature, then the payload (bundle id, Pro
product id, environment, not revoked, not expired, signed recently). A leaked
`PROXY_SECRET` on its own buys nothing, because only Apple can mint a valid JWS.

Rate limiting keys off `originalTransactionId` from the *verified* payload, never a
client-supplied header, so it survives renewals and can't be spoofed.

`signedDate` must be within 30 days. Apple re-signs on every entitlement refresh, so
this is what stops a refunded subscriber replaying a token minted before the refund.

## Endpoints

Only these paths exist. Anything else is a 404. xAI is reached only by the two
POST routes — a leaked secret must not expose the rest of the xAI API.

| Path | Auth | Notes |
|---|---|---|
| `POST /v1/chat/completions` | Bearer + JWS | Chat, briefs, radar explanations, storm photo vision. Streams SSE through untouched. |
| `POST /v1/images/generations` | Bearer + JWS | Imagine. Separate, much smaller budget. |
| `GET /v1/owm/*` | Bearer only | OpenWeatherMap proxy. No StoreKit check — weather is free. Allowlisted upstream paths only: `/data/4.0/onecall/current`, `/data/4.0/onecall/timeline/1h`, `/data/4.0/onecall/timeline/15min`, `/data/2.5/weather`, `/data/2.5/forecast`. Cache TTL `OWM_CACHE_TTL`; daily cap `OWM_DAILY_LIMIT`. |
| `GET /v1/status` | Bearer | Usage snapshot `{ ok, disabled, usage }`. Does not consume quota. |
| `GET /v1/alert` | none | `{ over, day, lastRollup }`. `over` is whether today crossed `ALERT_THRESHOLD`. `lastRollup` is the last day the cron wrote a report — an external checker can use it to see if the trigger is still alive. No usage figures. |
| `GET /v1/health` | none | Unauthenticated liveness. Returns `{ ok, disabled }` only. |

## Daily rollup

A Cloudflare cron (`59 23 * * *` UTC, declared in `wrangler.toml`) calls
`scheduled` → `runDailyRollup`. That writes a 30-day KV report and logs the
totals (`wrangler tail`). There is no email or notification channel. Check
`GET /v1/alert` (`lastRollup`) to confirm the trigger is still firing.

The cron is config only until the worker is deployed — `npx wrangler deploy`
is what actually registers it on Cloudflare.

## Limits

Three independent controls, all daily and all resetting at UTC midnight:

- `DAILY_CHAT_LIMIT` (default 150) per subscriber
- `DAILY_IMAGE_LIMIT` (default 10) per subscriber
- `GLOBAL_DAILY_LIMIT` (default 5000) across everyone — the one that actually bounds the bill

Responses carry `X-DayCast-Limit`, `-Remaining`, and `-Reset`. Subscriber exhaustion returns
429; global capacity exhaustion returns 503. SQLite-backed `DailyQuota` Durable Objects
reserve subscriber and global allowances atomically, one object per UTC budget day.
Only quota operations go through the object; xAI streaming stays in the Worker.

A reservation ID makes refunds idempotent. Explicit upstream 4xx rejections release both
allowances. Transport errors, timeouts, 5xx responses, and failures after successful stream
headers keep the reservation: the provider may already have billed the work. Quota-store
failures fail closed and never fall back to KV. KV now stores daily reports, not live quotas.
OpenWeatherMap cache misses use a separate atomic bucket, outside the AI global count.

The proxy accepts only the current app models (`grok-3-mini`, `grok-4.3`, and
`grok-imagine-image-quality`). Chat output defaults to 1,024 tokens and is capped at 4,096;
images are limited to one URL result. Input is bounded to 4 MiB, 64 messages, and 32,000
text characters (image prompts: 8,000). Vision accepts one embedded JPEG. Unknown fields,
remote image URLs, alternate token-limit fields, tools, and query overrides are rejected
before quota reservation. These are request/size controls, not a dollar-denominated budget.

## Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for the first SQLite migration and midnight cutover.
Production already uses `QUOTA_START_DAY = "2026-09-06"` — keep that date. The entrypoint
is `src/index.js`, which exports the Worker and `DailyQuota` class. Do not redeploy from
this source sync unless asked.

## Kill switch

The lever that works without an App Store release:

```bash
npx wrangler deploy --var DISABLED:1
```

All AI returns 503 `service_disabled`. OpenWeatherMap uses the separate `OWM_DISABLED` switch.

## Tests

```bash
npm test
```

Tests use Node 24 (including built-in SQLite), with no new runtime dependencies. Certificate parsing and ECDSA verification are built
on WebCrypto so the same code runs under Workers and `node:test`.

Tests sign against a **throwaway** chain (root → intermediate → P-256 leaf) generated by
`test/fixtures/generate.sh`. It holds private keys, so it is gitignored and regenerated
on demand — `npm test` builds it automatically if missing (needs `openssl`). One test
asserts the real Apple root *rejects* that test chain, which is what proves the pinning
is load-bearing.
