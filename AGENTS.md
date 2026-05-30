# AGENTS.md — GrokCast

This document governs all AI agent (Grok) work on the GrokCast iOS project.

## Project Overview

**GrokCast** is a premium-feeling native SwiftUI iOS weather app that pairs Apple WeatherKit with xAI's Grok models for delightful, contextual AI weather experiences ("Grok's Take", outfit advice, activity suggestions, free chat).

Core pillars:
- Beautiful, dark, typographic-heavy weather UI (Today hero + forecasts)
- First-class xAI integration (quick prompts + conversational chat with live weather context)
- Simple, clean architecture using modern Observation + async/await
- Zero third-party dependencies for core functionality

**Status (May 2026)**: Freshly scaffolded via `grok build new swiftui-ios-app GrokCast --template weather-forecast --integrate xai-api`. Ready for first-run polish, real device testing, and feature expansion.

## Repository Layout (follow this)

```
GrokCast/
├── GrokCast.xcodeproj/
├── GrokCast/
│   ├── App/
│   │   └── GrokCastApp.swift
│   ├── Features/
│   │   ├── Today/
│   │   ├── Forecast/
│   │   ├── GrokAI/
│   │   └── Locations/
│   ├── Shared/
│   │   ├── Models/
│   │   ├── Services/   # LocationService, WeatherService, XAIService, WeatherStore
│   │   └── Components/
│   └── Resources/Assets.xcassets/
├── project.yml
├── README.md
└── AGENTS.md
```

## Development Commands

```bash
# Open project
xed .

# Regenerate Xcode project after changing project.yml
xcodegen generate

# Clean build (from project root)
xcodebuild -project GrokCast.xcodeproj -scheme GrokCast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' clean build

# Full clean (when things get weird)
rm -rf ~/Library/Developer/Xcode/DerivedData/GrokCast-*
```

## Coding Conventions

- **SwiftUI + Observation** (`@Observable`, `@State`, `@Environment`)
- All business logic and API calls live in `Shared/Services/`
- Views live in `Features/<Feature>/<Feature>View.swift`
- Keep WeatherKit types mostly wrapped or lightly extended (see WeatherModels.swift)
- xAI integration is deliberately simple URLSession — do not introduce heavy networking libs unless justified
- Dark mode first. Gradients, large numbers, SF Symbols, and subtle materials.
- Haptics via the tiny `Haptic` helper when actions succeed
- No SwiftData until we need persistence beyond UserDefaults (start simple)

**Naming**:
- `*Service.swift` for single-responsibility managers (Location, Weather, XAI)
- `*Store.swift` for the central observable state holder
- Feature views end in `View.swift`

## xAI + WeatherKit Specifics

- xAI endpoint: `https://api.x.ai/v1/chat/completions` (OpenAI compatible)
- Default model: `grok-3-mini` (fast). Upgrade to `grok-3` when responses need more depth.
- Always inject current weather as a strong system prompt for best results.
- API key handling: Currently UserDefaults (fine for prototype). Production → Keychain + SecureField.
- WeatherKit capability + entitlements already configured in project.yml.

## Common Gotchas

1. **WeatherKit on Simulator**: Works without paid Apple dev account for development.
2. **Location permission**: Both "When In Use" descriptions are in Info.plist.
3. **After adding files**: If Xcode complains about missing files, regenerate with xcodegen or add manually in the navigator.
4. **API key not persisting?** Check UserDefaults in the simulator.
5. **Build errors after structural changes**: `xcodebuild clean` + delete DerivedData.

## Working With Grok Here

- Always `cd /Users/stephenmoore/Desktop/GrokCast` (or the exact worktree) before running `grok`
- Prefer small, reviewable diffs when iterating on the AI chat experience or UI polish
- When touching XAIService, test both happy path and the "missing/invalid key" error states
- Keep the "Grok personality" fun but useful — the system prompt in XAIService is the source of truth

---

**Last updated**: May 2026 (scaffolded by Grok)

Update this file when architecture, key integrations, or team practices evolve.
