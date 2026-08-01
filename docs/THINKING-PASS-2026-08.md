# Thinking pass — SpotterCast, August 2026

Run 2026-08-01 against `~/Projects/_meta/THINKING-PASS.md`. Same structure as
`DataCentral/docs/THINKING-PASS-2026-08.md`. **No decision taken yet.**

## Stage

**Live on the App Store as SpotterCast** (repo: `GrokCast`, bundle `com.scubasteve1999.GrokCast`,
App Store ID 6780682022). First release **2026-07-24**; current live version **1.0.4**, updated
**2026-07-31**. Free, Weather / Utilities, iOS 18+.

**Real users: 2 ratings, 5.0 average.** Eight days on sale.

`main` is clean at **1.0.5 / build 77** — archive prepared, **not submitted**. Same pattern as
DataCentral: a finished build sitting on disk.

## 1. What this is today

A dark, spotter-leaning severe-weather app. Open-Meteo is the forecast source of truth, with a
strictly-additive NWS/SPC/HRRR layer for US alerts, outlooks and short-term precip; a Mapbox radar
tab that serves real single-site NEXRAD products (super-res reflectivity, storm-relative velocity,
correlation coefficient, differential reflectivity) plus RainViewer live and Xweather/OWM forecast
frames; and Grok as the interpretive voice across briefs, radar explanations and storm-photo vision.
Monetization is a StoreKit 2 subscription, **SpotterCast Pro** (monthly/yearly).

| Does | Does not |
|---|---|
| Serve pro-grade radar products (N0B/N0S/N0C/N0X, composite) behind an Advanced chip | Let a spotter **file** anything — no Spotter Network, no mPING, no report submission |
| Read a storm photo and give a field-oriented analysis (Grok vision) | Position itself as a spotter app in the App Store listing's keywords |
| Layer SPC outlook probabilities, NWS alerts, HRRR vs Open-Meteo minutecast disagreement | Show other spotters' positions, reports, or any live ground truth |
| Push severe alerts, morning briefs, Live Activity, widgets, Watch code on disk | Have any acquisition loop that has been measured working |
| Wildfire layer (NASA FIRMS) and a data-driven Today feed | Gate AI behind Pro — AI runs on an **embedded key you pay for** |
| Sell Pro: forecast radar, Live Activity, widgets, unlimited locations | Route a single call through the Pro proxy — it is written but undeployed |

## 2. Already shipped — do not rebuild

Today hero + data-driven feed (Now/Hourly/Daily/Precip/Alerts/AirQuality/SunMoon/Radar/Fire/AI
cards), SpotterCast Score, Minutecast (Open-Meteo 15-min + CONUS HRRR with disagreement surfacing),
Forecast with UV/precip amounts/day-detail sheet, Mapbox radar (live RainViewer → OWM fallback,
Xweather forecast frames, NEXRAD single-site products, chase HUD, scrubber, playback, Explain
Radar), NWS alerts + SPC severe products, alert history + background refresh + rich time-sensitive
notifications, Grok chat / Today's Take / Morning Brief / Imagine / Storm Spotter photo analysis,
share cards, home + Lock Screen widgets, Live Activity, Siri Shortcuts / App Intents, Trip Planner,
wildfire layer (FIRMS + AirNow), onboarding, PostHog analytics, StoreKit 2 Pro with honest paywall
copy, Watch target on disk (deferred from submission).

Open items in `docs/ROADMAP.md` are mostly polish (rain-start push, Live Activity variants, Ask-Grok
intent, radar HUD glow, tab IA). None of them is the constraint.

## 3. The ceiling question

| Ceiling | Verdict |
|---|---|
| Legal / ethical | **Not binding.** Public data (Open-Meteo, NWS, SPC, IEM/RainViewer, FIRMS), licensed tiles, honest "as of" and provider labeling. |
| Feature depth | **Not binding, and not the point.** The app already out-features most consumer weather apps. |
| **Market impact** | **Binding, hard.** Eight days live, 2 ratings. |
| **Unit economics** | **Binding in a way DataCentral's isn't.** Growth costs you money per user. |

The standing rule applies: near-zero users → the answer is distribution, not features. But
SpotterCast has a second binding ceiling that has to be named, because it makes the usual advice
*dangerous* here:

**The AI is free to the user and billed to you.** `Config/DeveloperAPIKey.swift` carries a real
`xai-…` key, `GrokAPIConfiguration.developerAPIKey` returns it with **no `#if DEBUG` guard**, and
`GrokAuthResolver.resolve` prefers it over everything. So every App Store user's chat message,
morning brief, radar explanation and storm-photo vision call hits **your** xAI account. There is no
client-side rate limit, no per-user cap, and Pro does not gate AI —
`EntitlementChecker.canUseGrokAI` returns true for anyone the moment a developer key exists. The
hosted proxy that would fix this (`server/grok-proxy/worker.js`, with a 200 req/day per-subscription
limit) **is written and undeployed**: `GrokCastProConfig.grokProxyBaseURL = nil`, so
`GrokProxyConfiguration.isConfigured` is false everywhere.

At 2 users this is invisible. At 2,000 it is a bill with no ceiling and no way to shut it off
without an App Store release. **Any successful distribution push makes this worse, not better.**

**Measurement gap** — same as DataCentral, though less severe. PostHog is wired and
`Analytics.Event` covers `app_open`, tabs, `share_started`, `paywall_view`, `subscribe_tap`,
`subscribe_success`, `restore_success`, feed taps, fire layer. There is **no `share_completed`, no
install source, no attribution**, and — notably for the economics above — **no AI-usage event at
all**. You cannot currently answer "how many Grok calls per user per day," which is the number that
decides whether Pro is priced right.

**Identity gap.** The product is named SpotterCast, the system prompts say "field-first weather
intelligence for spotters," the radar ships SRV and correlation coefficient — and the App Store
keywords are `weather, forecast, radar, AI, alerts, tornado, hurricane, widgets, complications,
live radar, NWS, storm`. That is a generic consumer weather listing competing head-on with Apple
Weather, CARROT (86k ratings) and AccuWeather. `docs/App-Store-Connect.md` still drafts the listing
under the old name "GrokCast — AI Weather / Smart Forecasts & Live Radar." The live 1.0.4
description is better — it says "chase-ready radar" and "Storm Spotter AI" — but the keyword field,
the thing App Store search actually ranks on, was never repositioned. The app is built for a niche
and marketed to a mass market it cannot win.

## 4. Market signal

1. **The NWS is short-staffed going into severe season, and it is showing.** ~15% of staff lost to
   2025 cuts and buyouts; still hundreds below pre-cut levels in mid-2026 despite ongoing hiring.
   Reduced weather-balloon launches; an April 2026 tornado event where the local office's afternoon
   forecast carried no tornado probability, with missed balloon launches cited as a possible
   contributor; meteorologists publicly noting more "less-than-perfect" SPC forecasts than normal.
2. **That raises the value of ground truth and of independent interpretation** — exactly the two
   things this app is shaped like. When official guidance is thinner, the person standing under the
   storm matters more.
3. **The audience is large and organized, not hypothetical.** SKYWARN is a standing volunteer corps
   of roughly **350,000–400,000 trained spotters**, with 2026 training schedules published by NWS
   offices nationwide and a meaningful share now running virtual. Spotter Network is the existing
   coordination layer for chasers and spotters.
4. **The incumbent pro tools are paid-up-front and old-school.** RadarScope is $9.99 with
   subscription tiers on top; RadarOmega is $8.99 with Gamma/Beta/Alpha tiers. Both sell radar
   *rendering*. Neither sells interpretation.

The consumer AI-weather story (era: "an LLM writes your forecast summary") is crowded and
undifferentiated. The spotter story is the one where this app's actual code is the moat.

## 5. Competitive gap

| Player | Their strength | Gap vs. us |
|---|---|---|
| **RadarScope** ($9.99, 2.7k ratings, Base Velocity) | Industry standard. Full single-site product suite, **Spotter Network integration** for position + reporting. Trusted. | It renders; it does not explain. No AI read of what a couplet or a photo means. But **it owns the reporting loop we have none of.** |
| **RadarOmega** ($8.99, 900 ratings) | MRMS, model data, METAR/front overlays, deep tiering. | Same: data-rich, interpretation-poor. Lower ratings (3.5) suggests UX is a soft spot. |
| **CARROT Weather** (free, 86k ratings) | Personality, design, enormous installed base. | Consumer entertainment, not field tooling. Not our fight — and we will lose it if we pick it. |
| **Apple Weather / AccuWeather / MyRadar** | Default placement, brand, scale. | Unwinnable on the generic keyword set the listing currently targets. |
| **Grok app itself** | People already ask an LLM about the weather. | No radar, no alerts, no location loop. Our advantage is the *context injection*, not the model. |

**Double down on:** being the only app that both renders pro radar products *and* tells a spotter
what they are looking at — including from a photo of the actual sky. Nobody else has that pairing.

**Avoid becoming:** another AI-flavored consumer weather app. That market is saturated, the
incumbents have 86,000 ratings, and every user acquired there costs you xAI tokens for a feature
they will not pay for.

## 6. The bet

**Reposition to the spotter niche, and make the AI economics survivable before doing anything that
adds users.** Not a feature — a sequencing decision.

The distribution move is not a new capability; it is **making App Store search find the app the
code already is**. Keyword field, subtitle, screenshots and description aimed at
spotter/chaser/SKYWARN/SRV/velocity/NEXRAD/storm-report intent rather than `weather, forecast,
widgets`. That niche has ~350k trained members, published training calendars, an existing community
infrastructure, and two paid incumbents that don't interpret anything. Metadata is a no-review-cycle
change (promo text, keywords, subtitle can move without a binary).

**Sequence:**

| # | Step | Why |
|---|---|---|
| 0 | **Cap or gate the embedded AI key** | The one thing that must ship *before* users arrive. Cheapest form: a client-side daily call cap for non-Pro. Correct form: deploy `server/grok-proxy/worker.js`, set `grokProxyBaseURL`, move AI behind Pro as the paywall copy already promises. |
| 1 | **Instrument AI usage + acquisition** | `grok_request` (with feature + token estimate), `share_completed`, install source. Without the first you cannot price Pro; without the second you cannot tell which repositioning worked. |
| 2 | **Ship 1.0.5** | Built, tested, sitting on disk at build 77. |
| 3 | **Reposition the listing** — keywords, subtitle, screenshots, description | The bet. No binary required for most of it. |
| 4 | **Then** decide the next feature — the honest candidate is closing the reporting loop (Spotter Network / mPING submission), which is the one thing RadarScope has and we don't | Only once there is a real user number and a known cost-per-user. |

**Tradeoff accepted:** repositioning to spotters caps the theoretical audience at hundreds of
thousands rather than tens of millions, and forfeits the generic "AI weather app" search traffic
entirely. That traffic was never converting and each visitor from it costs tokens. This trades a
market we cannot win for one we are already built for.

## 7. What this pass will not propose

- **No feature work before step 0.** Adding capability to an app whose AI bills to a personal key,
  ungated and uncapped, is the one move that can turn success into a loss.
- **No warnings, watches, or hazard calls generated by Grok.** The system prompt already says "do
  not invent warnings" — that line is permanent. The app relays NWS/SPC; it never issues.
- **No life-safety guidance framed as authoritative.** Interpretation and field cues, yes.
  "It is safe to stay here," never.
- **No breaking the NWS-is-additive rule.** Non-US locations and NWS/SPC failures stay silent.
- **No BYOK as the mass-market answer.** Asking a consumer for an xAI key is not a business model;
  it is why the paywall currently has to apologize in small print.
- **No chasing CARROT/Apple on the generic weather keyword set.**
- **No scraping paywalled or vendor-private radar/model sources**; no shipping real keys in tracked
  source (unchanged hard rules).

## 8. Recommendation

**Do not add features. In order: cap the AI key, instrument usage and acquisition, ship 1.0.5, then
reposition the App Store listing to the spotter niche.**

The single most urgent item is step 0 — it is the only one where waiting has an increasing cost, and
it is currently invisible precisely because nobody is using the app. Steps 1–3 are all doable inside
a week; step 3 is mostly a text field.

Deferred deliberately: Spotter Network / mPING reporting (the real product gap vs. RadarScope), the
remaining Phase 3/4 polish, and the Watch target. All three are better decisions once there is a
user count and a cost-per-user to reason from.

## Sources

[SpotterCast on the App Store](https://apps.apple.com/us/app/spottercast/id6780682022) ·
[RadarScope](https://apps.apple.com/US/app/id288419283) ·
[RadarOmega](https://apps.apple.com/us/app/radaromega/id1439881811) ·
[CARROT Weather](https://apps.apple.com/us/app/carrot-weather-alerts-radar/id961390574) ·
[NWS SKYWARN program](https://www.weather.gov/skywarn/) ·
[Spotter Network](https://www.spotternetwork.org/) ·
[CBS — NWS staffing and missing data](https://www.cbsnews.com/news/national-weather-service-hurricane-season-less-experienced-staff-missing-data/) ·
[GV Wire — short-handed for storm season](https://gvwire.com/2026/05/06/storm-season-is-here-and-the-national-weather-service-is-short-handed/) ·
[BBC Science Focus — unprepared for storm season](https://www.sciencefocus.com/planet-earth/us-unprepared-deadly-storm-season) ·
[Star Tribune — cuts and Midwest storm forecasting](https://www.startribune.com/national-weather-service-cuts-could-make-predicting-storms-this-summer-more-difficult/601856101) ·
[2026 SKYWARN training schedules (NWS Hastings)](https://kgfw.com/2026/02/19/nws-hastings-announces-2026-skywarn-storm-spotter-training-schedule/)
