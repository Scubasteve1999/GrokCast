---
name: daycast
description: Current-truth checklist for DayCast (native SwiftUI weather). Use when developing or extending the app — architecture, IA, naming, and product rules that still match code. Not a changelog.
---

# DayCast

Native SwiftUI iOS weather app (iOS 18+). Open-Meteo primary + NWS hybrid (US alerts/obs) + xAI Grok. App Store / scheme: **DayCast**.

## Persona & bar

You are an iOS developer architect for Stephen’s DayCast.

**North star:** The weather app you’d open in a real storm and trust. Honest local now/alerts, readable Site Doppler + National radar, fast on a normal iPhone. Steal AccuWeather / Apple Weather *presentation* (photography, hierarchy, quiet chrome). Reject kitchen-sink *features*. Never ship Minecraft / cartoon / kids-sticker weather UI.

**Visual bar:**
- Dark premium. Photography-first on editorial surfaces (news, briefing, story cards).
- Title-case section labels (`Your News`, `Active Now`, `Day 1 Outlook`). Do not default new sections to `FigmaAccentSectionLabel` + colored SF Symbol chrome (that type is gone — don’t bring it back).
- Do **not** mutate `AlertsHonesty` constants (`activeNow` stays `"ACTIVE NOW"`). Title-case at the call site.
- Outlook accent lives on the category word (**Thunderstorm**), not an ALL CAPS stripe.
- Cards: large rounded cinematic images, bold headlines, quiet meta. No thick borders, left accent bars, or emoji tile heroes.

## Hard rules

- xAI key lives only in Keychain (`KeychainService`). `GrokAPIConfiguration.swift` stays secrets-free (base URL, model, timeouts).
- Forecast `Identifiable` Codable models: `var id: Date { time }` (or `date`). Never `UUID()`.
- App Group is `group.com.scubasteve1999.DayCast` — **not** `group.com.daycast.DayCast`.
- Open-Meteo is source of truth for primary forecast numbers. NWS alerts/obs are US-only and fail silent.
- Widgets (and Locations saved-row weather) read App Group snapshots only — never weather/AI fetches from the widget extension.
- Home Screen / Lock Screen widgets render only when `daycast_is_yearly`.
- Public chrome: **Sky Check** (not Storm Spotter / Briefing Studio). Radar: **Site Doppler** / **National radar** (never MRMS / Mosaic in chrome).
- Intentional legacy wire names: `grokCastScore`, `grokCastScoreLabel`, `grokBriefOneLiner`.
- Do not change entitlement / paywall / StoreKit Pro logic without explicit approval.

## Current product map

**IA (compact):** Today · Forecast · Radar · Alerts · More. Sky Check, Locations, and Settings live under More (`WeatherStore.Tab.moreHub`). iPad sidebar lists them. Stay under More — no fifth root tab.

**Today:** Storm-first feed (`FeedItem.defaultOrder`): Now → one official NWS chip (if live) → Hourly curve → Outlook radar plate → Your News → health → Daily → Nearby. `WeatherStage` photography under type. Weather modules use `weatherModuleStyle()` (material on the stage); Settings / Paywall stay solid `cardStyle`. Error banner above Now. Take / Imagine / Next-hour strip are not feed cards (Imagine is off Today and Sky Check). Future pill on the Outlook plate is Yearly-only.

**First run:** Storm-trust welcome, not AI marketing. Denied stays on `LocationPermissionView`. GPS-fail may load Olive Branch but **never** sets `isCurrent` — show `WeatherStore.gpsFallbackHonestyMessage`.

**Forecast:** `HourlyGraphView` (48h scrub + series picker) + `WeekDayChipStrip`. Not a chip-grid hourly. Not a `DailyRow` 10-day table (`DailyRow` is helpers only).

**Alerts:** Official-first — NWS Active Now rows, then Grok summarize (locked free users: Unlock with Pro when `canUnlockGrokViaPro`; no BYOK CTA). Outlook ≠ warning (`AlertsHonesty`; do not mutate constants). Your News rail home is Today (same `LocalBriefingStore`). LSR off by default.

**Radar:** Mapbox Dark canvas. Live default is nearest-site N0B (**Site Doppler**); dry/failed/stale auto-presents **National radar**. National tiles + MapsGL rain fallback; Site is Level III polar. Chrome never says MRMS/Mosaic. 24-hr / Future chrome stays Yearly-gated.

**Sky Check:** Chat desk under More. Empty copy is weather-questions first, photo second (`SkyCheckDeskCopy.emptyPitch`). One writer per stream (`appendSkyCheckStreamToken`: photo → `stormAnalysisText`, chat → `responseText`). Screen finished replies with `GrokContentFilter.acceptedSkyCheckText` (12k). Take / Explain Radar / Alerts / trip travel tips use the 1,600 cap. Compact composer pads `CompactTabBar.chromeHeight` (69). Internal type names may still say StormSpotter. Today’s Take card is off Today (`GrokBriefCopy` remains for Settings / paywall). Do not advertise adding a key on paywall / Sky Check empty / Alerts locked copy — Settings BYOK stays.

**Widgets / paywall:** `isPro` = any paid product (AI, extra locations). Yearly extras: Future radar, widgets, Live Activity (`canUseRadarFuture`, `canUseLiveActivity`, `canUseWidgetGrokBrief`). Official weather / radar / NWS stay free. Developer key is full in-app access.

## Agent workflow

- Work from `~/Projects/GrokCast`. Never treat Documents or Desktop as canonical.
- Commands, archive, Xcode Cloud, and hard rules: `AGENTS.md`. Design tokens: `DesignSystem.md`.
- Prefer `./grok-build` for repetitive tasks (`regenerate`, `clean`, `increment-build`, `generate-icons`).
- Plan briefly, then implement. Build + test after non-trivial changes (`xcodebuild` … `iPhone 17 Pro Max`).
- **Update this skill only when a durable product rule changes.** One-off delivery notes go in `.memory/` or the PR body — not here.

## Do not recreate

- MapKit + RainViewer as the Radar face (RainViewer may still exist as a tile fallback).
- POLLEN / NWS-obs tactical grid as the Today face.
- `DailyRow` 10-day table or `HourlyRow` chip grid as the Forecast face.
- `GrokBriefCard` / Today’s Take / Imagine on the Today feed.
- Grok / Sky Check as a compact root tab.
- `FigmaAccentSectionLabel` as default section chrome.
- Storm Spotter / Briefing Studio / Ask Grok in user chrome.
- MRMS / Mosaic / “Minutecast” as user-facing names.
- `group.com.daycast.DayCast`.
- Watch / `DayCastWatch` scaffold.
- Step-5 “update this skill after every feature.”
