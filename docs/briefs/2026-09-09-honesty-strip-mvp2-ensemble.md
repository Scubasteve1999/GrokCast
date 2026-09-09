# Cursor brief — Honesty strip MVP2: Open-Meteo ensemble

You are an iOS developer architect for Stephen’s DayCast.

**North star:** The weather app you’d open in a real storm and trust. Honest local now/alerts, readable Site Doppler + National radar, fast on a normal iPhone. Don’t chase AccuWeather’s kitchen sink. **trust-in-a-storm.**

**do not use i-have-adhd**

## Context

MVP1 shipped: calm standalone `nws {office}` after Now; severe folds into the Alerts chip. Files: `HonestyStripCopy`, `HonestyStrip`, `AlertsFeedCard` honesty, `LocalBriefingStore.officeOfRecord`, `TodayFeedView`, `FeedAssembler`, `TodayGlanceLayout`.

MVP2 adds Open-Meteo ensemble **Agree / Soft disagree / Strong disagree** plus one plain range sentence.

Example:

> nws memphis · severe thunderstorm watch until 9pm
> models disagree — storm may start 4–7pm, not “at 5:12”

## Goals

1. Three-state chip: Agree / Soft disagree / Strong disagree (hide when noise if cleaner).
2. One plain sentence — ranges not fake clocks. Agree: omit or quiet confirmer.
3. Placement: second line on the honesty strip **or** folded into the severe Alerts chip. No new tall card. Preserve Your News peek on iPhone 16.
4. Nationwide; soft-fail if ensemble unavailable (MVP1 strip alone).
5. Reuse existing Open-Meteo patterns (`OpenMeteoService`, Ensemble API). Do not invent a primary provider. `MinutecastAgreement` is UX precedent only.
6. Attribution: Settings Open-Meteo credit stays. Commercial paid plan = residual, not this PR.
7. Tone: blunt; not WEA; no MinuteCast precision.

## Out of scope

TF / App Store bump; Memphis geo-lock; Alerts rewrite; HWO; WeatherKit swap; paid OM endpoint; fearbait.

## Locked decisions (implementation)

| Item | Decision |
|------|----------|
| Source | Free `ensemble-api.open-meteo.com` · `icon_seamless` hourly precip + weather code |
| Wet | ≥ 0.01 in/hour |
| Window | Next 12 hours (30 min lookback) |
| Hide | `< 4` members, or wet fraction `< 0.20` and primary hourly also dry |
| Agree | Most members wet and first-wet spread ≤ 60 min — **omit sentence** |
| Soft | Spread 61–179 min, or primary wet / ensemble mostly dry |
| Strong | Spread ≥ 180 min (`4–7pm`), or wet/dry split 20–80% |
| Placement | Calm: second caption on the 36pt strip. Severe: chip line 2, ensemble over AFD |
| Density | Calm+ensemble peek still `> ` story-day peek; no extra card |
| Fail | Transport / decode / stale (>45 min) → MVP1 strip |
| Attribution | Existing Settings “Weather data · Open-Meteo” |
| Residual | Customer paid Open-Meteo host |
