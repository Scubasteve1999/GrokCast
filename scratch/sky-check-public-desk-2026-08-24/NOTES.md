# Sky Check public desk — 2026-08-24

**Repo:** `/Users/bigstevedev/Projects/GrokCast`  
**Base:** `d01c93a` (radar paint floor) + `4a821ff` (wet probe); marketing **1.0.7 (143)**  
**Commit:** `fix(grok): public Sky Check desk — fewer doors, no invented radar`  
**Slice:** `scratch/sky-check-ai-polish-2026-08-23/MVP-AGREEMENT.md` first implement slice only.

## What shipped

1. **Public desk copy.** CTA is **Check this sky** (chip too). Empty pitch is civilian sky-photo language. Notes sheet is optional notes — no wall-cloud / Observer coaching. `buildWeatherSystemPrompt` uses `GrokPrompts.skyCheckChatSystemPrompt` (public desk, no field-first / SRV / chase). Quick prompts: Threat check, Outside now?, Outlook. Hedge unchanged.
2. **Radar read gone.** Compact + regular chips. Explain Radar is untouched and remains the only radar AI. No invented frame on Sky Check.
3. **Imagine off this tab.** No “Imagine the scene” chip; no sparkles generate beside the Sky Check input. Today Now **Imagine today** left alone.
4. **One Ask landing.** Take action / morning `OPEN_GROK` / Take figma tap → `SkyCheckLanding.openReadyToType` (tab `.grok` + queued focus). Public action title is **Sky Check**, not Ask AI / Ask Grok. Siri `AskGrokIntent` type name unchanged.
5. **More unlocked subtitle.** “Photo check and weather questions”.
6. **After-success card.** Compact card keeps last-check text + tertiary hedge + **Check another**. Does not snap back to the empty pitch.
7. **Dead witty `QuickPrompt` enum deleted** (WeatherModels). Preview no longer binds “What should I wear?”.
8. **AI Insight wrapper dropped.** `AIInsightFeedCard` is just `GrokBriefCard` (TODAY'S TAKE).

## Stills (iPhone 16, `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`)

| File | What |
|------|------|
| `01-more-hub-sky-check.jpg` | More → Sky Check row; subtitle “Photo check and weather questions” |
| `02-sky-check-empty.jpg` | Empty desk: Check this sky, hedge, Threat check / Outside now? / Outlook, no Radar read, no Imagine |

Success card: PHPicker is out-of-process; sim a11y could not complete a library photo. Last-check + Check another is covered by `SkyCheckDeskCopy` + compact card branch (`stormAnalysisText` after `stormAnalysisMode` clears).

## Tests

`xcodebuild` DayCastTests on iPhone 16 `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`: **497 passed**.

`StormSpotterHonestyTests` extended: public CTA verb, no SRV / Radar read in Sky Check prompts, chat prompt not field-first, More subtitle, Take/`OPEN_GROK` landing title + `.grok` tab, share “Notes:” not Observer. `GrokAccessRulesTests` subtitle. UITest CTA “Check this sky”.

## Confirm

- Radar read: gone from Sky Check chips (compact + regular).
- Imagine: off Sky Check; Today Now Imagine today unchanged.
- CTA: sky/photo verb (“Check this sky”).
- Explain Radar: no radar files in this diff; sheet title still “Explain Radar”.

## Out of this slice (unchanged)

Radar paint / wet probe, version bump, push, TestFlight, 4.7 filter, refund, camera capture, persist thumbs, Imagine on Today, RadarExplainContext on Sky Check, internal `StormSpotter*` / `daycast://grok` / `Tab.grok` renames, fifth tab, CARROT, AccuWeather buffet.
