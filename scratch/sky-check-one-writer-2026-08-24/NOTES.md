# Sky Check one writer per stream — 2026-08-24

**Repo:** `/Users/bigstevedev/Projects/GrokCast`  
**Base:** `c5193c4` 4.7 screen, 5 local commits ahead of origin **1.0.7 (144)** — not bumped  
**Commit:** `fix(grok): Sky Check one writer per stream`  
**Slice:** state-model only. Photo tokens never land in the chat buffer. No radar / camera hop / persist thumbs / contrast / busy-lock / 4.7 rewrite / version / push / TF.

Parked item from `scratch/sky-check-ai-polish-2026-08-23/MVP-AGREEMENT.md`: “dual-write `responseText` footgun”.

## The hole

`analyzeStormPhoto` did `stormAnalysisText += token` **and** `responseText += token`. Compact stream UI already reads `stormAnalysisMode ? stormAnalysisText : responseText`. After a photo, `commitFinishedSkyCheckReply(..., asPhotoTurn: true)` copied the screened body into `responseText` again. Chat start cleared it; share / 4.7 hide / empty-fail / any later reader of `responseText` could treat the photo body as chat.

## What shipped

One writer per job. `GrokAIViewModel.appendSkyCheckStreamToken` is the only stream append.

| Job | Writer | Other buffer |
|---|---|---|
| Photo stream / allowed photo commit | `stormAnalysisText` | `responseText` stays empty |
| Chat stream / allowed chat commit | `responseText` | `stormAnalysisText` does not grow |

- Photo start still blanks `responseText`.
- Allowed photo commit sets `responseText = ""` (no copy of `accepted`).
- Photo hide still clears both (4.7 unchanged).
- Photo empty-fail blanks `responseText` before the existing empty-response error.

`streamingResponse` still picks the right live buffer. No third buffer. 4.7 `commitFinishedSkyCheckReply` is still the screen.

`SkyCheckDeskCopy.photoCTA` stays **Check this sky**.

## Tests

iPhone 16 `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`, iOS 26.5.

`xcodebuild` DayCastTests: **543** passed (4 new `SkyCheckStreamWriterTests`). Photo stream does not grow `responseText`; chat stream does not grow `stormAnalysisText`; allowed photo commit leaves `responseText` empty. `SkyCheckReplyCommitTests.testAllowedVisionStillPersists` now asserts the chat buffer stays empty after an allowed photo. Honesty CTA still “Check this sky”. Busy-lock and 4.7 suites still pass.

First full run had a one-off `BriefingThreadTests.testPhotoThumbRoundTripsForTheSameCityOnly` user/assistant swap (equal-timestamp SwiftData sort). Isolation + full rerun passed; persist thumbs was not changed.

## Confirm

Photo tokens never land in `responseText`.

## Out of this slice

Refund, Imagine on Today, queue, radar, camera hop, persist thumbs, contrast, busy-lock, 4.7 rewrite, fifth tab, version bump, push, TF.
