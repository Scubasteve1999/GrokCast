# GrokCast — App Store Copy

Paste into App Store Connect when resubmitting after the July 8, 2026 review.

---

## Privacy Policy URL (App Store Connect → App Privacy)

```
https://scubasteve1999.github.io/GrokCast/privacy
```

---

## Terms of Use (EULA)

You are using a **custom Terms of Use** hosted on GitHub Pages. Add this line to the **bottom of your App Description** (required by Guideline 3.1.2):

```
Terms of Use: https://scubasteve1999.github.io/GrokCast/terms
```

Alternatively, paste the same URL in App Store Connect → App Information → License Agreement (Custom EULA).

---

## Subtitle (30 chars max)

```
AI Weather & Severe Alerts
```

---

## Promotional Text (170 chars max)

```
Grok-powered weather with NWS radar, severe alert notifications, and Significant Location refresh when you travel — not continuous GPS tracking.
```

---

## Description

GrokCast is your AI-powered weather command center — beautiful forecasts, NWS severe alerts, live radar, and Grok intelligence in one native iOS app.

**Today & Forecast**
- Stunning current-conditions hero with hourly and 10-day outlooks
- NWS observations and official US forecast grids where available
- Open-Meteo fallback for reliable worldwide coverage

**Severe Weather**
- NWS Warnings and Watches with an offline-friendly Alerts tab
- Optional local notifications when new alerts are issued
- Interactive radar with NWS reflectivity overlays

**Grok AI**
- Quick prompts: outfit advice, activity suggestions, weekly summary
- Full conversational chat with live weather context injected
- Storm Spotter vision analysis for sky and storm photos

**Background updates (optional)**
- Low-power Significant Location Changes refresh weather when you travel
- No continuous GPS tracking — toggle off anytime in Settings

**Widgets**
- Home Screen and Lock Screen widgets for your saved locations

GrokCast Pro (auto-renewable subscription)
- Unlock premium Grok AI features and advanced capabilities
- Monthly and annual plans available; prices shown in-app before purchase
- Cancel anytime in App Store account settings

Terms of Use: https://scubasteve1999.github.io/GrokCast/terms

---

## Keywords

weather,forecast,radar,Grok,AI,NWS,alerts,severe,storm,widget

---

## Review notes (private, App Review Information → Notes)

**Guideline 2.5.4 — Background location**
- Removed `location` from `UIBackgroundModes`. GrokCast does **not** use persistent real-time background GPS.
- Background weather refresh uses **Significant Location Changes** (`startMonitoringSignificantLocationChanges`) plus `BGAppRefreshTask` for NWS alert polling.
- Optional toggle: Settings → Background Weather Updates.

**Guideline 3.1.2 — Subscriptions**
- Privacy Policy and Terms of Use links are in Settings → Legal.
- Subscription auto-renew disclosure is shown in Settings → Legal and on the in-app purchase screen.
- Privacy Policy URL is set in App Store Connect; Terms of Use (EULA) link is in the App Description above.

**Demo account / API key**
- Grok AI features require an xAI API key (Settings → xAI Developer Key) or the embedded TestFlight developer key if included in this build.

---

## Resubmission reply template (paste in App Store Connect resolution center)

```
Hello App Review,

We have addressed both issues:

1. Guideline 3.1.2(c): Added a functional Terms of Use (EULA) link to the App Store description and confirmed Privacy Policy + Terms links in the app under Settings → Legal, including subscription auto-renew disclosure.

2. Guideline 2.5.4: Removed the "location" UIBackgroundModes entry. GrokCast uses Significant Location Changes and BGAppRefreshTask only — not persistent background GPS. The optional feature is Settings → Background Weather Updates.

Thank you for your review.
```
