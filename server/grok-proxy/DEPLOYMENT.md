# Atomic quota cutover

Production is already live (2026-09-05) at `https://daycast-grok-proxy.stephendev.workers.dev`
with `QUOTA_START_DAY = "2026-09-06"`. Preserve that date on later deploys. Do not
return to KV counters after this version has served traffic.

## What changes

`src/index.js` exports `DailyQuota`, bound as `QUOTAS` with migration tag `quota-v1`
and `new_sqlite_classes`. The existing `USAGE` KV namespace and secrets stay in place.
No iOS release or entitlement change is required. Node 24 is required for the test suite.
The existing Wrangler version remains locked; no new dependency is introduced.

One SQLite object owns one UTC day's combined budget. Reserve checks subscriber and
global limits and writes one reservation in a synchronous transaction. Refund marks that
reservation once, releasing both counters. All upstream I/O happens outside the object.
The OWM bucket is independent of the AI global limit. Records expire after three days;
the daily KV rollup is retained for 30 days. The configured cron runs at 23:59 UTC, so its
report is a near-end-of-day snapshot (it omits the final minute), not an accounting total.

## First deployment — avoid granting a second budget on cutover day

Legacy KV counters cannot provide a trustworthy atomic starting balance. Do not reset
allowances in the middle of an active day. An empty `QUOTA_START_DAY` fails closed
deliberately.

1. Choose a UTC midnight cutover. Shortly before midnight, use the existing deployment
   process to set `DISABLED=1` and `OWM_DISABLED=1` on the old Worker. Stop old admissions
   and allow at least 120 seconds for in-flight requests to finish. Keep the old deployment
   disabled throughout the transition; allow additional time if requests remain in flight.
2. Set `QUOTA_START_DAY` in the new configuration to that next UTC calendar date
   (`YYYY-MM-DD`). Set both kill switches to 0. Preserve the existing quota limits,
   allowed environments, KV binding, and secrets. The activation gate will refuse forwarding
   before the chosen day even if this version is deployed early.
3. Run `npm ci`, `npm test`, and `npx wrangler deploy --dry-run` against the final configuration.
   Review the `QUOTAS` binding and `quota-v1` SQLite migration. Use the production
   `wrangler.toml`; never deploy `test/runtime.toml`, which exposes a local test harness.
4. After approval, deploy the new version as an immediate/full rollout before the chosen
   midnight: `npx wrangler deploy`. Do not split traffic with the old KV-metered version.
   Do not delete or rename the SQLite migration on later releases.
5. Verify after midnight with a legitimate test subscriber: approved chat and image requests
   work, usage appears in `/v1/status`, invalid bodies are rejected without changing usage,
   and the new counters increase. Validate live AI only within an explicitly approved
   spending allowance. Check scheduled rollups and error logs separately.

Keep `QUOTA_START_DAY` unchanged on subsequent deployments. It is a one-time activation
boundary, not a daily reset setting. After the new version has served traffic, rollback must
preserve the SQLite quota path or disable forwarding. Returning to the old KV-counter
version would reopen the original spending defect and discard the current reservations.

## Refund semantics and operational limits

Explicit xAI 4xx rejections return both quota credits. Repeating a refund is harmless,
including retrying an RPC whose reply was lost. A transport timeout, 5xx, or error after
successful stream headers retains the reservation because the provider may have billed
work. A crash between reservation and forwarding can also retain a credit: protection
fails closed rather than guessing whether money was spent. No client-supplied request ID
can bypass reservation; the Worker creates its own UUID for each admission.

These are bounded request and input/output-size budgets, not an exact currency ledger.
Model prices and provider-side billing remain external. A single daily budget is deliberately
serialized for exact global admission; provider streaming never uses that coordinator.

## Local verification without provider calls

```sh
npm ci
npm test
npx wrangler dev --local --config test/runtime.toml --port 8797 --persist-to /tmp/daycast-quota-test
```

In a second terminal, run `node test/runtime-check.mjs`. It submits 100 simultaneous local
reservations with a limit of 7 and repeats a refund ten times. Restart the same local
runtime/storage, then run `node test/runtime-check.mjs <day-from-first-output>` to verify
persistence. The harness never calls xAI or changes a Cloudflare account.

References: [SQLite transactions](https://developers.cloudflare.com/durable-objects/api/sqlite-storage-api/)
and [Durable Object migrations](https://developers.cloudflare.com/durable-objects/reference/durable-objects-migrations/).
