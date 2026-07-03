# GrokCast Unified Roadmap

**North star:** *The weather app that explains what the sky means — and shows you what it looks like.*

This document merges **App Store readiness**, **go-big product strategy**, and **Design System v2** into one phased plan. Each phase delivers user-visible value and moves toward a stunning, review-ready, differentiated app.

---

## Design north star

| Layer | Role |
|-------|------|
| **Atmosphere** | Condition-aware sky, particles, glow — users feel the weather |
| **Data** | Scannable hierarchy — temp dominant, details in cards |
| **Intelligence** | Grok as briefing voice, not a bolted-on chatbot |

**Brand lane:** Apple Weather atmosphere + Carrot personality + pro radar + Grok intelligence.

---

## Phase 0 — Foundation ✅ (complete)

App Store blockers and baseline polish.

- [x] In-app Privacy Policy + Support links
- [x] Clear weather cache (functional)
- [x] Grok empty state when no API key
- [x] °F / °C units toggle
- [x] Onboarding: location + data/Grok disclosure
- [x] Updated `privacy.html` + `support.html`

**Still before submit:** App Review Notes, TestFlight device QA, `./grok-build increment-build` + archive, **Submit for Review** (deferred).

- [x] GitHub Pages workflow (`/.github/workflows/pages.yml` → `/docs`)

---

## Phase 1 — Identity sprint ✅

### Design
- [x] Unified `WeatherBackgroundView` on Today (`.full` intensity)
- [x] Design System v2: glass surfaces, section headers, motion tokens
- [x] Today hero: larger temp, condition glow, glass card
- [x] `GrokBriefCard` on Today
- [x] Custom Settings + `MoreHubSheet`

### Product
- [x] Grok Brief v0 on Today with share

---

## Phase 2 — Consumer Grok + daily habit (in progress)

### Product
- [ ] Hosted xAI proxy OR subscription (no user API keys)
- [x] Grok Morning Brief — local notification + Settings toggle (7–11 AM)
- [x] Shareable Grok Brief text (Today card + Alerts summary)
- [ ] Push: rain starting soon (Phase 3)

### Design
- [x] Grok tab → Briefing studio (2×2 action grid + full-width tiles)
- [x] Storm Spotter analysis dossier layout
- [x] Alerts tab: Grok “In plain English” summary card

### Exit criteria (partial)
- [x] Daily brief habit infrastructure (cache + notification + share)
- [ ] Grok works without BYOK for mass market

---

## Phase 3 — Utility moat ✅ (core shipped)

*Table stakes vs AccuWeather / Apple Weather.*

### Product
- [x] Minutecast / next-hour precip (15-min Open-Meteo + Today strip)
- [x] Live Activities: score + temp + Minutecast (Lock Screen / Dynamic Island)
- [x] “Explain this radar” — sparkles button + Grok sheet + share
- [x] GrokCast Score / “Go outside” index on Today + medium widget
- [x] Siri Shortcuts + App Intents (GrokCast Score, Minutecast)

### Design
- [x] Minutecast strip on Today (precip intensity bars)
- [x] Forecast daily temp range bar
- [x] Hourly precip gradient bars
- [x] Radar scrub selection haptics

### Remaining Phase 3 polish
- [ ] Push: rain starting soon (local notification from Minutecast)
- [ ] Live Activity variants for severe alert / radar event
- [ ] “Ask Grok” App Intent (opens chat with context)
- [ ] Radar glass HUD + glowing playhead

### Exit criteria
- Users can plan the next hour without opening another app
- Lock Screen / Dynamic Island presence during weather events

---

## Phase 4 — Ecosystem + growth ✅ (core shipped)

### Product
- [x] Apple Watch app + WidgetKit complications (temp, score, Grok one-liner)
- [x] Widget: Grok one-liner on medium widget
- [x] Storm Spotter community share loop (#GrokCastStormSpotter + Share Report)
- [ ] Tab IA simplification (Home / Map / You) — optional, deferred

### Design
- [x] Display typography for hero temp (`Typography.heroTemperature` condensed)
- [x] Launch screen brand color (`LaunchBackground`)
- [x] App Store screenshot preview compositions (Today / Radar / Grok)
- [x] Optional alert / brief sounds toggle (Settings)

### Exit criteria
- Daily touchpoints: phone, wrist, Lock Screen ✅
- ASO screenshot templates in Xcode Previews ✅

### Remaining before App Store
- [ ] Capture screenshots (`./grok-build capture-aso` or Xcode Previews)
- [ ] Final app icon polish (assets exist; optional refresh)
- [ ] TestFlight QA on 2+ devices (Phase 0)
- [ ] Submit for App Store review (when ready — not required tonight)

---

## Design System v2 tokens (reference)

See `DesignSystem.md` § Design System v2.

| Token | Usage |
|-------|--------|
| `surfaceGlass` | Brief cards, HUD, Settings rows |
| `surfaceSolid` | Dense data grids |
| `surfaceElevated` | Hero-adjacent cards |
| `bgGlow` | Condition-tinted radial behind hero temp |
| `motionHero` | 0.8s background crossfade |
| `motionCard` | spring 0.35 / 0.75 |

---

## App Store submission checklist

1. Publish `docs/privacy.html` + `docs/support.html` to GitHub Pages
2. Fill App Store Connect metadata + screenshot set (Today, Radar, Grok)
3. Write App Review Notes (location, background, xAI key or embedded reviewer key)
4. Run `docs/TestFlight-Radar-Widget-Validation-Checklist.md` on 2+ devices
5. `./grok-build increment-build --tag` → Archive → Upload

---

## Screenshot compositions (marketing)

1. **Today** — massive temp + sky + Grok Brief line
2. **Radar** — FUTURE frame + timeline + glass HUD
3. **Grok** — Brief card or Imagine / Spotter result

---

**Owner:** Stephen Moore  
**Last updated:** July 2026
