# Sky Check busy-lock — 2026-08-24

**Repo:** `/Users/bigstevedev/Projects/GrokCast`  
**Base:** `aa07ee2` user-bubble contrast, 3 local commits ahead of origin **1.0.7 (144)** — not bumped  
**Commit:** `9a07af7` `fix(grok): Sky Check busy-lock (one generation)`  
**Slice:** lock only. No queue. No radar / camera hop / persist thumbs / chips / well pill / user-bubble / chat grounding / version / push / TF.

Parked item from `scratch/sky-check-ai-polish-2026-08-23/MVP-AGREEMENT.md`: “Busy-lock queue across shared VM”. This is the lock.

## The hole

`askGrok` already `guard !isStreaming && !isGeneratingImage`. `analyzeStormPhoto` did not — it `generationTask?.cancel()` and started a new `streamStormPhoto`, dual-writing `responseText` + `stormAnalysisText`. A second Check this sky / notes **Check** cancelled the live xAI call or raced the shared VM. UI `aiActionsDisabled` is not a lock; notes confirm can fire two `Task`s in one runloop.

## What shipped

Same two flags as `askGrok`. Second `analyzeStormPhoto` returns without cancel, without a new vision stream, without overwriting `lastStormImageData` / in-flight text.

| Second tap while… | Behavior |
|---|---|
| Live `generationTask` | Silent no-op (no Retry footgun on a stream that will succeed) |
| Flags set, no live task | Honest one-liner |

- Already checking: `Already checking this sky. Try when this one finishes.`
- Already answering: `Already answering. Try when this one finishes.`

Notes **Check** is disabled while streaming / generating. VM remains the lock. No pending-photo buffer.

`SkyCheckDeskCopy.photoCTA` stays **Check this sky**.

## Tests

iPhone 16 `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`, iOS 26.5.

`xcodebuild` DayCastTests: **527** passed (5 new `SkyCheckBusyLockTests`). Second photo while streaming / chat / Imagine is a no-op or honest fail (`lastStormImageData` stays nil — no `streamStormPhoto`). `askGrok` still silent-refuses while streaming. Honesty `testPublicCTAIsASkyPhotoVerb` passed — CTA still “Check this sky”.

## Confirm

Photo no longer cancel-restarts a live stream.

## Out of this slice

Queue, dual-write hardening, radar, camera hop, persist thumbs, contrast, composer, 4.7, refund, Imagine on Today, fifth tab, copy rewrite, version bump, push, TF.
