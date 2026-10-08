# REFS agreement worker

Point JSON for the DayCast timing chip. The phone fetches this payload only. GRIB stays here.

Source is the NOAA operational parallel bucket `s3://noaa-rrfs-ops-pds` (HTTPS, no AWS account):

`refs.YYYYMMDD/HH/ensprod/refs.tHHz.eas.fFFF.{conus|ak|hi|pr}.grib2`

The 1-hour light-precip field is the `eas` message `APCP … prob >0.254 … process=197`. The worker reads the `.idx`, byte-ranges that message, and decodes one grid point. HRRR hourly precip, when the point is in CONUS or Alaska, comes from `s3://noaa-hrrr-bdp-pds` the same way. A HRRR miss leaves the REFS window up without a divergence sentence.

`parallel` is `true` until 2026-11-03 12:00 UTC (SCN 26-48 Updated AAE moved it from Oct 14).

## Endpoints

- `GET /health`
- `GET /era-notice` — RRFS/REFS banner dates. `Cache-Control: public, max-age=900`.
- `GET /v1/agreement?lat=&lon=&tz=America/Chicago&hours=12`
- `GET /v1/agreement?stub=1` — documented sample, `stub: true`, `parallel: true`. Not a live extract.

Hours are model hours, never a minute clock. Labels in the JSON are `REFS` and `HRRR` only.

## Deploy

From this directory, with Wrangler logged into the Cloudflare account that already hosts `daycast-grok-proxy`:

```bash
npm install
npx wrangler deploy
```

No secrets. Then set the origin (no trailing slash) in `DayCast/Shared/Configuration/RefsAgreementConfiguration.swift`:

```swift
static let productionBaseURL = "https://daycast-refs-agreement.<account>.workers.dev"
```

Until that string is set, the chip stays hidden. DEBUG → Settings → Developer → “Force REFS agreement” shows the sample sentence without a worker.

## Era notice (slip-date)

`GET /era-notice` is the Today banner / “What this means” dates. The worker reads KV `ERA_NOTICE` key `current`. A miss or invalid payload returns the app’s baked-in defaults (November 3, `slipped`).

Move the date without an app release (from this directory, after `npx wrangler deploy`):

```bash
npx wrangler kv key put --binding=ERA_NOTICE current '{"id":"scn-26-48-2026-10-15","cutoverUTC":"2026-10-15T12:00:00Z","windowStartUTC":"2026-10-07T12:00:00Z","windowEndUTC":"2026-10-28T12:00:00Z","status":"slipped","updatedAt":"2026-10-13T18:00:00Z"}'
```

`status` is `scheduled`, `slipped`, or `done`. A new `id` re-shows a dismissed banner. Phones pick up a change within about 15 minutes.

## Tests

```bash
npm test
```

The Hawaii fixture is a real `eas` message. Grid indexes were checked against eccodes nearest-neighbor for CONUS, Alaska, Hawaii, and Puerto Rico.
