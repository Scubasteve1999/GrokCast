# App Store Connect prep (not submitted yet)

Use this when you are ready to upload metadata and screenshots. **Do not submit for review until TestFlight QA passes.**

## 1. TestFlight upload (when ready)

**Prerequisite:** In [Apple Developer → Identifiers](https://developer.apple.com/account/resources/identifiers/list), ensure App Groups `group.com.scubasteve1999.GrokCast` is enabled for **GrokCast** and **GrokCastWidgets** (iPhone app + widget extension only — **no Apple Watch target in this submission**). Then in Xcode, open **Signing & Capabilities** for each target and let Xcode refresh provisioning profiles.

```bash
./grok-build archive          # Release archive → build/GrokCast.xcarchive
./grok-build archive --increment   # bump build number first
```

If archive fails with App Group provisioning errors, fix capabilities in Developer portal (above) or archive from Xcode (**Product → Archive**) after signing resolves.

Then in Xcode:

1. **Window → Organizer** → select the archive
2. **Distribute App** → **App Store Connect** → **Upload**
3. Wait for processing in App Store Connect → **TestFlight**
4. Add internal testers; run `docs/TestFlight-Radar-Widget-Validation-Checklist.md` on 2+ physical devices

Optional CLI upload (after archive + export):

```bash
./Scripts/upload_testflight.sh   # requires App Store Connect API key or Apple ID session
```

## 2. Screenshot capture (6.7" Display)

Automated (simulator):

```bash
./Scripts/capture_aso_screenshots.sh
```

Output: `Marketing/AppStore/*.png` (1290×2796 target)

Manual (Xcode Previews):

1. Open `GrokCast/Features/Marketing/AppStoreScreenshotViews.swift`
2. Run previews **ASO — Today**, **ASO — Radar**, **ASO — Grok**
3. Capture at 3× scale (393×852 logical → ~1290×2796)

### Recommended set for v1.0.1

| # | Composition | File |
|---|-------------|------|
| 1 | Today — hero + score + Grok brief | `01-today.png` |
| 2 | Radar — FUTURE + HUD + Explain | `02-radar.png` |
| 3 | Grok — Briefing studio + Storm dossier | `03-grok.png` |

Optional 4th: real **Alerts** tab with Grok summary (device capture).

## 3. Metadata draft

**Name:** GrokCast

**Subtitle:** Weather with Grok intelligence

**Promotional text (170 chars):**

Dark, premium weather with Minutecast, GrokCast Score, live radar, NWS alerts, widgets, and Grok briefings — know when to go outside.

**Description (short):**

GrokCast combines accurate Open-Meteo forecasts and NWS alerts with a beautiful dark UI, Mapbox radar, Live Activities, and optional Grok AI briefings.

- Today: GrokCast Score, Minutecast, and Grok’s take
- Radar: live and forecast frames with Explain Radar
- Alerts: NWS warnings with plain-English Grok summaries
- Grok AI: chat, Imagine, Storm Spotter photo analysis
- Widgets & Live Activity: temp, score, and brief one-liner (iPhone)

**Keywords:** weather,forecast,radar,alerts,Grok,AI,Minutecast,widget

**Category:** Weather

**Privacy Policy URL:** https://scubasteve1999.github.io/GrokCast/privacy.html

**Terms of Use URL:** https://scubasteve1999.github.io/GrokCast/terms.html

**Support URL:** https://scubasteve1999.github.io/GrokCast/support.html

## 4. Submit checklist (later)

- [ ] GitHub Pages live (privacy + support)
- [ ] TestFlight build on 2+ devices
- [ ] Screenshots uploaded (6.7" required; add 6.5" if desired)
- [ ] App Review Notes pasted from `docs/App-Review-Notes.md`
- [ ] `./grok-build increment-build --tag` before final archive
- [ ] Submit for review (not tonight)
