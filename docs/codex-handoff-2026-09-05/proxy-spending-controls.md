> Update: deployed September 5, 2026; automatic activation at 7:00 p.m. Chicago time. See proxy-deployment-result.md. The preparation record below predates deployment.

# DayCast proxy spending controls

Implemented in `/Users/bigstevedev/Projects/GrokCastLocal/server/grok-proxy`. Production has not been deployed or changed.

## Defects addressed

- Replaced non-atomic KV quota updates with a SQLite Durable Object per UTC day. Subscriber and global AI allowances are checked and reserved in one transaction; global rejection consumes no subscriber allowance.
- Refunds use reservation IDs and are idempotent. Explicit provider 4xx rejections return both credits. Ambiguous transport failures, 5xx responses, and interrupted successful streams retain credits to avoid granting potentially billed work twice.
- Added strict request validation before reservation: approved existing app models only, 4 MiB body limit enforced while reading, 32,000 total chat text characters, 1–64 messages, maximum 4,096 output tokens, one embedded JPEG for vision, and one image output. Unsupported fields, remote image URLs, and query overrides are rejected.
- OpenWeather has an independent atomic allowance. Missing storage or an invalid activation date fails closed. Existing entitlement verification is preserved.

These controls bound request counts and input/output sizes; they are not an exact dollar ledger.

## Verification

- 104 automated proxy tests passed in staging, including valid app payloads, invalid requests, authentication, quota races, rollback, refunds, reporting, and UTC rollover.
- Actual local Cloudflare runtime using the existing locked Wrangler 4.118.0: 100 concurrent reservations admitted exactly 7 with a global limit of 7; ten repeated refunds returned one credit; a replacement reservation restored the count to 7.
- Persisted count of 7 survived a runtime restart and was readable with the locked Wrangler version.
- Production bundle dry run passed with the QUOTAS binding and SQLite migration. No provider calls or production deployment were performed.
- No dependency was added or upgraded. Tests now require Node 24 for built-in SQLite.

## Deployment boundary

`QUOTA_START_DAY` is intentionally empty until a UTC cutover date is selected. Deploying this configuration unchanged disables forwarding. Follow the accompanying deployment guide: stop legacy admissions, drain outstanding requests, and switch fully to the new ledger at UTC midnight. Avoid a traffic split or rollback to legacy KV counters after new traffic begins.

The daily report runs at 23:59 UTC and omits the final minute. Reservations are retained for three days; report snapshots for 30 days.

## Files

- `proxy-spending-controls.patch`: complete reviewable patch for this slice.
- `proxy-deployment.md`: deployment and rollback procedure.
- `proxy-tests.log`: final tests run against the applied source.
- `proxy-runtime-verification.json`: local concurrency and persistence evidence.
