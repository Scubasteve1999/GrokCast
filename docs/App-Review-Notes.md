# App Store Review Notes (draft)

Copy into **App Store Connect → App Review Information → Notes** when you submit.
Kept in sync with `fastlane/metadata/review_information/notes.txt`.

---

DayCast combines Open-Meteo forecasts, National Weather Service alerts and observations,
Mapbox radar, and AI weather features (powered by xAI's Grok) for briefings, radar explanations,
and storm photo analysis.

## Reviewer access — no account

No account or sign-in is required. Location is optional (defaults to Olive Branch, MS).
Weather, radar, forecasts, and NWS alerts are free and need no purchase.

## Reaching the AI features — please read

**AI features require DayCast Pro in this build.** Earlier versions shipped an embedded xAI
developer key so anyone could use AI; that key has been removed. The key now lives on our server,
and AI calls are routed through it only for verified subscribers.

To review the AI features, **purchase DayCast Pro in the StoreKit sandbox** — sandbox purchases
are free and are not charged:

1. Open **Settings → DayCast Pro → View DayCast Pro**.
2. Choose Monthly or Yearly and complete the sandbox purchase.
3. Return to the **AI** tab and try a quick prompt. It should stream a reply within a few seconds.

Our server accepts both Production and Sandbox StoreKit environments, so a sandbox subscription
works exactly like a real one.

**Alternative, if you prefer not to transact:** Settings accepts your own xAI API key (starts with
`xai-`, from console.x.ai). With a key saved, all AI features unlock without a subscription.

If AI reports "DayCast Pro unlocks AI features," the subscription has not been recognised yet —
tap **Restore Purchases** in Settings and retry.

## Suggested path

1. Allow location when prompted (or use the default location).
2. **Today** — conditions, DayCast Score, Minutecast.
3. **Radar** — interactive map with animation.
4. **Alerts** — live NWS watches and warnings.
5. **AI** — after the sandbox purchase above, try a quick prompt; should stream a reply.
   Optional: Shortcuts → “Ask Grok” with a question (opens the AI tab and submits).
6. **Settings → LEGAL & SUPPORT** — Privacy Policy and Terms of Use.

## DayCast Pro (subscriptions) — how to review

Open the paywall from **Settings → DayCast Pro → View DayCast Pro**.

It can also be triggered by:

- Tapping any AI feature while not subscribed, or
- Turning on **Live Activity** or **Morning AI Brief** in Settings, or
- Trying to save a **second location** (free limit is 1).

Product IDs in this binary:

- `com.scubasteve1999.DayCast.pro.monthly` — DayCast Pro Monthly
- `com.scubasteve1999.DayCast.pro.yearly` — DayCast Pro Yearly

Pro unlocks: AI chat, Today's Take, Explain Radar, Morning AI Brief, Storm Spotter photo analysis,
forecast radar (FUTURE), Live Activity (updates when the app refreshes weather), unlimited saved
locations, and richer widgets.

Paywall includes **Privacy Policy** and **Terms of Use (EULA)** links and **Restore Purchases**.

## What the AI features send, and where

AI requests go to our proxy server, which forwards them to xAI (`api.x.ai`). Each request carries:

- The current weather context as text (location name, temperature, conditions, alerts).
- For **Storm Spotter** only: the photo the user explicitly selects, resized and sent as image data.
- An Apple-signed StoreKit transaction, used solely to verify an active subscription and apply
  per-subscriber rate limits.

No account, email, contact data, or advertising identifier is sent. The user's photo library is
accessed only when they pick a photo for Storm Spotter analysis.

AI usage has a daily allowance per subscription (resets at midnight UTC) to prevent abuse. It is
far above normal use and review will not reach it.

## Subscriptions (3.1.2)

The DayCast Pro paywall (Settings → DayCast Pro → View DayCast Pro) shows the subscription
title, length, price per plan, and functional Privacy Policy / Terms of Use (EULA) links at
the bottom of the purchase sheet, per guideline 3.1.2(c).

- Privacy: https://scubasteve1999.github.io/GrokCast/privacy.html
- Terms: https://scubasteve1999.github.io/GrokCast/terms.html
- Support: https://scubasteve1999.github.io/GrokCast/support.html

## Location / background

When In Use + optional Significant Location Changes only; no `location` background mode.

**Contact:** stephenmoorecm1357@gmail.com
