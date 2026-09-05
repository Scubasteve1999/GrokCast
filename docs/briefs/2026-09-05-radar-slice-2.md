# Cursor brief — Radar Slice 2: visual polish + Layers organization

You are an iOS developer architect, master in design and app features/functions, specifically for Stephen's DayCast weather app.

**North star:** DayCast is the weather app you'd open in a real storm and trust. Honest local now/alerts, readable Site Doppler + National radar, fast/obvious on a normal iPhone. Don't chase AccuWeather's kitchen sink.

**do not use i-have-adhd**

## Context

Slice 1 (hit targets, timeline a11y, HUD hierarchy, large-text Live/24-hr/Layers stack) is already on `main` via PR #29 (`f55e947`).

Design audit: `docs/codex-handoff-2026-09-05/radar-design-audit.md` — Medium findings only for this slice.

**Preserve:** large map, compact bottom panel, blue accent, radar data/paint behavior, playback behavior, subscription/entitlement logic (Yearly still owns Future; Monthly does not).

## Goal

Radar Slice 2 — visual polish and organization:

1. **Basemap contrast** — roads and town names read better on Light (and Dark if needed) without washing out precip. Rain stays visually dominant.
2. **Layers sheet** — title **“Layers & display”**; lead with product/layer selection and opacity; group playback preferences (auto-resume, Map only) separately below or in their own section.
3. **Forecast access clarity** — for users **without** Yearly Future access, the 24-hr control must look locked / Pro **before** tap (e.g. “24-hr · Pro” or lock affordance). Do **not** change who can unlock Future; keep `requestModeChange` → `.radarFuture` paywall.

Done when: rain remains dominant, settings are easy to find in Layers, and non-Yearly users can tell Future needs Pro before tapping.

## Implementation notes

### A) Basemap / labels
- Primary files: `RadarMapStyle.swift` (quiet workstation punch/halo constants), and wherever style layers are applied after load (`RadarMapboxRepresentable` / related).
- Audit said Light looks washed out. Tune label/road contrast (halo width/color, text opacity, road line prominence if already controlled) for Light; verify Dark still works.
- Check dense-rain and sparse-rain mentally against Site Doppler + National — precip must stay on top of geography, not the reverse.
- Do not invent new Mapbox style URIs; stay on existing `RadarBaseMapStyle` cases.

### B) Layers sheet reorder
- `RadarDisplayOptionsSheet` in `RadarControlPanel.swift` (navigationTitle currently `"Display"`).
- Suggested section order:
  1. **Products** (Rain / Detail rain / Storm winds) + short footer as today
  2. **Opacity** (move up from bottom)
  3. **Map** (overlay / fire / lightning / base map)
  4. **Legend** (+ Colors if shown)
  5. **Playback / view** (auto-resume, Map only) — not first
  6. Explain radar (can stay near products or at end)
- Rename title to **Layers & display**. Keep detents `.medium` / `.large`.

### C) Future chip Pro affordance
- `RadarChromeCopy.futureChip` is `"24-hr"`; mode pills in `liveForecastPicker` / `modePill`.
- For `!EntitlementChecker.canUseYearlyExtras(...)` (same rule as `RadarState.requestModeChange`), show a clear Pro/lock presentation on the 24-hr control **without** hiding it (unlike Today Outlook Future pill hide — Radar tab still shows the entry so users can upgrade).
- Accessibility label should say Future requires Pro / Yearly when locked.
- Yearly (and developer key) keeps current selected appearance with no lock chrome.

## Out of scope

- Slice 1 rework, weather store, proxy, App Store, TestFlight bump, entitlement changes, Radar Slice cache-race list from older handoff docs.

## Verify

Primary sim: **iPhone 16 on iOS 26.5** (`8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`). Never iOS 27 beta.

1. Build Debug.
2. Free or Monthly: 24-hr shows Pro/lock affordance; tap still opens `.radarFuture` paywall; Live unaffected.
3. Yearly (or sandbox): 24-hr looks unlocked; Future still works.
4. Layers sheet: title “Layers & display”; products + opacity near top; auto-resume / Map only not first.
5. Light basemap: roads/towns more readable; precip still dominates in rain.

## Done means

Branch + PR (or commit on main if that’s the repo habit). Short report: files changed, before/after notes for Layers order and Future chip, any basemap constant tweaks.

## Report back

Files, test/build status, screenshots if easy, what’s still open.
