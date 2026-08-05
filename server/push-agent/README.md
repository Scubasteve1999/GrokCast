# DayCast — push agent

Cloudflare Worker, built on the [Agents SDK](https://developers.cloudflare.com/agents/),
that watches NWS alerts and delivers APNs pushes to DayCast devices.

It exists because the on-device notification services can only fire when iOS chooses
to wake the app. `AlertNotificationService` posts a great tornado warning — but only
if the app happened to refresh. This worker polls with the app closed and pushes.

Separate from [`../grok-proxy`](../grok-proxy) on purpose: that worker is
dependency-free plain JS on KV, this one needs Durable Objects and the Agents SDK.
Keeping them apart means the AI proxy's blast radius does not grow.

## Model: one Durable Object per device

Each device gets its own `DeviceAgent` instance, keyed by a client-generated id.
That buys three things:

- **Isolation.** One device's stuck poll cannot delay anyone else's alert.
- **Per-device scheduling.** `scheduleEvery()` for the alert poll, and a self-rescheduling
  `schedule()` for the morning brief at the user's own wall-clock hour, in their own
  time zone. Cron would be UTC-only and would break twice a year on DST.
- **Durable state.** The APNs token, location, preferences, and the set of
  already-notified alert ids survive eviction, so a restart does not re-notify.

## What it sends

| Trigger | Push | Mirrors |
|---|---|---|
| `pollAlerts` every `ALERT_POLL_SECONDS` | New severe NWS alert | `AlertNotificationService` |
| `sendMorningBrief` daily at the user's hour | Forecast brief | `MorningBriefNotificationService` |
| `POST /v1/push/send` | Operator-authored message | — |
| `POST /v1/push/refresh` | Silent `content-available` wake | `PushNotificationService.didReceiveRemoteNotification` |

Titles, subtitles, 300/220-char truncation, thread ids, categories, and deep links are
reproduced from the Swift services in `src/notifications.ts`, so a server push and a
local one look identical and coalesce in Notification Center instead of stacking.

**Keep the two in sync.** `src/nws.ts` duplicates `NWSAlert.isSevereEvent`,
`.isWarning`, `.isLifeThreatening`, and `.expiresRelativeText`. If the Swift
classification changes, change it here too, or the same storm produces two different
notifications depending on which path fired. The tests pin the current behaviour.

## Not double-notifying

Both paths can notify for the same alert. Three things keep that in check:

- The first poll after registration **records without pushing** — the same baseline
  `AlertHistoryStore.hasCompletedInitialAlertSync()` establishes on-device. Enrolling
  mid-storm does not fire a burst for alerts the user already saw.
- `apns-collapse-id` is the NWS alert id, so an updated alert replaces rather than
  repeats.
- Moving location re-baselines. A new place means a new set of active alerts, and
  none of them are news to the user.

It does **not** coordinate with the device's own `AlertHistoryStore`. Run one or the
other for a given alert type, or accept an occasional duplicate.

## Endpoints

| Path | Auth | Notes |
|---|---|---|
| `POST /v1/push/register` | `PUSH_SECRET` | Idempotent. Call on launch and on any token/location/preference change. |
| `POST /v1/push/unregister` | `PUSH_SECRET` | Clears state, cancels schedules. |
| `POST /v1/push/status` | `PUSH_SECRET` | Diagnostics. Never returns the APNs token. |
| `POST /v1/push/send` | `ADMIN_SECRET` | Operator message to one device. |
| `POST /v1/push/refresh` | `ADMIN_SECRET` | Silent background wake. |
| `GET /v1/push/health` | none | `{ ok, disabled }` only. |

Anything else is a 404, checked before auth and before body parsing. Same reasoning as
grok-proxy's allowlist: a leaked secret must not expose a wider surface.

Register body:

```json
{
  "deviceId": "<32+ random URL-safe chars, from the Keychain>",
  "apnsToken": "<hex APNs device token>",
  "environment": "production",
  "latitude": 35.22,
  "longitude": -97.44,
  "locationName": "Norman",
  "timeZone": "America/Chicago",
  "alertsEnabled": true,
  "morningBriefEnabled": true,
  "morningBriefHour": 7,
  "soundsEnabled": true,
  "temperatureUnit": "fahrenheit"
}
```

`soundsEnabled` and `temperatureUnit` are device-local `UserDefaults`
(`GrokCastNotificationSounds`, unit preference) that the server has no other way to
read — the device has to report them or pushes drift from the in-app settings.

## What the secrets do and don't buy

`PUSH_SECRET` ships inside the app binary, so **treat it as public**, exactly like
grok-proxy's. It stops idle scanning and nothing more.

The thing that actually protects a device is `deviceId`: a random value generated on
first launch and kept in the Keychain, never `identifierForVendor`. Anyone holding
`PUSH_SECRET` can register *their own* device; only someone who knows a specific
`deviceId` can unregister or read the status of *that* device. So it must stay
unguessable — 32 random URL-safe characters or better.

If that ever needs to be stronger, the move is the one grok-proxy already made:
require `X-DayCast-Transaction` and verify the StoreKit JWS. That code is written
and tested in `../grok-proxy/src/appleTransaction.js`.

`ADMIN_SECRET` is operator-only and never ships in the app.

## Deploy

```bash
npm install
npx wrangler secret put APNS_KEY_P8      # contents of AuthKey_XXXXXXXXXX.p8
npx wrangler secret put APNS_KEY_ID      # 10-char Key ID
npx wrangler secret put APNS_TEAM_ID     # 10-char Team ID
npx wrangler secret put PUSH_SECRET      # long random string; also goes in the app
npx wrangler secret put ADMIN_SECRET     # operator-only
npx wrangler deploy
```

The APNs key is a **Key ID + .p8** from Apple Developer → Keys, with the Apple Push
Notification service capability. One key signs for every app on the team and does not
expire, unlike a certificate.

Verify:

```bash
curl -s https://<worker>.workers.dev/v1/push/health
```

`APNS_BUNDLE_ID` in `wrangler.jsonc` must equal the app's bundle id — APNs rejects a
mismatched `apns-topic` with `DeviceTokenNotForTopic`, which this worker reads as a
dead token and drops.

## Kill switch

```bash
npx wrangler deploy --var DISABLED:1
```

All delivery stops. Registration still succeeds, so devices stay enrolled and resume
when it flips back — the same shape as grok-proxy's switch.

## Tests

```bash
npm test
```

46 tests, no test-framework dependency. Node's built-in runner strips the types
directly, which is why the pure modules (`apns`, `nws`, `notifications`, `time`,
`auth`) hold no Workers-only imports — the same code runs under `workerd` and
`node --test`.

APNs signing is covered against a **throwaway** P-256 key generated per run, never a
committed one. Time-zone tests pin the morning brief across both 2026 US DST
transitions, half-hour offsets, and the date line.

```bash
npm run typecheck    # tsc --noEmit
```

## Local development

```bash
cp .dev.vars.example .dev.vars   # fill in; it is gitignored
npm run dev
```

Everything works locally **except the APNs leg**. APNs is HTTP/2-only and `workerd`
cannot make outbound HTTP/2 connections in local dev
([cloudflare/workerd#4841](https://github.com/cloudflare/workerd/issues/4841)), so
every send returns:

```json
{ "ok": false, "status": 0, "reason": "Network connection lost.", "tokenIsDead": false }
```

That is expected locally and works once deployed. It is deliberately treated as a
transient transport error, never as a dead token — otherwise a local test run would
teach the agent to throw away a perfectly good device token. Use
`npx wrangler dev --remote` or a deployed preview to exercise real delivery.

## Client side

`PushRegistrationService` (`GrokCast/Shared/Services/`) does the uploading. It syncs:

- immediately when the APNs token arrives,
- debounced (1.5s) when the location or any notification preference changes,
- on every foreground — which is what catches permission revoked in Settings, and a
  new time zone after travel.

Unchanged payloads never hit the network: the last successful registration body is
kept verbatim as a fingerprint. Losing notification permission triggers `unregister`
rather than leaving this worker polling NWS for a device that cannot display anything.

**It stays completely inert until `DeveloperAPIKey.pushAgentBaseURL` and
`pushAgentSharedSecret` are filled in.** Nothing is uploaded, and notifications remain
local-only. To turn it on after deploying:

```swift
// GrokCast/Config/DeveloperAPIKey.swift — gitignored
static let pushAgentBaseURL: String? = "https://<worker>.workers.dev/v1/push"
static let pushAgentSharedSecret: String? = "<the PUSH_SECRET you set above>"
```

Note the `/v1/push` suffix — the client appends `/register` and `/unregister`.

Failures are silent by design (`#if DEBUG` logging only): a push-agent outage must
never surface an error in a weather app whose local notifications still work.
