# App Store Review Notes (draft)

Copy into **App Store Connect → App Review Information → Notes** when you submit.
Kept in sync with `fastlane/metadata/review_information/notes.txt`.

---

DayCast uses Open-Meteo, NWS alerts/observations, Mapbox radar, and xAI Grok for briefings, Explain Radar, and Sky Check photo analysis.

NO ACCOUNT
No sign-in. Location is optional (defaults to Olive Branch, MS). Weather, radar, forecasts, and NWS alerts in the app are free.

AI — PLEASE READ
AI requires DayCast Pro (Monthly or Yearly). The old embedded xAI key is gone. Calls go through our proxy for verified subscribers only.

Sandbox purchases are free. To review AI:
1. Settings > DayCast Pro > View DayCast Pro
2. Choose Monthly and complete the sandbox purchase
3. More > Sky Check — send a short prompt; it should stream a reply

Monthly unlocks AI, Today's Take, Explain Radar, Sky Check, and extra saved locations.
Yearly is required for Future radar (Radar tab), Home Screen / Lock Screen widgets, and Live Activity. Monthly will not unlock those.

Sandbox and Production StoreKit both work. Restore Purchases if AI still says Pro is required.

Alternative: Settings accepts your own xAI key (starts with xai-, from console.x.ai). That unlocks AI without a subscription.

SUGGESTED PATH
1. Allow location or keep the default
2. Today — now, official NWS chip when warned, temperature curve, Outlook on live radar, Your News
3. Radar — Site Doppler on Dark; National when local is clear
4. Alerts — live NWS watches and warnings
5. More > Sky Check after Monthly sandbox purchase
6. Settings > Privacy & support — Privacy Policy and Terms

SUBSCRIPTIONS
Paywall: Settings > DayCast Pro > View DayCast Pro. Also from an AI tap, Live Activity (Yearly), Morning brief, or saving a second location (free limit is 1).

IDs:
- com.scubasteve1999.DayCast.pro.monthly — AI + unlimited locations
- com.scubasteve1999.DayCast.pro.yearly — Monthly plus Future radar, widgets, Live Activity (updates when the app refreshes)

Paywall has Privacy Policy, Terms of Use (EULA), and Restore Purchases.

AI DATA
Requests go to our proxy, then xAI (api.x.ai). Payload is weather context as text; Sky Check also sends the user-picked photo (resized); plus an Apple-signed StoreKit transaction for entitlement and rate limits. No account, email, contacts, or IDFA. Photo library only when the user picks a Sky Check photo. Daily AI cap resets midnight UTC; review will not hit it.

GUIDELINE 4.7
Today's Take is off the Today feed in this build. Screening still runs before cache, morning notification, and widget one-liner. Restore or turn the feature off from Settings > Today's Take. Sky Check replies are screened on-device; a blocked reply is replaced with a hide line, never raw Grok. Reports: stephenmoorecm1357@gmail.com (within 24 hours).

3.1.2
Paywall shows title, length, and price per plan, plus working links:
Privacy: https://scubasteve1999.github.io/GrokCast/privacy.html
Terms: https://scubasteve1999.github.io/GrokCast/terms.html
Support: https://scubasteve1999.github.io/GrokCast/support.html

LOCATION
When In Use for forecast. Optional Travel weather may prompt Always for Apple Significant Location Changes only. No location background mode.

Contact: stephenmoorecm1357@gmail.com
