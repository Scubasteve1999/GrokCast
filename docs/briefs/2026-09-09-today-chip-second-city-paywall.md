# Cursor brief — Today chip: second-city paywall

You are an iOS developer architect, master in design and app features/functions, specifically for Stephen's DayCast weather app.

**North star:** DayCast is the weather app you'd open in a real storm and trust. Honest local now/alerts, readable Site Doppler + National radar, fast/obvious on a normal iPhone. Don't chase AccuWeather's kitchen sink. **trust-in-a-storm**.

**do not use i-have-adhd**

**Repo:** Scubasteve1999/GrokCast — branch from current `main`, open a PR.

## Why

Live App Store **1.0.10 (162)** already gates free users at **Near Me (GPS) + 1 named city**. Locations tab shows `Free includes Near Me + 1 saved city`, CTA **Save unlimited places** → `PaywallCoordinator.present(.locations)`.

Today's `LocationChipBar` only **switches** already-saved cities. Toolbar location button recenters GPS. Adding a second named city forces More → Locations — late in the path for the highest-intent conversion moment (wanting weather for another city *while looking at Today*).

## Goal

Surface the **same** locations paywall earlier: from Today’s location chip / search when a free user tries a second named city. No new IAP, no plan redesign, no App Review submit in this PR.

## Product rules (locked)

1. Free allotment unchanged: Near Me (`isCurrent`) does **not** count; named limit = `EntitlementChecker.freeSavedLocationLimit` (1).
2. Selection logic must reuse `CitySearch.selectionDecision` / `EntitlementChecker.canAddLocation` — do **not** invent a second gate.
3. On `.paywall`: `PaywallCoordinator.shared.present(.locations)` — same feature as Locations tab.
4. Copy reuse (do not invent marketing lines):
   - `LocationsCopy.freeLimitChip` — `Free includes Near Me + 1 saved city`
   - `LocationsCopy.saveUnlimitedCTA` — `Save unlimited places`
   - Paywall benefit already: `Unlimited saved locations`
5. Monthly / Yearly product IDs and inclusion copy stay as shipped (`DayCastProProducts` / `PaywallPeriodCopy`).
6. Pro users: search/add works as today (unlimited named).

## UX

**Screen:** Today — `LocationChipBar` strip above the feed.

**Entry:** Trailing control on the chip bar (`+` preferred; accessibility “Add city”). Opens city search (sheet or inline — prefer a compact sheet so the feed isn’t rebuilt). Reuse Locations search patterns (`CitySearch`, MapKit) — don’t fork a second search stack if a shared helper already exists.

**Flow:**
1. Tap `+` → search cities.
2. Pick result → run existing selection decision on a candidate `SavedLocation`.
3. `.selectExisting` / `.add` / `.replace` → same persistence as Locations (no Today-only save path).
4. `.paywall` → present locations paywall; do **not** silently fail or bounce to Locations tab without the sheet.
5. Optional: when free allotment is already full, a quiet chip/caption using `freeLimitChip` is OK if density allows; not required if the paywall alone is clear.

**Density:** Chip bar must stay one-thumb. No second tall banner. Don’t steal Your News peek with a permanent promo row.

## Analytics

- Existing: `paywallView` with `feature=locations` (keep).
- Add source discrimination, e.g. parameter `source=today_chip` (vs Locations-tab present which may omit or use `source=locations`). Match existing Analytics conventions — don’t invent a parallel event name if a parameter fits.
- Track the `+` / Add city open (light tap event) so we can measure attempt → paywall rate.

**Success metric (for Stephen / Apps after ship):** 7-day lift in locations paywall views with `source=today_chip`, and locations-sourced Pro starts vs Locations-tab-only baseline.

## Out of scope

TestFlight / App Store bump; App Review submit; honesty strip changes; Yearly-only Future/widgets teases; Flock / DataCentral; changing free limit; new subscription products; fearbait copy.

## Done means

PR against `main`. Report: entry control, search presentation, gate reuse proof (call sites), analytics `source`, density note, tests for free second-city → paywall from the Today path. CI `build-and-validate` is the compile gate. No version bump unless Stephen asks in a later slice.
