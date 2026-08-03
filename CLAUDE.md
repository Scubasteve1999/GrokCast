# CLAUDE.md — GrokCast

Native SwiftUI iOS weather app (iOS 18+): Open-Meteo primary + NWS hybrid (US alerts/observations) + xAI Grok for AI weather features. App Store name is **SpotterCast**; codebase/Xcode scheme is **GrokCast**.

Deeper background: `AGENTS.md` (full project rules — source of truth), `DesignSystem.md` (color/typography/spacing tokens — follow it for all UI work), `.grok/skills/grokcast/SKILL.md` (detailed feature history), `docs/Agent-Handoff-Claude-Cursor.md` (Claude Code ↔ Cursor handoff).

**Always work from the app repo root** (not the marketing site):

```bash
cd ~/Projects/GrokCast
# real path (prefer this if xcodebuild hangs on Desktop/iCloud):
cd /Users/bigstevedev/Documents/GrokCast
```

| Path | What it is |
|------|------------|
| `~/Projects/GrokCast` → `Documents/GrokCast` | **iOS app** (this repo) |
| `~/Projects/SpotterCast` → `Documents/SpotterCast` | Marketing site only (HTML) — not the app |

## Commands

Run all commands from the app repo root above.

### Build

```bash
xcodebuild -project GrokCast.xcodeproj -scheme GrokCast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
```

Clean build when needed:

```bash
xcodebuild -project GrokCast.xcodeproj -scheme GrokCast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' clean build
```

### Test

Always run tests after non-trivial changes:

```bash
xcodebuild -project GrokCast.xcodeproj -scheme GrokCast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test
```

Targets: `GrokCast`, `GrokCastWidgets`, `GrokCastTests`, `GrokCastUITests`.
Scheme: `GrokCast` (also `GrokCastWidgets` for widget-only work).

### Archive / TestFlight

Preferred:

```bash
./Scripts/archive_for_testflight.sh              # archive only
./Scripts/archive_for_testflight.sh --increment  # bump CURRENT_PROJECT_VERSION in project.yml, then archive
# optional upload after a successful archive:
./Scripts/upload_testflight.sh
```

Manual equivalent:

```bash
xcodebuild -project GrokCast.xcodeproj -scheme GrokCast \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/GrokCast.xcarchive \
  archive
```

Build number lives in `project.yml` (`CURRENT_PROJECT_VERSION`). Prefer `./Scripts/increment_build.sh` or `./Scripts/archive_for_testflight.sh --increment` over `agvtool` (xcodegen regenerates wipe agvtool-only bumps).

### Project regeneration & utilities

```bash
xcodegen generate          # after project.yml or add/remove source files
./grok-build regenerate    # wrapper (preferred when available)
./grok-build clean         # or --deep for stubborn issues
rm -rf ~/Library/Developer/Xcode/DerivedData/GrokCast-*
xed .                      # open in Xcode
```

**Default simulator:** `iPhone 17 Pro Max`. Also available: iPhone 17 Pro, 17, 17e, Air.

## Hard rules

1. **Never commit secrets or API keys.** Keys live in the iOS Keychain (`KeychainService`) and gitignored `GrokCast/Config/DeveloperAPIKey.swift` (TestFlight embed only). `GrokAPIConfiguration.swift` stays secrets-free. Stub templates live as `*.example` under `GrokCast/Config/`.
2. **Never change entitlement / paywall / StoreKit Pro logic without explicit approval.**
3. Prefer **small, reviewable diffs**. Match existing code style exactly; clarity over cleverness.
4. **Do not introduce new dependencies** without asking.
5. **Always run tests** after non-trivial changes (see Test command).
6. **NWS is strictly additive.** Non-US locations or NWS failures must stay silent (no errors surfaced). Open-Meteo remains source of truth for primary forecast numbers.
7. Prefer plain `URLSession` + async/await; no new networking libraries.
8. `Identifiable` in Codable forecast models must use **stable Date-based IDs** (`var id: Date { time }`), never `UUID()`.
9. Widgets read App Group snapshots only — **never call weather/AI APIs from the widget extension**.
10. Build/archive from the **Documents** tree when `xcodebuild` hangs on Desktop/iCloud-synced paths.

## Architecture

- Single `@Observable WeatherStore` (Shared/Services/) injected via `.environment()`; all business logic/API calls in `Shared/Services/`, views in `Features/<Feature>/`.
- 7 tabs (ContentView.swift MainTabView): Today, Forecast, Radar, Alerts, Grok AI, Locations, Settings. System tab bar hidden; custom `CompactTabBar` via safeAreaInset.
- Radar: Mapbox-based (`RadarMapboxRepresentable.swift`), decomposed into RadarState/RadarLoader/RadarTimeline/RadarPlayback/etc. Tile providers: RainViewer (live primary) → OpenWeatherMap fallback; Xweather primary for forecast frames.
- Grok/xAI: `XAIService` (chat/vision), `GrokBuildService` (SSE streaming), `GrokAIService` + `GrokAIConversationStore`; prompts centralized in `Shared/Grok/GrokPrompts.swift`.
- Widgets (`GrokCastWidgets` target) read App Group `group.com.scubasteve1999.GrokCast` snapshots only — never call APIs from the widget.
- SPM already in use: MapboxMaps, Firebase Messaging, PostHog — do not add more without asking.
- Dark-first UI; reuse DesignTokens / TacticalCard / Haptic / ultraThinMaterial patterns — see `DesignSystem.md`.
- Lint with `swift-format` when touching formatting-sensitive files.
