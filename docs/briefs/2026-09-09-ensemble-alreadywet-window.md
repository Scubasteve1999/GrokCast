# Cursor brief — Ensemble `alreadyWet` must not look ahead

You are an iOS developer architect, master in design and app features/functions, specifically for Stephen's DayCast weather app.

**North star:** DayCast is the weather app you'd open in a real storm and trust. Honest local now/alerts, readable Site Doppler + National radar, fast/obvious on a normal iPhone. Don't chase AccuWeather's kitchen sink. **trust-in-a-storm**.

**do not use i-have-adhd**

## Bug

In `EnsembleAgreement.evaluate`, `alreadyWet` was:

```swift
let alreadyWet = starts.contains {
  $0 <= now.addingTimeInterval(Double(Thresholds.lookbackMinutes) * 60)
}
```

That treats first-wet up to **now + 30 minutes** as already raining. Late in the hour (e.g. 3:45 with first wet at 4:00) can wrongly pick linger/through copy instead of “may start …”.

`lookbackMinutes` correctly widens the **search window** for first-wet (`windowStart = now - 30m`, plus the in-progress hourly slot). It must **not** widen the already-wet predicate into the future.

Fixed on `main` as of MVP2 #48 (`e98a3e9` / `5a917be`). This brief locks the contract so it does not regress.

## Fix

1. Set `alreadyWet` only when a member’s first-wet time is at or before `now`:

```swift
let alreadyWet = starts.contains { $0 <= now }
```

Prefer `<= now`. Do **not** add lookback into the future.

2. Keep lookback on `windowStart` / `firstWetIndex` unchanged (`scoringWindowStart`).

3. Unit tests in `EnsembleAgreementTests`:
   - `now` = 15:45, members first-wet at 16:00 only → `alreadyWet == false`, sentence uses start/around (not linger/through). (`testUpcomingHourIsNotAlreadyWetAfterHalfPast`)
   - `now` = 15:45, a member first-wet at 15:00 (within past lookback / current slot and `<= now`) → `alreadyWet == true`, linger/through path still works. (`testCurrentHourStaysAlreadyWetAfterHalfPast`)
   - `testAlreadyWetSplitSaysMayMissOrLinger` / `testAlreadyWetUsesThroughNotStart` must still pass.

4. No copy string redesign, no API/threshold/placement changes, no TF bump, no Settings/attribution edits.

## Out of scope

TestFlight / App Store bump; paid Open-Meteo; AFD priority; soft/strong thresholds; Memphis geo-lock.

## Done means

PR against `main`. Report the one-line predicate change, tests added/updated, and that CI `build-and-validate` is the compile gate.
