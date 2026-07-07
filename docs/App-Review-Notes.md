# App Store Review Notes (draft)

Copy into **App Store Connect → App Review Information → Notes** when you submit.

---

## App summary

GrokCast is an iPhone weather app that combines Open-Meteo forecasts, NWS alerts and observations, Mapbox radar, and optional Grok/xAI features for briefings and storm photo analysis.

**This submission (v1.0.1) is iPhone only** — no Apple Watch app or watchOS complications are included in this build.

## Location

- **When In Use** and optional **Always** for Significant Location Changes (background refresh when the user travels).
- Location drives local forecast, radar center, and NWS alerts.
- The first-launch flow explains why location is needed before the system prompt.

## Background modes

- `location` — Significant Location Changes (user toggle in Settings; requires Always authorization).
- `fetch` — BGAppRefreshTask for NWS alert polling when alert notifications are enabled.

## Grok / xAI

- Grok features require an xAI developer API key stored in the iOS Keychain, **or** an embedded developer key in TestFlight builds (`DeveloperAPIKey.swift`, gitignored).
- Weather questions send current conditions and forecast context to xAI; Storm Spotter may send a user-selected photo.
- Users can use the app without Grok (forecast, radar, alerts, widgets work without a key).

## Test account / reviewer access

- [ ] Add embedded reviewer key in `DeveloperAPIKey.swift` before archive, **or**
- [ ] Provide a demo xAI key in this field: `________________`

Suggested reviewer path:

1. Allow location when prompted (or use default Olive Branch, MS).
2. Open **Today** — score, Minutecast, Grok brief (if key present).
3. Open **Radar** — map loads; tap sparkles for Explain Radar (requires key).
4. Open **Settings** — Privacy Policy and Support links open GitHub Pages.

## Live Activities & notifications

- Live Activity is opt-in (Settings). Shows score, temp, and Minutecast.
- Severe weather notifications are opt-in; morning Grok brief is a separate local notification (opt-in, 7–11 AM).

## Privacy policy URL

https://scubasteve1999.github.io/GrokCast/privacy.html

## Support URL

https://scubasteve1999.github.io/GrokCast/support.html

---

**Contact:** Scubasteve1999@users.noreply.github.com (or update before submit)
