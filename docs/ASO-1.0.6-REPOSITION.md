# Step 4 — App Store reposition (approved copy)

The bet from [`THINKING-PASS-2026-08.md`](THINKING-PASS-2026-08.md): stop competing for generic
weather traffic the app cannot win, and be findable by the niche it is already built for.

Approved 2026-08-01. Copy below is final — paste as written.

## Rollout

| Field | When | Why |
|---|---|---|
| Promotional Text | **Now** | Editable without a version submission or review |
| Subtitle, Keywords, Description | **1.0.6**, after 1.0.5 clears review | All three require a version submission; submitting now would withdraw 1.0.5 and lose its place in the queue |

---

## 1. Subtitle — 25/30

```
Storm Spotter Radar & SPC
```

## 2. Keywords — 96/100

```
spotter,chaser,chasing,nexrad,velocity,srv,supercell,mesocyclone,hail,severe,tornado,outlook,nws
```

No spaces after commas — each one costs a character.

> **Known overlap, accepted.** This set was written against the alternate subtitle
> (`Chase Radar, SPC & AI Reads`). With `Storm Spotter Radar & SPC`, Apple already indexes
> *spotter*, so the leading `spotter,` is redundant and worth ~8 characters. Left as-is by
> decision. `mesoanalysis` or `reflectivity` are the first candidates if those characters are ever
> reclaimed. The upside of the chosen subtitle is that `chaser`/`chasing` are no longer covered by
> an indexed *chase*, so they now pull their full weight.

## 3. Promotional Text — 135/170

```
NEXRAD velocity, correlation coefficient, SPC outlooks and mesoscale discussions, NWS warnings, and a plain-language read of the frame.
```

Not indexed for search — this converts someone already on the page. Safe to iterate on freely.

## 4. Description

```
SpotterCast is a field weather app for storm spotters, chasers, and people who
watch the sky themselves.

RADAR
• Single-site NEXRAD products: super-resolution reflectivity, base and storm-
  relative velocity, correlation coefficient, differential reflectivity,
  composite reflectivity
• Live regional mosaic with animation and frame scrubbing
• Forecast radar frames (Pro)

SEVERE WEATHER
• SPC Day 1 outlook probabilities for tornado, hail, and wind
• Mesoscale discussions
• Nearby storm reports
• National Weather Service watches, warnings, and advisories, with
  time-sensitive notifications

SHORT TERM
• Next-hour precipitation at 15-minute resolution
• HRRR short-term precipitation for the continental US, shown next to the
  standard model so you can see when the two disagree
• Hourly and 10-day forecasts

AI READS (SpotterCast Pro)
• Explain Radar — a plain-language read of the frame you are looking at
• Photo analysis — send a photo of the sky and get a read on the structure
• Morning brief — a short written summary of the day's setup
• Chat with current conditions attached

ALSO
• Home Screen and Lock Screen widgets, Live Activity
• Wildfire layer (NASA FIRMS) with air quality
• Saved locations, Siri shortcuts

WHAT'S FREE
Radar, NWS alerts, SPC products, forecasts, and next-hour precipitation are
free. SpotterCast Pro adds the AI features, forecast radar, Live Activity, and
unlimited saved locations. AI has a daily limit.

DATA SOURCES
Open-Meteo, the National Weather Service, the Storm Prediction Center, NEXRAD
Level III via Iowa Environmental Mesonet, RainViewer, and NASA FIRMS.

SpotterCast is not affiliated with NOAA, the National Weather Service, or any
government agency. It is an interpretation aid, not a warning source. Always
follow official warnings and the guidance of local emergency officials.
```

Every line maps to shipped code. The closing disclaimer is load-bearing: the app sells AI that
interprets severe weather, and saying plainly that it is not a warning source is both honest and
what keeps a reviewer from reading it as an emergency-services claim.

---

## Positioning shift

**Before.** An AI weather app with a good radar tab, indexed on `weather, forecast, radar, AI,
alerts, tornado, hurricane, widgets, complications, live radar, NWS, storm`. The top results for
every one of those are Apple Weather, CARROT (86k ratings), and AccuWeather. At 2 ratings the app
ranks on none of them, and traffic that does arrive wants a consumer weather app and bounces.

**After.** A field tool indexed on terms only the intended audience types. `srv`, `mesocyclone`,
`correlation coefficient` are low volume with near-zero competition — but someone searching them
knows exactly what they want, and few apps have it. RadarScope and RadarOmega render these
products; neither explains them.

The trade is real: the theoretical mass market is given up for a few hundred thousand trained
spotters plus the chaser community. That is the market the code was already built for.

## Keywords deliberately avoided

| Term | Why |
|---|---|
| `skywarn` | Registered NWS program name — third-party trademarks in the keyword field are grounds for rejection. Highest-volume fit in the niche, and still not worth it |
| `weather`, `forecast` | Unwinnable; the highest-competition terms on the store |
| `radar`, `spc`, `storm` | Already in the subtitle, which Apple indexes — repeating wastes characters |
| `hurricane` | No tropical-specific features; sets the wrong expectation |
| `widgets`, `complications` | Low intent, and *complications* implies a Watch app not in this build |
| `emergency`, `warning system`, `official`, `alert system` | Emergency-service framing invites both rejection and liability |
| `radarscope`, `radaromega`, `carrot` | Competitor names — straight rejection |
| `free` | Prohibited in the keyword field |

## Measuring it

Step 3 (commit `5917277`) shipped the instrumentation this depends on:

- **App Store Connect → Analytics → Acquisition** — impressions and conversion by source, before
  and after. This is the number that says whether the reposition worked.
- **Campaign tokens** (`ct=share_today` and friends) attribute installs to shared content.
  Requires `providerToken` in `ShareAttribution.swift` to be set — links work without it, reports
  do not.
- **`first_open`** dates the cohort so before and after are separable.

**Capture a 30-day acquisition baseline before submitting 1.0.6.** Without it the reposition is
unfalsifiable.

## Not proposed

- Renaming the app. `SpotterCast` has 19 unused characters and carries the most ASO weight, but
  also the most brand risk, and the existing 5-star ratings are attached to it. Revisit only if the
  reposition works.
- Keyword-stuffing the name field.
- Any claim of spotter-network integration or report submission — the app has neither. That is the
  real product gap versus RadarScope, and it is a product decision, not a metadata one.
