# Handoff to Grok agent — next version after 1.0.6

Written 2026-08-06, while 1.0.6 is in App Store review. **Updated 2026-08-14: 1.0.6
(build 122) was approved and is live today** — see the state/first-task sections
below, both revised accordingly. Modeled on `docs/Agent-Handoff-Claude-Cursor.md`'s
handoff format.

## The one thing you must know before touching this

`docs/THINKING-PASS-2026-08.md` (2026-08-02) ends with an explicit gate:

> Do not run another [strategy] pass until at least one of these is true: (1) 30 days
> of post-reposition App Store Search data, (2) 10+ subscribers, (3) the reposition
> demonstrably fails.

**None of these are true yet, but the clock has now started.** 1.0.6 — which carries
the spotter-niche reposition (new subtitle/keywords/description) — was approved and
went live **2026-08-14** (build 122, after one 3.1.2(c) rejection for broken
privacy/terms links, fixed and resubmitted). Do not scope or start the big candidate
feature below (Spotter Network / mPING) until a gate trips — earliest possible trip
date is **2026-09-13** (30 days out), sooner if 10+ subscribers land first.

## State of the repo right now

- `main` is clean and pushed, 1.0.6 (build 122) approved and live as of 2026-08-14.
- Since the 2026-08-06 version of this handoff, these landed on `main` (all from the
  "safe to build now" list below, pre-approved):
  - Live Activity severe-alert / radar-event variants shipped (`WeatherLiveActivityManager`,
    `WeatherLiveActivityWidget`, `WeatherLiveActivityAttributes`) — the roadmap item is
    now checked off.
  - TestFlight detection fixed to use `AppTransaction.shared` instead of sniffing the
    sandbox receipt path (`GrokAPIConfiguration.swift`) — the old method was unreliable.
  - `grok-build` CLI trimmed from 676 to 148 lines: removed the `radar`,
    `integrate-nws-api`, and `integrate-weatherkit` commands, which were echo-only
    scaffolding from an old workflow (printed a flag description, then just ran
    `xcodegen generate` — never touched source). The six commands that do real work
    (`increment-build`, `regenerate`, `generate-icons`, `clean`, `archive`,
    `capture-aso`) are untouched.
  - App Store review screenshot assets added under `Marketing/AppStore/`.
- AI cost gate is live: metered Cloudflare Worker proxy, per-subscriber + global daily
  caps, kill switch (shipped 1.0.5).
- Instrumentation shipped with 1.0.6: `share_completed`, `ai_request` (per feature),
  `ai_limit_reached`, `first_open`.
- Acquisition baseline captured pre-reposition in `docs/baseline-2026-08-01.md`:
  113 impressions / 27 page views / 5 downloads / 2 ratings over 8 live days.
  That capture is for **dead listing `6780682022`**. Live listing is
  `6798461672`, launched 2026-08-14 as 1.0.6 — see
  `docs/baseline-2026-08-14.md`. Do not score the reposition against the old
  113. The number to beat on this record starts at ~0.

## First task on pickup: done, except optional Sources

Live-day marker is in [`docs/baseline-2026-08-14.md`](baseline-2026-08-14.md).
Overview captured 2026-08-14 (date pill **August 13**): every Acquisition
and Sales tile is **Not Enough Data**; subscription event tiles are dashes.
Sources was not screenshotted — skip until Overview impressions leave NED.

Watch **App Store Search impressions** once numbers appear. Gate is not
tripped. Earliest trip **2026-09-13**, or 10+ subscribers. Do not start
Spotter Network / mPING before then.

## Safe to build now, regardless of gate status

Small polish items already scoped in `docs/ROADMAP.md`, Phase 3/4 remainder. None of
these touch AI cost, paywall, or entitlements — the two things the thinking-pass doc
flagged as the actual risk:

- ~~Push notification: rain-starting-soon~~ — shipped (82d7cea).
- ~~Live Activity variants for severe alert / radar event~~ — shipped 2026-08-14
  (657b609).
- ~~"Ask Grok" App Intent (opens chat with context)~~ — shipped on `main` 2026-08-14
  (`AskGrokIntent` + `AskGrokPendingPrompt`; reuses `GrokAIViewModel.askGrok`).
- ~~Radar glass HUD + glowing playhead~~ — shipped on `main` 2026-08-14
  (`ChaseRadarHUD` / `RadarControlPanel` glass, figma scrubber playhead).
- Tab IA simplification (Home / Map / You) — marked optional in ROADMAP; skip if not cheap

Fine to pick the leftover item up between now and whichever gate trips first.
Only optional Tab IA remains on this list.

## Do NOT build yet: the gated candidate list, ranked

### 1. Spotter Network / mPING report submission — leading candidate, gated

The thinking-pass competitive analysis named this as the one concrete gap against
RadarScope: "it renders; it does not explain... but it owns the reporting loop we have
none of." DayCast already renders pro radar products (SRV, correlation coefficient,
composite reflectivity) and explains them via Grok — closing this gap would make it
the only app in the niche doing both render + explain + report.

**Why gated:** it's a real build — new networking integration, likely a new
permissions/consent flow, a new data-submission surface with its own App Store review
risk profile. Justified only by an audience the reposition hasn't yet been shown to
reach. Building it before the gate trips risks shipping a costly feature for users who
never found the app.

**Safe prep now (research only, do not implement):** confirm whether Spotter Network
and/or mPING expose a third-party submission API and what their integration/onboarding
terms require.

### 2. Grok-assisted report drafting

Once/if #1 exists: Grok drafts a plain-English report summary from the user's current
radar view + optional storm photo before submission. Purely additive on top of #1 —
don't scope independently of it.

### 3. Deeper NEXRAD/model product coverage

Lower priority — deepens an axis (pro radar rendering) where DayCast is already
differentiated, rather than closing the one gap that's actually missing. Only pull
this forward if post-reposition user feedback specifically asks for a missing product.

### 4. Consumer-facing AI feature expansion — explicitly rejected

`THINKING-PASS-2026-08.md` §7 rules this out directly: the consumer AI-weather market
is saturated (CARROT alone has 86k ratings), and every consumer user acquired there
costs xAI tokens for a feature they won't pay for. Listed here only so it's visibly
considered-and-rejected, not overlooked.

## What decides the branch when a gate trips

- **Gate 1 or 2 trips (reposition working):** green-light #1, Spotter Network/mPING.
  The business theory validated — build the differentiator.
- **Gate 3 trips (reposition fails, no search traffic after 30 days):** per the
  thinking-pass doc, the question changes from "which feature" to "is the spotter
  niche reachable through App Store search at all" — the answer might be community
  distribution (e.g. direct outreach to SKYWARN/spotter communities) rather than more
  product. Run a fresh thinking pass at that point; don't default to this list.

## Repo rules to respect (unchanged, see AGENTS.md / CLAUDE.md)

- Never commit secrets; AI key lives behind the metered proxy now, not embedded.
- Never touch entitlement/paywall/StoreKit logic without explicit approval.
- NWS stays strictly additive; never invent warnings via Grok.
- `xcodegen generate` after touching `project.yml` or adding/removing files.
- Small, reviewable diffs; no new dependencies without asking.

## On completion of this handoff

Save this file as `docs/Agent-Handoff-Grok-Next-Version.md` and link it from
`docs/ROADMAP.md`'s top section so it's discoverable alongside the existing roadmap.
