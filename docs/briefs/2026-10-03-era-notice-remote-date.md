# Brief: RRFS/REFS banner date from remote config (slip-date watch)

Repo: /Users/stephenmoore/Projects/GrokCast (Scubasteve1999/GrokCast), branch off main (1.0.13 / 169).
Skills: architect + north star + daycast skill. Do not use i-have-adhd.

## Goal
If NWS declares Oct 14 a Critical Weather Day and moves the RRFS/REFS cutover, the Today banner and the "What this means" card must show the new date the same day, with no app update. Today the dates are hardcoded in `DayCast/Features/Today/Feed/ForecastEraNotice.swift`.

## Server (existing worker `server/refs-agreement`, deployed at https://daycast-refs-agreement.stephendev.workers.dev)
1. Add `GET /era-notice`. It returns JSON:
   `{ "id": "scn-26-48-2026-10-14", "cutoverUTC": "2026-10-14T12:00:00Z", "windowStartUTC": "2026-10-07T12:00:00Z", "windowEndUTC": "2026-10-28T12:00:00Z", "status": "scheduled", "updatedAt": "..." }`
   `status` is one of `scheduled`, `slipped`, or `done`.
2. Read the value from a KV namespace `ERA_NOTICE`, key `current`. If it is missing, return the defaults above, which match today's hardcoded values.
3. Send `Cache-Control: public, max-age=900` so a change reaches phones within about 15 minutes.
4. Validate on read: dates must be ISO and lie between 2026-10-01 and 2026-12-31, and start must be before cutover, which must be before end. If any check fails, return the defaults.
5. Add tests in `server/refs-agreement/test`. Add a README section with the one command that moves the date, for example:
   `npx wrangler kv key put --binding=ERA_NOTICE current '{...}'`

## App
1. `ForecastEraNotice` keeps the current constants as fallback. Add an `EraNoticeConfig` that is Codable and has the same fields.
2. Fetch `/era-notice` on app launch and on Today refresh, at most once every 15 minutes. Reuse the base URL from `RefsAgreementConfiguration.productionBaseURL`. Cache the last good value in UserDefaults.
3. On a network error, use the cache, then the constants. Never show an error and never block Today.
4. Apply the same sanity checks in the app. If the remote dates are out of bounds, use the constants.
5. `isInWindow`, `shouldShowBanner`, and `shouldOfferExplainer` read the effective config.
6. The dismiss key uses the remote `id`. A slipped date ships a new id, which re-shows the banner once.
7. Build the copy from the effective cutover date, formatted as a date in the user's locale:
   - scheduled: "On or around {date}, NCEP is replacing older short-range systems…" (current text, with the date filled in).
   - slipped: "NWS moved the switch to {date} after a Critical Weather Day. NCEP is replacing…"
   - done: "On {date}, NCEP replaced older short-range systems…"
   - Keep the timingRisk, notOfficial, and cite lines and both SCN links.
8. Don't touch HonestyStrip or the REFS timing chip.
9. Add unit tests:
   - Remote slip to 2026-10-15 shows the new date and a new id re-shows the banner.
   - Bad JSON or out-of-bounds dates fall back to the constants.
   - Offline uses the cache.
   - The DEBUG force-show still works.

## Ship
- Bump to 1.0.14 (170) and regenerate the project with XcodeGen (`/tmp/xcodegen-bin/xcodegen/bin/xcodegen`, or `brew install xcodegen`).
- Keep the minimum iOS at 18.0. Verify on the iPhone 17 iOS 27.0 sim.
- This only helps if 1.0.14 is live before Oct 14, so it has to be submitted by about Oct 8.
- Deploy the worker before the app ships. Old 1.0.13 phones keep the hardcoded Oct 14 date.

## Done when
- `curl https://daycast-refs-agreement.stephendev.workers.dev/era-notice` returns the defaults.
- Putting a slipped value in KV changes the sim's banner and card date within 15 minutes, with no rebuild.
- Tests are green and a PR is open.
