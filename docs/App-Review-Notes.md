# App Store Review Notes (draft)

Copy into **App Store Connect → App Review Information → Notes** when you submit (also synced to `fastlane/metadata/review_information/notes.txt`).

---

SpotterCast combines Open-Meteo forecasts, National Weather Service alerts and observations, Mapbox radar, and optional AI weather features (powered by an xAI API key) for briefings and storm photo analysis.

## Reviewer access — AI chat

No account or sign-in is required. Embed a working `DeveloperAPIKey.xai` before archive so AI works out of the box. If AI chat fails, Settings accepts a key starting with `xai-`.

Suggested path:

1. Allow location when prompted (or use default Olive Branch, MS).
2. Today — conditions, SpotterCast Score, Minutecast.
3. Radar — interactive map with animation.
4. Alerts — live NWS watches/warnings.
5. AI — try a quick prompt; should stream a reply.
6. Settings → LEGAL & SUPPORT — Privacy Policy and Terms of Use.
7. SpotterCast Pro paywall — Privacy Policy + Terms of Use (EULA) links.

## Subscriptions (3.1.2)

- Privacy: https://scubasteve1999.github.io/SpotterCast/privacy/
- Terms: https://scubasteve1999.github.io/SpotterCast/terms/

## Location / background

See previous notes: When In Use + optional Significant Location Changes only; no `location` background mode.

**Contact:** stephenmoorecm1357@gmail.com
