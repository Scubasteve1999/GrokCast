# App Store Review Notes (draft)

Copy into **App Store Connect → App Review Information → Notes** when you submit (also synced to `fastlane/metadata/review_information/notes.txt`).

---

SpotterCast combines Open-Meteo forecasts, National Weather Service alerts and observations, Mapbox radar, and optional AI weather features (powered by an xAI API key) for briefings and storm photo analysis.

## Reviewer access — no account

No account or sign-in is required. Location is optional (defaults to Olive Branch, MS). AI chat uses an embedded developer key in this build; if AI fails, Settings accepts a key starting with `xai-`.

Suggested path:

1. Allow location when prompted (or use the default location).
2. Today — conditions, SpotterCast Score, Minutecast.
3. Radar — interactive map with animation.
4. Alerts — live NWS watches/warnings.
5. AI — try a quick prompt; should stream a reply.
6. Settings → LEGAL & SUPPORT — Privacy Policy and Terms of Use.

## SpotterCast Pro (subscriptions) — how to review

Open the paywall from **Settings → SpotterCast Pro → View SpotterCast Pro**.

You can also trigger it by:
- Turning on **Live Activity** in Settings (Pro gate), or
- Trying to save a **second location** (free limit is 1).

Product IDs in this binary:

- `com.scubasteve1999.GrokCast.pro.monthly` — SpotterCast Pro Monthly
- `com.scubasteve1999.GrokCast.pro.yearly` — SpotterCast Pro Yearly

Pro unlocks: forecast radar (FUTURE), Live Activity, unlimited saved locations, widget AI brief.  
AI chat works with the embedded key for all users; a hosted Pro proxy is not required for review.

Paywall includes **Privacy Policy** and **Terms of Use (EULA)** links and **Restore Purchases**.

## Subscriptions (3.1.2)

- Privacy: https://scubasteve1999.github.io/SpotterCast/privacy/
- Terms: https://scubasteve1999.github.io/SpotterCast/terms/
- Support: https://scubasteve1999.github.io/SpotterCast/support/

## Location / background

When In Use + optional Significant Location Changes only; no `location` background mode.

**Contact:** stephenmoorecm1357@gmail.com
