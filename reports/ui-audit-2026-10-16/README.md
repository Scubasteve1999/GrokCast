# DayCast UI / UX / Design Audit — 2026-10-16

**Scope:** every tab (Today, Forecast, Radar, Alerts, More → Sky Check / Locations / Settings, Paywall), app chrome, and Dynamic Type.
**Method:** Debug build on iPhone 17 Pro Max simulator (free tier, Olive Branch MS), screenshots in this folder, plus a line-by-line code review of every view against `DesignSystem.md` / `DesignTokens.swift`.
**Status:** findings only — no code changed.

Legend: 📷 = seen in the running app · 🔍 = found in code (file:line) · ✅ = I re-verified a code claim myself.

---

## Top 12 — fix these first

| # | Issue | Where | Why it matters |
|---|---|---|---|
| 1 | 📷 **Today hero truncates at large text sizes** — "Feels like · H · L" lost the low ("H 73° \|…") and the rain line cut mid-word; graph labels collide; hour labels become "…"; tab bar icons overlap labels. *Correction: the original "hero vanishes" note was wrong — that screenshot (`09`) was taken while Today was scrolled down.* **Fixed 2026-10-16:** supporting lines wrap at accessibility sizes (`10-today-ax5-after-fix.png`). Graph and tab bar collisions remain. | `NowFeedCard.swift`, `HourlyGraphView.swift:601-608`, `Tab.swift` | Low-vision users lose the low temperature and rain chance. |
| 2 | ~~📷 ~10 s blank screen on cold launch~~ **Not reproduced.** Warm relaunch shows content in ~2 s; the 10 s was the first launch of a fresh Debug install on a just-booted simulator. Measure on a device with a Release build (Xcode Organizer → Launch Time) before acting. | — | — |
| 3 | ✅ **Fixed 2026-10-16.** **"Use my own key" ships in Release but leads nowhere.** Button jumps to Settings, whose key field is `#if DEBUG` only. | `GrokAPIKeyEmptyStateView.swift:40-43`; `SettingsView.swift:87-90` | Dead end on the Pro upsell screen; looks broken next to "Unlock with Pro". Wrap in `#if DEBUG`. |
| 4 | ✅ **Fixed 2026-10-16.** **Alerts empty state says "NWS" for any location** — "No active or recent NWS alerts for London…", header "NWS · …". | `AlertsView.swift:417-425`, `AlertsActiveCopy.swift:55` | Violates hard rule #6 (NWS must stay silent outside the US) and implies coverage that doesn't exist. |
| 5 | 🔍 **Sky Check streams a reply, then the TypeSafe verifier can yank it** → "Couldn't show that reply." | `GrokAIViewModel.swift:150 → 286-327` | Users read text that then disappears. Hold a "Checking…" state (or blur) until the verdict, *or* verify per-chunk. This is the new verifier's UX seam. |
| 6 | **Fixed 2026-10-16.** 📷 **"Sunset" label draws on top of the current temp** in the hourly curve (Today and Forecast). | `HourlyGraphView.swift` annotation layout | Visible on every launch near sunset; looks like a rendering bug. See `01-today.png`, `03-forecast.png`. |
| 7 | **Reclassified:** the blurred band is intentional (see `LocationChipBar.plate`); scrolled text clipping under a pinned header is expected. Only the resting look over the photo is open — a taste call. 📷 **Content scrolls under an opaque grey "Near Me" band**, clipping card text (e.g. "REFS · HRRR" cut in half). | `LocationChipBar.swift:43,99,115` | Breaks the "photo is the stage" look and hides content. Use the material/scrim treatment or let the bar scroll away. |
| 8 | 📷 **Alerts "all clear" state feels broken:** tiny meta line, duplicated *Your News*, panel ends in a hard edge over an ominous storm photo. | `AlertsView.swift` empty/news layout | On a calm day the safety tab should *reassure*. Add a clear "All clear for Olive Branch" hero; pick a calm still for no-alert state. |
| 9 | **Fixed 2026-10-16** (12-hr no longer auto-plays with Reduce Motion; Live already opened paused). 🔍 **No Reduce Motion handling in Radar**; 12-hr loop autoplays. | `RadarState.swift:421, 527, 535` | Vestibular-safety issue; Today already respects it — Radar should too. |
| 10 | **Fixed 2026-10-16.** 🔍 **Tab bar has no `.isSelected` trait**; More-hub rows don't mark the active destination. | `Tab.swift:279-283`, `DesignComponents.swift:162-175` | VoiceOver users can't tell where they are. |
| 11 | 🔍 **Location permission denied/restricted = dead end** — no "search for a city" path. | `LocationPermissionView.swift:64-76`, `TodayView.swift:12-13, 223-262` | Users who decline location can't use the app at all. |
| 12 | 🔍 **Saved cities delete instantly** (trash, context menu, full swipe) — no confirm, no undo. | `LocationsView.swift:252, 265, 332-333` | Easy to lose data by accident. |

---

## Per-tab findings

### Today (`01`, `02`, `09`)
- 📷 Daily summary says **"Today overcast"** while the hero says **"Clear"** — contradictory at a glance (daily vs current condition; label it "Today overall" or reconcile).
- 📷 Your News headline grammar: *"There are elevated wildfire danger concerns"* — upstream NWS text; consider light cleanup or quoting it as a source.
- 📷 Hero jargon: "Upstream NWS model change moved to Nov 3, 2026, 6 AM CT" and "REFS · HRRR" sit in prime real estate. 🔍 `ForecastEraNotice.swift:230-243` is full of NCEP/NAM/HREF/RRFS. Lead with plain language.
- 📷 "Updated just now" is clipped vertically at the bottom of the hero.
- **Fixed 2026-10-16.** 🔍 Radar preview map: tap-only, no button trait; `OutlookRadarCopy.accessibilityLabel` is defined but never applied (`RadarFeedCard.swift:142, 224, 243-248`).
- 🔍 Hourly card exposes only the "Now" hour to VoiceOver (`HourlyFeedCard.swift:27`).
- 🔍 Forecast-era banner dismiss ✕ is 20×20pt (`ForecastEraNoticeBanner.swift:38-44`).
- 🔍 Future radar pill only appears when already entitled, so its paywall branch is unreachable (`RadarFeedCard.swift:293-295 vs 334`). *(UI observation only — no entitlement change proposed.)*
- 🔍 Stale data dims the whole hero to 0.7 opacity on a photo — contrast loss (`NowFeedCard.swift`).
- 🔍 Location chip bar is a non-scrolling `HStack`; several cities overflow/shrink (`LocationChipBar.swift:18-64`).
- 🔍 Token drift: `todayTempSize = 88` in code vs 72 in DesignSystem.md; Now glyph 56pt vs spec `widgetTemp(36)`. Decide which is right and update the other.
- 🔍 Copy: "Use my position" / "Use current location" / "Enable location" for one action; "This is not GPS yet."; "local Now"; unexplained "pts", "FRP"; "am/pm" vs "AM".

### Forecast (`03`)
- 📷✅ **Hourly rows carry a condition glyph per row** — DesignSystem §6 says hourly has *zero* (`ForecastHourlyList.swift:82-87`). 24 identical suns read as the "Minecraft strip" the spec warns against.
- 📷 Time formats mix: "7pm" in list vs "9PM" in graph.
- 📷 Selected metric chip (Temperature) is a solid white inverted pill — spec says selection is type weight.
- 📷 Daily detail labels the high as **"Temperature"** next to **"Low"** — should be "High".
- 📷 Daily strip duplicates Today's *This Week* almost exactly; Forecast could go deeper (precip timing, wind) instead of repeating.
- 📷 Unlabelled dash row between graph and hour labels reads as noise.
- 🔍 Daily chip icon 18pt (> 16pt limit) (`WeekDayChipStrip.swift:47-51`); day-detail sheet has a 44pt multicolor glyph = second hero glyph (`ForecastDayDetailSheet.swift:68-71`).
- 🔍 OpenWeatherMap comparison chip hardcodes °F, ignoring the unit setting (`OpenWeatherMapForecastChip.swift:19`) — **real bug for Celsius users**.
- 🔍 Retry buttons `.controlSize(.small)` < 44pt (`ForecastView.swift:115-122`).

### Radar (`04`)
- 📷 Live/12-hr and 1x/2x/3x are white inverted pills; Site Doppler/National use accent fill + rim — spec says type weight on `radarTrack` (`RadarControlPanel.swift:254-266, 329-341`, `RadarPlaybackControls.swift:122-139`).
- 📷 Lightning button shows **selected** while a banner says "Lightning temporarily unavailable" — contradictory state.
- 📷 Free user sees orange "12-hr radar is temporarily unavailable." for a feature that's locked to them anyway — two conflicting messages.
- 📷 HUD jargon: "SCAN 1m", "NQA" (raw site code). 🔍 VoiceOver reads "5m" as "5 meters" (`ChaseRadarHUD.swift:36-37`).
- 📷 Location chip truncates "Olive Branch,…" and map labels bleed through the glass.
- 📷 Control dock takes ~⅓ of the screen; duplicates (recenter ×2, Layers ×2, opacity ×2) (`RadarControlPanel.swift:101, 165, 189`).
- 🔍 Every outage says "Check connection and try again" even for provider outages (`RadarView.swift:449-478`, `RadarState.swift:289`).
- 🔍 Timestamps have no time zone and force `en_US_POSIX` (ignores 24-hour setting).
- 🔍 "Map only" doesn't hide the panel (`showsControlSheet` always true).
- 🔍 One mode, three names: "12-hr", "Forecast radar", "FUTURE"; DesignSystem.md still says "24-hr".
- ✅ Good: scrubber has adjustable action/value; icon buttons labelled with 44pt targets; velocity legend has text.

### Alerts (`05`)
- See Top 12 #4 and #8.
- 🔍 Alert detail screen ignores the token system entirely — raw black/white, ad-hoc 0.35 severity rim, radius 14 — a de facto 4th card style on the screen people open *during* danger (`AlertDetailView.swift:25-135`).
- 🔍 Event names forced `.uppercased()` (`AlertsView.swift:254`, `AlertDetailView.swift:39`).
- 🔍 Advisory vs Watch differ mostly by color at 0.12 tint — add a text severity label (`AlertsView.swift:296-298`).
- 🔍 Alert row isn't combined for VoiceOver and has no "opens details" hint (`AlertsView.swift:233-241`).
- 🔍 Copy: "Severe weather Warnings and Watches" casing; "Showing last known warnings" when cache holds advisories.

### More hub (`06`)
- 📷 Half the sheet repeats the current temp; only three rows. Either make it a plain list or give the header real value.
- 📷 "Sky Check — Included with DayCast Pro" doesn't say what it is ("Ask AI about your sky").
- 🔍 Destination screens set empty nav titles; tab still says "More"; no "you are here" marker.
- 🔍 Sky Check icon differs: `cloud.bolt.fill` (hub) vs `cloud.sun` (empty state/paywall).

### Sky Check (`07`)
- 📷 "Sky Check" title twice (screen + card). Upsell says Pro unlocks "…and Sky Check" while you're on Sky Check.
- 📷 Quick-prompt chips look disabled with no explanation; input field looks enabled for a free user.
- 📷 Disclaimer ("Not an NWS product…") is low-contrast small text — it's a safety disclaimer; give it `textSecondary`.
- 🔍 No Stop button while streaming; no "New chat" (`clearResponse` exists but is unused) (`GrokAIView.swift:609`).
- 🔍 Raw `error.localizedDescription` shown to users (`GrokAIViewModel.swift:154`).
- 🔍 Retry always re-asks the last *question*, even if the image check failed (`GrokAIView.swift:148-159`).
- 🔍 No VoiceOver announcement for "Thinking…" / reply ready.
- 🔍 Three ad-hoc card styles (`responseCard`, `GrokResponseCard`, error plate) + 23 raw colors in GrokAI views.

### Settings (`08`)
- 📷 Cleanest screen in the app. Minor: "Restore Purchases" is a small text link (< 44pt) with no completion feedback; "For spotters." jargon.
- 📷 Pro copy: "Yearly adds 12-hr Future radar" vs Radar's "12-hr · Pro" — naming mismatch.
- 🔍 "Off until POSTHOG_API_KEY is set" can surface to users (`SettingsView.swift:340`).
- 🔍 "Clear weather cache" styled destructive but no confirm/feedback (`SettingsView.swift:416-418`).
- 🔍 Toggle subtitles hidden from VoiceOver (`SettingsView.swift:648`).

### Paywall (UI/copy only — entitlement logic untouched)
- 🔍 Headline "Never miss a severe alert" over-promises and implies alerts are Pro, while body says they're free (`PaywallView.swift:341`).
- 🔍 "Generous daily limit" is vague (`:112`). Selected plan lacks `.isSelected`; accent rim off-contract (`:189-223`). Prices in `accentWarm` (reserved for warm temps).
- 🔍 "12-hr forecast radar" vs "Future radar" on the same screen.

---

## Design-system debt (counts from code review)

| Category | Today | Forecast/Alerts | Radar | More/Sky Check/Settings | Total |
|---|---|---|---|---|---|
| Raw colors / ad-hoc opacity | 21 | 14 | 10 | 23 | **~68** |
| Off-scale spacing (6/10/14…) | 5 | 8 | 12 | 9 | **~34** |
| Ad-hoc radii | ~4 | 5 | 9 | 10 | **~28** |
| Font helpers bypassed | 4 | 0 | 10 | 3 | **17** |
| Extra card styles (4th card) | 0 | 1 | 0 | 3 | **4** |
| Inverted/accent pills vs type-weight rule | 1 | 1 | 4 | 4 rims | **~10** |
| ALL CAPS labels | 1 | 3 | 3 | 0 | **7** |

Worst offenders: `AlertDetailView.swift`, `GrokAIView.swift` + `GrokErrorView.swift`, `RadarControlPanel.swift`, `TripPlannerView.swift`.

**Suggested structural fix:** add one shared `StatusBanner` (error/stale/outage), one `SegmentedTypeWeightPicker` (Live/12-hr, 1x/2x/3x, metric chips, plan picker), and route all of them through tokens. That collapses ~20 of the findings above.

## Spec drift to resolve in `DesignSystem.md`
- `todayTempSize` 88 (code) vs 72 (doc); Now glyph 56 vs 36.
- "Live/24-hr" (doc) vs "12-hr" (code).
- Doc version stamp is 2026-08-24 — two months of UI changes since.

---

## AI surfaces & TypeSafe (per your TypeSafe preference)
The UX gaps around AI are mostly *state* problems, not model problems:
1. **Verify-then-reveal** (Top #5): the verifier currently runs after streaming. Either buffer until the TypeSafe verdict, or stream into a visually "pending" state and promote it on pass. Don't show-then-retract.
2. **Tell the user why** a reply was withheld ("I couldn't confirm that against current conditions") instead of a generic failure — the verifier's typed verdict already tells you which case it is.
3. **Retry should replay the failed action** (question vs image check), keyed off the same verdict/error type.
No new TypeSafe calls are needed for any of these; they're presentation changes on top of what shipped in `62c44af`.

---

## Not covered / limits
- iPad (regular size class, 7-tab sidebar) not run.
- Live alert, paywall, Locations list, and Sky Check reply states not exercised in the simulator (no active alerts; free tier; no saved cities) — those findings are code-only.
- VoiceOver checked by code inspection, not with the VoiceOver rotor.
- Simulated Denver location was ignored in favour of cached Olive Branch — worth a quick check that "Near Me" refreshes on a real location change.
