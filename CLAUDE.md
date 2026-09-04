# CLAUDE.md — DayCast

Native SwiftUI iOS weather app (iOS 18+): Open-Meteo primary + NWS hybrid (US alerts/observations) + xAI Grok for AI weather features. App Store name is **DayCast**; codebase/Xcode scheme is **DayCast**.

Deeper background: `AGENTS.md` (full project rules — source of truth), `DesignSystem.md` (color/typography/spacing tokens — follow it for all UI work), `.grok/skills/daycast/SKILL.md` (detailed feature history), `docs/Agent-Handoff-Claude-Cursor.md` (Claude Code ↔ Cursor handoff).

**Always work from the app repo root**:

```bash
cd ~/Projects/GrokCast
# ~/Documents/GrokCast is an iCloud-synced mirror of the same repo — avoid it,
# git and xcodebuild operations there can hang indefinitely.
```

| Path | What it is |
|------|------------|
| `~/Projects/GrokCast` | **iOS app** (this repo; Xcode project/scheme/App Store name are DayCast) |
| `~/Projects/GrokCast/docs/*.html` | Marketing/support site (privacy, terms, support) — static HTML inside this repo, not a separate one |
| `~/Documents/GrokCast` | iCloud-synced mirror — do not work from here |

## Commands

Run all commands from the app repo root above.

### Build

```bash
xcodebuild -project DayCast.xcodeproj -scheme DayCast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
```

### Test

Always run tests after non-trivial changes:

```bash
xcodebuild -project DayCast.xcodeproj -scheme DayCast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test
```

Archive/TestFlight and project-regeneration commands: see `AGENTS.md`.

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

## Architecture

- Dark-first UI; reuse DesignTokens / TacticalCard / Haptic / ultraThinMaterial patterns — see `DesignSystem.md`.
- Lint with `swift-format` when touching formatting-sensitive files.
