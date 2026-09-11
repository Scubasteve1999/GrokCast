# DayCast

Native SwiftUI weather app for **iOS 18+**. App Store name and Xcode scheme: **DayCast**.

Open-Meteo is the source of truth for forecast numbers. NWS is US-only and additive (alerts/observations). xAI Grok powers Sky Check and other AI features.

**Work from `~/Projects/GrokCast`.** `~/Documents/GrokCast` is an iCloud-synced mirror — do not use it.

## Current truth

| What | Where |
|------|--------|
| Agent rules, commands, archive, Xcode Cloud | [`AGENTS.md`](AGENTS.md) |
| Product IA, chrome, do-not-recreate | [`.grok/skills/daycast/SKILL.md`](.grok/skills/daycast/SKILL.md) |
| Marketing version + build | [`project.yml`](project.yml) (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) |
| Design tokens | [`DesignSystem.md`](DesignSystem.md) |
| Hosted Pro Grok proxy | [`server/grok-proxy/README.md`](server/grok-proxy/README.md) |

IA (compact): Today · Forecast · Radar · Alerts · More. Sky Check, Locations, and Settings live under More.

Public chrome: **Sky Check** (not Storm Spotter / Briefing Studio). Radar: **Site Doppler** / **National radar**.

## Build

```bash
cd ~/Projects/GrokCast
xcodebuild -project DayCast.xcodeproj -scheme DayCast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
```

Default simulator: iPhone 17 Pro Max. After `project.yml` or source add/remove: `xcodegen generate` (or `./grok-build regenerate`).

## Secrets

Never commit API keys. Keys live in the iOS Keychain (`KeychainService`) and gitignored `DayCast/Config/DeveloperAPIKey.swift`. `DayCast/Shared/Configuration/GrokAPIConfiguration.swift` stays secrets-free. Stub templates live as `*.example` under `DayCast/Config/`.
