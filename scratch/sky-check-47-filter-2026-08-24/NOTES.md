# Sky Check 4.7 screen — 2026-08-24

**Repo:** `/Users/bigstevedev/Projects/GrokCast`  
**Base:** `3d168af` busy-lock, 4 local commits ahead of origin **1.0.7 (144)** — not bumped  
**Commit:** `fix(grok): Sky Check 4.7 screen on chat and vision`  
**Slice:** screen finished chat + vision. Honest hide. No Take fallback. No radar / bump / push / TF.

Parked item from `scratch/sky-check-ai-polish-2026-08-23/MVP-AGREEMENT.md`: “4.7 content filter on vision / studio chat”.

## The hole

`GrokContentFilter` already screens Today's Take, Explain Radar, and Alerts summary. `askGrok` and `analyzeStormPhoto` streamed into `responseText` / `stormAnalysisText` and persisted `ChatMessage.assistant(...)` raw. Blocked categories could sit in the Sky Check thread and SwiftData. Compact last-check / share read `stormAnalysisText`, so a blocked vision body could linger on the desk.

## What shipped

Reuse `GrokContentFilter`. After a finished stream, `GrokAIViewModel.commitFinishedSkyCheckReply` screens then commits.

| Finished body | Chat | Vision |
|---|---|---|
| Allowed | Persist assistant. Keep `responseText`. | Persist user thumb + analysis. Keep `stormAnalysisText`. |
| Empty / whitespace | Existing empty error. No assistant. | Existing empty error. No photo turn. |
| Category block or Sky Check `.tooLong` | Hide one-liner as assistant. Clear `responseText`. | Persist user + thumb. Hide one-liner (`isStormSpotterAnalysis == false`). Clear live buffers **before** `stormAnalysisMode = false`. |

Hide copy: `Couldn't show that reply. Try another question.` Not `GrokErrorView`, not `LocalWeatherBrief`.

Length: Take stays **1,600**. Sky Check is **12,000** (`skyCheckMaxCharacterCount`). Empty still blocks. Do not silent-truncate.

Streaming: final body only. Tokens unfiltered.

`SkyCheckDeskCopy.photoCTA` stays **Check this sky**.

## Tests

iPhone 16 `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`, iOS 26.5.

iPhone 16 `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`, iOS 26.5.

`xcodebuild` DayCastTests: **539** passed (12 new: `SkyCheckContentFilterTests` + `SkyCheckReplyCommitTests`). Blocked phrase does not stay in `conversationHistory` or live buffers; allowed weather persists; Take 1,600 still `.tooLong` on default `screen`; Sky Check allows ~2k weather; CTA still “Check this sky”. In-memory `GrokAIConversationStore` so tests do not write the on-disk thread.

## Confirm

Blocked chat/vision never persist. `persistCurrentHistory` snapshots `conversationHistory` after the screen.

## Out of this slice

Refund, Imagine on Today, queue, radar, camera hop, persist-thumb policy, contrast, chat grounding, version bump, push, TF.
