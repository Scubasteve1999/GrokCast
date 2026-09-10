# Cursor brief — Honesty WFO title case

You are an iOS developer architect, master in design and app features/functions, specifically for Stephen's DayCast weather app.

**North star:** DayCast is the weather app you'd open in a real storm and trust. Honest local now/alerts, readable Site Doppler + National radar, fast/obvious on a normal iPhone. Don't chase AccuWeather's kitchen sink. **trust-in-a-storm**.

**do not use i-have-adhd**

## Bug

Heat Advisory chip subtitle showed `nws memphis · Until Thu 4:15 AM`. Stephen wants title case: **`NWS Memphis`** (not forced lowercase).

`HonestyStripCopy.wfoLabel` intentionally ended with `.lowercased()` (MVP1 product shape `nws memphis`). For advisories (not watch/warning), `AlertsFeedCard.chipUntil` prefixes `honesty.wfoLabel` onto the until line. Same label feeds the calm honesty strip and severe primary lines.

## Cause

One helper, one forced lowercase:

```swift
return trimmed.lowercased()
```

`LocalBriefingParser.sourceName` already returns `NWS Memphis` / `NWS Tampa Bay Area` / `NWS MEG`. The strip then smashed that to `nws memphis`.

## Fix

1. Change `wfoLabel` so the visible office string is title case. Keep using `LocalBriefingParser.sourceName` — do **not** invent a second WFO pipeline.
2. Format in that helper: keep `nws ` → `NWS ` prefix; title-case the city/office remainder. Short CWA tokens stay uppercase (`NWS MEG`, not `NWS Meg`).
3. `spokenOffice` / VoiceOver: title-case `NWS Memphis` still speaks as “National Weather Service Memphis…”.
4. Headline product lines for watch/warning stay lowercase product style (`severe thunderstorm watch until 9pm`). Only the WFO portion is title case (`NWS Memphis · severe…`).
5. Update tests that asserted `nws memphis` / lowercase WFO (`HonestyStripCopyTests`, Alerts chip contracts).

## Out of scope

TestFlight / App Store; changing until-line capitalization (`Until Thu…` comes from `AlertsActiveCopy`); Memphis geo-lock; Flock/DataCentral; paywall / ensemble.

## Locked examples

| Input | Visible |
|-------|---------|
| office `Memphis, TN` / CWA `MEG` | `NWS Memphis` |
| office `NWS Memphis, TN` | `NWS Memphis` |
| office `nws memphis, tn` / `MEMPHIS, TN` | `NWS Memphis` |
| office `Tampa Bay Area, FL` | `NWS Tampa Bay Area` |
| missing name / CWA `MEG` | `NWS MEG` |
| calm strip | `NWS Memphis` |
| advisory chip until | `NWS Memphis · Until Thu 4:15 AM` |
| watch/warning primary | `NWS Memphis · severe thunderstorm watch until 9pm` |

## Done means

PR against `main`. Report before/after example strings, files touched, tests updated. CI `build-and-validate` is the compile gate. No TF bump.
