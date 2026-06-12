# GrokCast

**GrokCast** — AI-powered weather forecasts with Grok (xAI).

A beautiful native SwiftUI iOS app that combines Apple WeatherKit for accurate forecasts with xAI's Grok for witty, contextual weather insights, outfit suggestions, activity recommendations, and free-form chat about the weather.

Built with the `grok build new swiftui-ios-app` template (weather-forecast + xai-api integration).

## Features

- **Today View**: Stunning hero display of current conditions with large typography, SF Symbols, and a rich detail grid (feels-like, humidity, wind, UV, precip, visibility).
- **Forecast**: 24-hour horizontal scroller + 10-day vertical forecast with precipitation chances.
- **Grok AI**: 
  - Quick prompt buttons ("Grok's Take", "What to Wear", "Good for a Walk?", etc.)
  - Full chat interface with conversation history
  - Weather context automatically injected into every Grok response
- **Locations**: Add/search cities, use device location, switch between them. Persistent.
- **xAI Integration**: Enter your API key once in the Locations tab. Uses `grok-3-mini` by default (fast & cheap).

## Requirements

- iOS 17.0+
- Xcode 16+
- Apple Developer account (for WeatherKit capability on device; simulator works without paid account for basic testing)
- Free xAI API key from https://console.x.ai/

## Getting Started

1. **Clone / Open**
   ```bash
   cd ~/Desktop/GrokCast
   open GrokCast.xcodeproj
   # or xed .
   ```

2. **Add your xAI API Key**
   - Run on simulator
   - Go to **Locations** tab
   - Tap "Add Key"
   - Paste your key (starts with `xai-...`)
   - Key is stored locally (demo). For shipping apps, move to Keychain.

3. **Run**
   - Select a simulator (iPhone 17 Pro recommended)
   - Build & Run (⌘R)
   - Grant location permission when prompted
   - WeatherKit works great in Simulator.

## Secrets & API Keys

This project follows secure practices for handling API keys:

- **Never commit real API keys** to the repository.
- The real xAI API key is stored **only in the iOS Keychain** using `KeychainService`.
- `GrokAPIConfiguration.swift` contains **only public configuration** (base URLs, endpoints, model names, timeouts, etc.).
- A safe template file (`GrokAPIConfiguration.swift.example`) is committed so other developers know the expected structure.

### How to set up your local environment

1. Copy the example file:
   ```bash
   cp GrokAPIConfiguration.swift.example GrokAPIConfiguration.swift
   ```

The real xAI key is managed automatically through the app’s **Settings** tab and stored securely in the Keychain.

**Do not paste real keys into any .swift file.**

This pattern keeps the codebase clean while protecting credentials.

## Architecture

```
GrokCast/
├── App/
│   └── GrokCastApp.swift
├── Features/
│   ├── Today/          # Hero current conditions
│   ├── Forecast/       # Hourly + Daily
│   ├── GrokAI/         # Quick prompts + streaming-style chat
│   └── Locations/      # Saved places + xAI key management
├── Shared/
│   ├── Models/         # SavedLocation, WeatherData, ChatMessage, QuickPrompt
│   ├── Services/
│   │   ├── LocationService.swift      # CLLocationManager + reverse geocode
│   │   ├── WeatherService.swift       # Thin wrapper over WeatherKit
│   │   ├── XAIService.swift           # OpenAI-compatible /v1/chat/completions to api.x.ai
│   │   └── WeatherStore.swift         # Central @Observable state + persistence
│   └── Components/
├── Resources/
│   └── Assets.xcassets/
└── project.yml
```

**Key Design Decisions** (weather-forecast template):
- Pure SwiftUI + Observation framework (no Combine boilerplate)
- Weather data powered 100% by native **WeatherKit** (no extra API keys for weather)
- xAI calls use simple `URLSession` + JSON (no third-party networking libs)
- Dark-first beautiful UI with glassmorphism and large weather typography
- One central `WeatherStore` injected via `.environment()`

## Next Steps / Polish Ideas

- Add Settings tab (units toggle, API key management, about)
- SwiftData persistence for saved locations + chat history
- WidgetKit + Live Activities for current weather + "Grok score"
- Streaming responses from xAI (SSE)
- Air quality + pollen from WeatherKit
- Haptic feedback on refresh / prompt send
- Onboarding flow explaining Grok + WeatherKit
- App Icon & Launch Screen

## Building from Source

The project was generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
xcodegen generate
```

After editing `project.yml`, always regenerate.

## Pre-Archive / Release Helpers

Before archiving for TestFlight or the App Store:

1. **Add your App Icon**
   - Place a **1024×1024** PNG file named `AppIcon-1024.png` into:
     ```
     GrokCast/Resources/Assets.xcassets/AppIcon.appiconset/
     ```
   - Then run:
     ```bash
     ./grok-build regenerate
     ```

2. Increment the build number:
   ```bash
   ./Scripts/increment_build.sh
   ```

This uses `agvtool` to automatically bump `CFBundleVersion` across the project.

**Tip:** Run this right before you do **Product → Archive**.

### Using the Local Grok Build Helper

For convenience, you can use the local `grok-build` wrapper:

```bash
./grok-build increment-build
```

Add `--tag` to also create a git tag (e.g. `v1.0-b12`):

```bash
./grok-build increment-build --tag
```

This is the recommended way before archiving for TestFlight.

## License

MIT — do whatever, just don't blame Grok when it tells you it's perfect weather for a picnic and then it rains.

---

Built by Grok • April 2026
