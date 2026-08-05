# AGENTS.md — DayCast

This document governs all AI agent work on this iOS project.

## Identity & paths

| Name | Role |
|------|------|
| **DayCast** | App Store display name, Xcode project, scheme, source tree |
| **PRODUCT_BUNDLE_IDENTIFIER** | `com.scubasteve1999.DayCast` (widgets: `…DayCast.DayCastWidgets`) |
| **App Group** | `group.com.scubasteve1999.DayCast` |
| **URL scheme** | `daycast://` |
| **Historical bundle ID** | `com.scubasteve1999.GrokCast` — changing the last segment is a **new App Store app identity**, not a cosmetic rename. Do not invent `com.daycast.*` as the product bundle ID. |

### Intentional legacy wire names (do not “clean up” blindly)

| Leftover | Why it stays |
|----------|----------------|
| Widget JSON keys `grokCastScore` / `grokCastScoreLabel` | App Group payloads from older installs |
| `grokBriefOneLiner` key | Same shared snapshot contract |

Notification category IDs use `DAYCAST_*`. In-process deep link uses `Notification.Name.dayCastDeepLink` (raw `"daycast.deepLink"`).

**Always work from the app repo root** (not the marketing site):

```bash
# Live path on this machine (folder may still be named GrokCast):
cd /Users/bigstevedev/Documents/GrokCast
# Prefer Documents/DayCast if/when the directory is renamed.
```

| Path | What it is |
|------|------------|
| `/Users/bigstevedev/Documents/GrokCast` (sources under `DayCast/`) | **iOS app** (this repo) |
| Separate marketing HTML site (if present) | Not the app binary |

## Stack

- SwiftUI + Xcode (iOS 18+)
- XcodeGen (`project.yml` → `DayCast.xcodeproj`)
- Observation (`@Observable`), async/await, plain `URLSession`
- SPM: MapboxMaps, Firebase Messaging, PostHog (do not add more without asking)
- WidgetKit + ActivityKit; App Group `group.com.scubasteve1999.DayCast`
- Weather: Open-Meteo (primary) + NWS hybrid (US alerts/observations, additive only)
- AI: xAI Grok via Keychain / optional gitignored developer embed

Prefer existing patterns in the codebase. Do not introduce new dependencies without asking.

## Commands

Run all commands from the app repo root above.

### Build

```bash
xcodebuild -project DayCast.xcodeproj -scheme DayCast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
```

Clean build when needed:

```bash
xcodebuild -project DayCast.xcodeproj -scheme DayCast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' clean build
```

### Test

Always run tests after non-trivial changes:

```bash
xcodebuild -project DayCast.xcodeproj -scheme DayCast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test
```

Targets: `DayCast`, `DayCastWidgets`, `DayCastTests`, `DayCastUITests`.
Scheme: `DayCast` (also `DayCastWidgets` for widget-only work).

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
xcodebuild -project DayCast.xcodeproj -scheme DayCast \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/DayCast.xcarchive \
  archive
```

Build number lives in `project.yml` (`CURRENT_PROJECT_VERSION`). Prefer `./Scripts/increment_build.sh` or `./Scripts/archive_for_testflight.sh --increment` over `agvtool` (xcodegen regenerates wipe agvtool-only bumps).

### Xcode Cloud archives

Xcode Cloud clones fresh, so it has none of the gitignored key files a local
archive already has on disk. `ci_scripts/ci_post_clone.sh` restores them from
secret environment variables on the **Build and Testflight** workflow
(App Store Connect → Xcode Cloud → Manage Workflows → Environment):

| Variable | Restores | Required for |
|---|---|---|
| `GOOGLE_SERVICE_INFO_PLIST_BASE64` | `DayCast/Config/GoogleService-Info.plist` | every Xcode Cloud build (hard build input) |
| `DEVELOPER_API_KEY_SWIFT_BASE64` | `DayCast/Config/DeveloperAPIKey.swift` | archive builds (Mapbox, Xweather, xAI) |
| `OPENWEATHERMAP_KEYS_SWIFT_BASE64` | `DayCast/Config/OpenWeatherMapKeys.swift` | optional — no real key is issued yet |

Generate each value with, e.g.:

```bash
base64 -i DayCast/Config/DeveloperAPIKey.swift | pbcopy
```

Paste it as the variable's value and check **Secret**. If a required file is
missing or still holds placeholder values, an archive build (`CI_XCODEBUILD_ACTION
= archive`) fails loudly rather than shipping a build with no working keys —
GitHub Actions PR builds are unaffected and use the committed `*.example`
templates instead.

### Project regeneration & utilities

```bash
xcodegen generate          # after project.yml or add/remove source files
./grok-build regenerate    # wrapper (preferred when available)
./grok-build clean         # or --deep for stubborn issues
rm -rf ~/Library/Developer/Xcode/DerivedData/DayCast-*
xed .                      # open in Xcode
```

**Default simulator:** `iPhone 17 Pro Max`. Also available: iPhone 17 Pro, 17, 17e, Air.

## Hard rules

1. **Never commit secrets or API keys.** Keys live in the iOS Keychain (`KeychainService`) and gitignored `DayCast/Config/DeveloperAPIKey.swift` (TestFlight embed only). `GrokAPIConfiguration.swift` stays secrets-free. Stub templates live as `*.example` under `DayCast/Config/`.
2. **Never change entitlement / paywall / StoreKit Pro logic without explicit approval.**
3. Prefer **small, reviewable diffs**. Match existing code style exactly; clarity over cleverness.
4. **Do not introduce new dependencies** without asking.
5. **Always run tests** after non-trivial changes (see Test command).
6. **NWS is strictly additive.** Non-US locations or NWS failures must stay silent (no errors surfaced). Open-Meteo remains source of truth for primary forecast numbers.
7. Prefer plain `URLSession` + async/await; no new networking libraries.
8. `Identifiable` in Codable forecast models must use **stable Date-based IDs** (`var id: Date { time }`), never `UUID()`.
9. Widgets read App Group snapshots only — **never call weather/AI APIs from the widget extension**.
10. Build/archive from the **Documents** tree when `xcodebuild` hangs on Desktop/iCloud-synced paths.

## Style & architecture

- **SwiftUI + Observation**: `@Observable`, `@State`, `@Environment(WeatherStore.self)`
- Central state: single `@Observable WeatherStore` in `Shared/Services/`, injected via `.environment()`
- Business logic and API calls: `Shared/Services/`
- Views: `Features/<Feature>/` (e.g. `TodayView.swift`)
- Design: dark-first; reuse DesignTokens / TacticalCard / Haptic / `ultraThinMaterial` — see `DesignSystem.md`
- Naming: `*Service.swift` (managers), `*Store.swift` (observable state), feature views end in `View.swift`
- Grok prompts centralized in `Shared/Grok/GrokPrompts.swift`
- Radar subsystem under `Features/Radar/` (Mapbox representable + loader/timeline/playback)

### Layout (high level)

```
DayCast/
├── DayCast.xcodeproj/
├── DayCast/
│   ├── App/
│   ├── Features/          # Today, Forecast, Radar, Alerts, GrokAI, Locations, Settings, …
│   ├── Shared/
│   │   ├── Models/
│   │   ├── Services/      # WeatherStore, Location, OpenMeteo, NWS, XAI, …
│   │   ├── Grok/
│   │   └── Components/
│   └── Resources/
├── DayCastWidgets/
├── DayCastTests/
├── DayCastUITests/
├── Scripts/               # archive_for_testflight, increment_build, upload_testflight, …
├── project.yml
├── CLAUDE.md
└── AGENTS.md
```

## Common gotchas

1. After adding/removing files or editing `project.yml`, run `xcodegen generate` (or `./grok-build regenerate`) before building.
2. Location + Open-Meteo work in Simulator without paid accounts; grant location when prompted.
3. CI stubs gitignored config from `*.example` templates — local builds need those files present if missing.
4. Structural churn → `clean build` or wipe DerivedData (see utilities above).
5. When touching XAI/Grok paths, exercise happy path and missing/invalid key error states.

## Related docs

- `CLAUDE.md` — short agent bootstrap (build + hard rules)
- `DesignSystem.md` — color/typography/spacing tokens
- `.grok/skills/daycast/SKILL.md` — feature history and radar/Grok patterns
- `docs/` — handoffs, App Store notes, roadmaps

---

**Last updated:** 2026-08-02

Update this file when architecture, commands, or team practices change.
