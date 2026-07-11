# SpotterCast — App Store Copy

Paste into App Store Connect when resubmitting after the July 11, 2026 Guideline 4.1(a) rejection.

**Public name:** SpotterCast  
**Build:** 1.0.1 (48)  
**Do not use** the words Grok, GrokCast, or xAI Grok anywhere in App Store metadata.

> **Name locked:** SpotterCast (confirmed available in App Store Connect). `StormCast` and `NimbusCast` were taken.

---

## App Name (30 chars max)

```
SpotterCast
```

---

## Privacy Policy URL (App Store Connect → App Privacy)

```
https://scubasteve1999.github.io/SpotterCast/privacy
```

Update the hosted page content to say **SpotterCast** (URL path can stay).

---

## Terms of Use (EULA)

You are using a **custom Terms of Use** hosted on GitHub Pages. Add this line to the **bottom of your App Description** (required by Guideline 3.1.2):

```
Terms of Use: https://scubasteve1999.github.io/SpotterCast/terms
```

Alternatively, paste the same URL in App Store Connect → App Information → License Agreement (Custom EULA).

Update the hosted page content to say **SpotterCast**.

---

## Subtitle (30 chars max)

**Not keywords.** Subtitle is a short marketing line shown under the app name.

```
AI Weather & Severe Alerts
```

Do **not** paste `weather,forecast,radar,AI,NWS` here — that belongs in Keywords.

---

## Promotional Text (170 chars max)

```
AI-powered weather with NWS radar, severe alert notifications, and Significant Location refresh when you travel — not continuous GPS tracking.
```

---

## Description

SpotterCast is your AI-powered weather command center — beautiful forecasts, NWS severe alerts, live radar, and smart weather insights in one native iOS app.

**Today & Forecast**
- Stunning current-conditions hero with hourly and 10-day outlooks
- NWS observations and official US forecast grids where available
- Open-Meteo fallback for reliable worldwide coverage

**Severe Weather**
- NWS Warnings and Watches with an offline-friendly Alerts tab
- Optional local notifications when new alerts are issued
- Interactive radar with NWS reflectivity overlays

**AI Weather Assistant**
- Quick prompts: outfit advice, activity suggestions, weekly summary
- Full conversational chat with live weather context injected
- Storm Spotter vision analysis for sky and storm photos

**Background updates (optional)**
- Low-power Significant Location Changes refresh weather when you travel
- No continuous GPS tracking — toggle off anytime in Settings

**Widgets**
- Home Screen and Lock Screen widgets for your saved locations

SpotterCast Pro (auto-renewable subscription)
- Unlock premium AI weather features and advanced capabilities
- Monthly and annual plans available; prices shown in-app before purchase
- Cancel anytime in App Store account settings

Terms of Use: https://scubasteve1999.github.io/SpotterCast/terms

---

## Keywords

Paste only in the **Keywords** field (not Subtitle):

```
weather,forecast,radar,AI,NWS,alerts,severe,storm,widget,assistant
```

(Do **not** include Grok or GrokCast.)

---

## Review notes (private, App Review Information → Notes)

**Guideline 4.1(a) — Branding**
- App display name and all user-facing branding are now **SpotterCast**.
- Removed third-party “Grok” references from the app name, UI, icon, and App Store metadata.
- AI features are presented as SpotterCast’s own weather assistant (no association claimed with another developer’s product).

**Guideline 2.5.4 — Background location**
- Removed `location` from `UIBackgroundModes`. SpotterCast does **not** use persistent real-time background GPS.
- Background weather refresh uses **Significant Location Changes** (`startMonitoringSignificantLocationChanges`) plus `BGAppRefreshTask` for NWS alert polling.
- Optional toggle: Settings → Background Weather Updates.

**Guideline 3.1.2 — Subscriptions**
- Privacy Policy and Terms of Use links are in Settings → Legal.
- Subscription auto-renew disclosure is shown in Settings → Legal and on the in-app purchase screen.
- Privacy Policy URL is set in App Store Connect; Terms of Use (EULA) link is in the App Description above.

**Demo account / API key**
- AI features require a developer API key (Settings → Developer Key) or the embedded TestFlight developer key if included in this build.

---

## Resubmission reply template (paste in App Store Connect Resolution Center)

```
Hello App Review,

Thank you for the feedback regarding Guideline 4.1(a).

We have removed all third-party “Grok” branding from the app and metadata. The app is now named SpotterCast. We updated:

• App name and display name
• App icon (no third-party marks or former brand text)
• Description, promotional text, and keywords
• In-app UI strings (tabs, prompts, widgets, notifications)
• Screenshots (please use the new set attached to this version)

SpotterCast does not claim affiliation with any other developer’s app or intellectual property. AI weather features are presented as SpotterCast’s own assistant.

Build 1.0.1 (48) includes these changes.

Thank you for your review.
```

---

## App Store Connect checklist (manual)

Complete these in ASC / asset tooling before submitting:

1. **App Information → Name** → `SpotterCast` (confirmed)
2. **Subtitle** → `AI Weather & Severe Alerts` (not comma-separated keywords)
3. **Keywords** → paste the Keywords block above
4. Paste **Promotional Text** and **Description** from this file
5. Upload **new screenshots** that show SpotterCast / AI (not GrokCast / Grok AI)
6. Confirm **app icon** in the binary is the new text-free weather icon (build 48)
7. Update **IAP / subscription display name** to `SpotterCast Pro` if it still says GrokCast Pro
8. Update hosted **Privacy**, **Terms**, and **Support** page titles/body to SpotterCast (URLs may stay)
9. Paste the **Resolution Center reply** above when you resubmit
10. Archive & upload **1.0.1 (48)** from Xcode (scheme `GrokCast`)
