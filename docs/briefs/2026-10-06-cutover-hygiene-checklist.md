# Cutover hygiene checklist — RRFS/REFS go-live (Dig 5)

**Status: Done (2026-10-06).** Shipped in `e4bb878`; pushed to `main`. Tests green: 928 unit, 9 UI (UI fixes in `aa5a1b3`, `8a3cb60`, `6006dec`).

Repo: `~/Projects/GrokCast`. Cutover: Wed Oct 14, 2026, 1200 UTC (SCN 26-48 AAD). Same day NAM, SREF, HREF, HiresW (except Guam) retire; RAP and HRRR stay. Slip rule: if Oct 14 is a Critical Weather Day / Enhanced Caution, NWS moves to 1200 UTC on the next clear weekday.

## Found
Swept `DayCast/`, `DayCastWidgets/`, `DayCastTests/`, `DayCastUITests/`, `server/` (no node_modules), `Scripts/`, `docs/` for NAM / NAM MOS / SREF / HREF / HiresW labels, NOMADS `…/com/nam|sref|href|hiresw/prod` paths, and model-picker defaults.

- No NOMADS URLs and no `/com/<model>/prod` paths anywhere.
- No model picker. The only model constant is `OpenMeteoEnsembleService.model = "icon_seamless"` (not NCEP).
- No help/glossary text calling retiring models "current". `docs/*.html` clean.
- Only live mentions:
  - `ForecastEraNotice.swift` Copy (opener / cite): already status-aware, past tense in `.done`.
  - `AppLinks.swift:23`: SCN 26-47 weather.gov PDF (clickable, in-app Safari).
  - `XweatherRadarLayer.swift:10`: comment, "GFS, NAM, or HRRR".

## Changed
- `ForecastEraNotice.Copy.retiringStaying` added and placed right after the opener in `paragraphs`:
  "Retiring that day: NAM, HREF, SREF, and HiresW (except Guam). Staying: RAP, HRRR, and HiresW Guam."
  Shown in scheduled / slipped / done. Card view unchanged (it renders every paragraph).
- Test `testRetiringStayingLineShowsForEveryStatus` covers all three statuses and guards against "HRRR is…", "all HiresW", "October 6".

## Left (and why)
- SCN 26-47 PDF link: official, stable weather.gov document about the retirement; not a NOMADS product. Not a dead link.
- Xweather `fradar` comment: documents a vendor layer; no user-facing NAM button exists. Future radar untouched.
- Open-Meteo HRRR minutecast: untouched (HRRR stays).
- No date-gated hide: there is no clickable legacy label/path to hide, so nothing to test before/after cutover.
- Opener / cite wording: unchanged (already lists retiring names; past tense once `.done`).

## Ops
Slip the date (needs a NEW id, `status: "slipped"`, new `cutoverUTC`), from `server/refs-agreement`:

```bash
npx wrangler kv key put --binding=ERA_NOTICE current '{"id":"scn-26-48-2026-10-15","cutoverUTC":"2026-10-15T12:00:00Z","windowStartUTC":"2026-10-07T12:00:00Z","windowEndUTC":"2026-10-28T12:00:00Z","status":"slipped","updatedAt":"2026-10-13T18:00:00Z"}'
```

Phones pick it up within ~15 min (`GET https://daycast-refs-agreement.stephendev.workers.dev/era-notice`, `max-age=900`).

Ops note: check NWS CWD Oct 13–15.
