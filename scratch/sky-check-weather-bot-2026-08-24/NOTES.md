# Sky Check weather bot — 2026-08-24

**Repo:** `/Users/bigstevedev/Projects/GrokCast`  
**Base:** `0bc8520` (photo well) on `c3dba88`; marketing **1.0.7 (143)**  
**Commit:** `fix(grok): Sky Check is the weather bot (grounded chat)`  
**Slice:** chat is the desk, grounded like vision. No radar paint / bump / push / TF.

## What shipped

1. **Grounded chat.** `GrokAIViewModel.buildWeatherSystemPrompt` now calls `GrokPrompts.skyCheckChatSystemPrompt(weather:…)` and reuses existing builders:
   - current conditions
   - next ~12–24 hourly (`hourlyOutlookBlock` — temp, precip %, amount ≥0.1")
   - NWS nearest observation (`nwsObservationBlock`, shared with vision)
   - HRRR when `hasHRRRSlots` + `isUsableHRRR()` for this city (`shortTermPrecipBlock`)
   - compact NWS alert titles + `severeContextBlock`
   - AFD/PNS key messages from `LocalBriefingStore` when the pack is for this city (`localBriefingBlock` — quoted as issued, no Grok rewrite)
   Identity: use only the data; cite NWS / HRRR / AFD; do not invent radar, warnings, or numbers.

2. **Chat is the desk.** Compact + regular: `conversationHistory` is the main surface. Empty copy is weather-questions first. Photo well / **Check this sky** is a secondary tool. After a text ask, the empty photo pitch is gone; answer stays in the thread; **Check this sky** remains a compact CTA. 3 chips (Threat check / Outside now? / Outlook) still send into `askGrok`. Input stays in the bottom inset (`Ask about the weather…`).

3. **Copy.** More subtitle: “Ask about your weather. Photo check when you want.” Empty pitch: “Ask about your weather. Check a sky photo when you want eyes on the sky.” Hedge unchanged. No Ask AI / Ask Grok noun.

4. **Imagine stays off this tab.** `askGrok` no longer routes to image generation. `isImageGenerationRequest` returns false for “picture of the sky” / photo analysis / the three chips. Today **Imagine today** untouched.

## Stills (iPhone 16, `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`, iOS 26.5)

| File | What |
|------|------|
| `01-more-hub-sky-check.jpg` | More → Sky Check; subtitle weather-first |
| `02-sky-check-empty.jpg` | Empty desk: questions first, hedge, 3 chips, photo well, composer in a11y (`daycast.grok.chatField`) |
| `03-sky-check-answered.jpg` | Threat check → thread answer citing Day 1 / NWS Memphis AFD / HRRR; empty pitch gone; **Check this sky** secondary |

Live Threat check reply (Olive Branch): no watches/warnings in the block; Day 1 thunderstorms; AFD shower/t-storm chances; HRRR dry for ≥2h. Did not invent radar.

## Tests

`xcodebuild` DayCastTests on iPhone 16 `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`: **500 passed**.

`StormSpotterHonestyTests`: chat prompt includes hourly + KMEM obs + HRRR + AFD when fixtures provide them; omits those blocks when missing; no N0B / Site Doppler / MRMS invention language; chips are not image-gen; photo CTA still “Check this sky”.

## Confirm

- Chat system prompt contains hourly / HRRR / AFD / obs when data exists (unit + live sim).
- Radar read: still gone from Sky Check. Explain Radar untouched.
- Imagine: off Sky Check `askGrok`; Today Imagine today unchanged.
- Version: still **1.0.7 (143)**. No push, no TestFlight.

## Out of this slice

Radar paint / wet probe, version bump, push, TestFlight, camera capture, persist thumbs, 4.7 filter, refund, RadarExplainContext / live frames, fifth tab, Ask Grok brand, CARROT, killing Today's Take or Imagine today.
