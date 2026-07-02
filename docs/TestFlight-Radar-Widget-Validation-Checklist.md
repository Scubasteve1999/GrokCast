# TestFlight External Tester Validation – Radar + Widget Checklist

Thanks for helping test GrokCast! This short checklist (10–15 minutes) focuses on the most important recent Radar updates (Future Cast, smooth animation, switching modes, offline/cached behavior, MapKit implementation) and the polished widget (with Today hero temp no-clip, DesignTokens cards).

Please test on your **iPhone** and **iPad** if you have both. Use Airplane Mode for offline tests.

Report any problems clearly so we can fix them quickly.

## Quick Setup
1. Install the latest TestFlight build.
2. Open the app and allow location access (important for Radar and widgets).
3. Tap the **Radar** tab.
4. Check Today tab for hero (large temp + icon, no truncation on narrow screens, polished cards).

## Radar Tests

### 1. NOW Mode Playback (Most Important)
- Make sure you're in **NOW** (left side of the segmented control).
- Tap the **play** button (circle arrow).
- Watch the radar image for 20–30 seconds.
- Tap **pause**.

**What to check:**
- Does the radar animate smoothly (rain moving across the map)?
- Does the time label and progress update?
- Does pause stop it cleanly?

**Report:** Animation worked / didn't start / was jerky / etc. Device model.

### 2. FUTURE Mode Playback
- Switch to **FUTURE** (right side of segmented control).
- Tap play.

**What to check:**
- Does it show future rain forecasts?
- Is the animation smooth like NOW mode?
- Labels show times ahead (e.g. +15m, +30m)?

**Report any differences from NOW mode.**

### 3. Switch Modes While Playing
- Start playing in **NOW**.
- While it's animating, switch to **FUTURE**.
- Switch back to **NOW** while still playing.

**What to check:**
- Does animation keep going or restart nicely?
- Any freezing, jumping, or blank screen?
- Does the CACHED pill appear or disappear?

**This tests the recent animation restart fixes.**

### 4. Scrubbing the Timeline
- Play or pause the radar.
- Drag the slider left and right slowly and quickly.
- Release the slider.

**What to check:**
- Does the radar image update instantly to the time you drag to?
- When you release, does playback resume (if it was playing before)?

**Test on both iPhone and iPad.**

### 5. Cached / Offline Mode (Very Important)
- Turn on **Airplane Mode** (or turn off Wi-Fi + Cellular).
- Go back to the Radar tab.
- Try playing in NOW and FUTURE.
- Look for the small **CACHED** pill near the top.

**What to check:**
- Does the "CACHED" indicator appear?
- Can you still play and scrub using the last saved radar data?
- Does it look usable (no big errors or missing images)?
- Turn network back on — does fresh data load and "CACHED" go away?

**Test switching modes while offline.**

## Radar Status Note
- Radar uses stable MapKit path with full animation/scrub/cache from RadarState unification.
- Today hero temperature (42pt icon, truncation fixed via priority + scale factor, DesignTokens + elevatedCardStyle consistency across cards).
- Central DesignTokens for elevated shadows and card styling (matches Forecast/Alerts polish).

## Widget Tests
1. Add the GrokCast widget to your home screen (try Small and Medium sizes).
2. Check it shows weather for your current or saved location.
3. Look at it for 1–2 minutes.

**What to check:**
- Does it display temperature, condition icon, and location name clearly?
- Any layout issues, cut-off text, or weird colors on iPhone vs iPad?
- If there's an alert, does the warning icon show?
- Tap the widget — does it open the app to the right screen?
- Does it look polished and consistent with the app?

## How to Report Issues
For anything that doesn't work, reply with:

**Test #:** (e.g. 3)
**Device:** iPhone 14 Pro / iPad Air 5
**What happened:** Animation froze when I switched from NOW to FUTURE while playing.
**Steps to reproduce:** 1. Start playing in NOW 2. Switch to FUTURE
**Screenshots or video:** (attach if possible)

Thank you! Your feedback on these specific areas will help us get Radar and the widget solid for everyone.