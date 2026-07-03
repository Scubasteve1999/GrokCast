# CLAUDE.md — GrokCast

Native SwiftUI iOS weather app (iOS 18+): Open-Meteo primary + NWS hybrid (US alerts/observations) + xAI Grok for AI weather features. Only third-party dependency is MapboxMaps 11.x (SPM) for the Radar tab.

Deeper background: `AGENTS.md` (project conventions, written for Grok Build era), `DesignSystem.md` (color/typography/spacing tokens — follow it for all UI work), `.grok/skills/grokcast/SKILL.md` (detailed feature history).

## Build & verify

```bash
xcodegen generate   # after editing project.yml or adding/removing files (or ./grok-build regenerate)
xcodebuild -project GrokCast.xcodeproj -scheme GrokCast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
```

- Installed simulators include iPhone 17 Pro Max / 17 / 17e / Air (no "iPhone 17 Pro").
- Lint with `swift-format`. Bump build before archiving: `./Scripts/increment_build.sh` or `./grok-build increment-build --tag`.

## Architecture

- Single `@Observable WeatherStore` (Shared/Services/) injected via `.environment()`; all business logic/API calls in `Shared/Services/`, views in `Features/<Feature>/`.
- 7 tabs (ContentView.swift MainTabView): Today, Forecast, Radar, Alerts, Grok AI, Locations, Settings. System tab bar hidden; custom `CompactTabBar` via safeAreaInset.
- Radar: Mapbox-based (`RadarMapboxRepresentable.swift`), decomposed into RadarState/RadarLoader/RadarTimeline/RadarPlayback/etc. Tile providers: RainViewer (live primary) → OpenWeatherMap fallback; Xweather primary for forecast frames.
- Grok/xAI: `XAIService` (chat/vision), `GrokBuildService` (SSE streaming), `GrokAIService` + `GrokAIConversationStore`; prompts centralized in `Shared/Grok/GrokPrompts.swift`.
- Widgets (`GrokCastWidgets` target) read App Group `group.com.scubasteve1999.GrokCast` snapshots only — never call APIs from the widget.

## Hard rules

- **Never put real API keys in tracked source.** Keys live in the iOS Keychain (`KeychainService`) and gitignored `GrokCast/Config/DeveloperAPIKey.swift` (embedded for TestFlight). `GrokAPIConfiguration.swift` stays secrets-free.
- `Identifiable` in Codable forecast models must use stable Date-based IDs (`var id: Date { time }`), never `UUID()`.
- Dark-first UI; reuse DesignTokens / TacticalCard / Haptic / ultraThinMaterial patterns; keep diffs small and focused. **Exception:** **Today**, **Forecast**, and **Alerts** use a bright, Apple-Weather-style condition sky with translucent frosted cards (`Features/Today/TodayBrightTheme.swift` — `TodaySkyBackground`, `.todayGlassCard`, `TodayBright.*`, shared sections in `TodayAppleSections.swift`). Radar, Grok AI, Locations, and Settings stay dark-first.
- NWS is strictly additive: non-US locations or NWS failures must stay silent (no errors surfaced, Open-Meteo remains source of truth).
- Prefer plain URLSession + async/await; no networking libraries.
