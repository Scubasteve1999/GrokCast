# Cursor brief — Finish Codex handoff on real GrokCast

You are an iOS developer architect, master in design and app features/functions, specifically for Stephen's DayCast weather app.

**North star:** DayCast is the weather app you'd open in a real storm and trust. Honest local now/alerts, readable Site Doppler + National radar, fast/obvious on a normal iPhone. Don't chase AccuWeather's kitchen sink.

**do not use i-have-adhd**

## Context (read first)

Codex audited DayCast and built three slices **into the wrong tree**:

- Working dump: `/Users/bigstevedev/Projects/GrokCastLocal` (no git; older than `main`)
- Codex artifacts: `/Users/bigstevedev/Documents/Codex/2026-09-05/build-x20/`
  - `outputs/weather-correctness.patch` + `work/weather-slice/`
  - `outputs/radar-slice-1.patch` + `work/radar-slice/` (and GrokCastLocal has a further large-text finish)
  - `outputs/proxy-spending-controls.patch` + deployed Worker already live

**Real product repo (only land here):** `/Users/bigstevedev/Projects/GrokCast` on `main` (HEAD should be `ec0c650` or newer).  
`git apply --check` of the Codex patches **fails** against current `main` — port by intent, do not overwrite whole files from GrokCastLocal.

**Already done (do not redo):**
- Proxy spending controls **deployed** to `https://daycast-grok-proxy.stephendev.workers.dev` (version `57517d01-f640-42b9-b889-7e630fa144b8`). Preserve `QUOTA_START_DAY = "2026-09-06"`. Sync source into `server/grok-proxy/` so git matches production; do not redeploy unless asked.
- TestFlight **1.0.10 (157)** already VALID (locations paywall copy). No bump / no App Review in this slice.

## Goal (one user-visible + one correctness slice)

Land Codex's unfinished handoff onto real GrokCast:

1. **Weather correctness** — city/unit switching never shows mismatched weather.
2. **Radar Slice 1** — readable / easy controls (44pt hits, adjustable timeline, scalable HUD text, large Dynamic Type stacks Live / 24-hr / Layers). Keep map-first layout, blue accent, playback behavior, subscription logic.

Out of scope this slice: Radar Slice 2 (basemap contrast, Layers sheet reorder, Forecast·Pro label), App Store submit, new product features.

## Port instructions

### A) Weather correctness

Reference: `outputs/weather-correctness-slice.md`, `work/weather-slice/`, and the 10 new tests in Local `DayCastTests/WeatherStoreFallbackTests.swift`.

Into **current** `WeatherStore` / related files on GrokCast:

- Track selection (city + units + generation/revision); publish only if still matching.
- Clear/hide previous-city NWS/OWM immediately; reject late responses.
- Unit-aware cache / widget snapshots; never display F as C; untagged legacy snapshots refresh instead of guessing.
- Retry stays on selected city.
- Port injectable boundaries only as needed for the new tests.
- Add the 10 regressions; keep existing tests.

Touched files will likely include (verify against diff, don't invent extras):
`WeatherStore.swift`, `OpenMeteoService.swift`, `OpenMeteoModels.swift`, `WidgetWeatherSnapshot.swift`, `TodayView.swift` (only if Retry/selection wiring needs it), `WeatherStoreFallbackTests.swift`.

### B) Radar Slice 1

Reference: Local `DayCast/Features/Radar/*` (preferred — includes large-text finish) and `outputs/radar-design-audit.md`.

Port **behavior**, rebased onto current GrokCast radar (current panel still owns `showDisplayOptions` binding differently than Local):

- ≥44pt hit targets for Play, Recenter, Live, 24-hr, Layers (visual can stay compact).
- Timeline: 44pt interaction, VoiceOver adjustable with frame time value.
- Chase HUD: scalable location / scan age / alert hierarchy; don't crowd map at accessibility sizes.
- `slimModeRow` (or equivalent): at accessibility Dynamic Type, stack Live/24-hr and Layers on separate rows so they don't wrap awkwardly.
- `ViewThatFits` (or equivalent) so playback row can wrap speed picker under Play/time on narrow widths.
- Update `CriticalFlowsUITests.testRadarTabShowsLiveControls` for Live / Recenter / Layers / timeline + 44pt checks — **do not delete** other UITests that still exist on `main` (National product, etc.).

Do **not** blindly replace `RadarControlPanel.swift` from Local if it fights current Today/Radar architecture; merge carefully and keep GrokCast call sites compiling.

### C) Proxy source sync (no redeploy)

Copy missing/updated proxy modules from Local into `server/grok-proxy/` so the repo matches the deployed Worker (`quota-ledger.js`, `quota-object.js`, `request-policy.js`, `index.js`, tests, `DEPLOYMENT.md`). Do not change production secrets or `QUOTA_START_DAY`.

## Verify

Primary sim: **iPhone 16 on iOS 26.5** (UDID `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`). Also acceptable: iPhone 15 / 17 on iOS 26.5. Never iOS 27 beta.

1. Unit tests green (include new weather regressions).
2. Debug build.
3. UITest radar chrome (updated) green; do not regress other CriticalFlows tests without fixing them.
4. Manual: switch city fast + switch °F/°C offline/online — no stale other-city temps. Radar: Large Accessibility text — Live / 24-hr / Layers readable and tappable on a smaller phone width.

## Done means

- Commits on `Projects/GrokCast` `main` (or a PR branch if you prefer — say which).
- Weather mismatches gone under the listed tests.
- Radar Slice 1 readability/a11y landed with large-text mode row fix.
- Proxy source in git matches deployed spending-control Worker; **no** App Review / version bump unless asked.

## Report back

Files changed, test counts, any intentional deviation from Local (because `main` moved), and what's still open (Slice 2).
