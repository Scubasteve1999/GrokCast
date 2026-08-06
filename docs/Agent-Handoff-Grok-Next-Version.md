# Handoff to Grok agent — next version after 1.0.6

Written 2026-08-06, while 1.0.6 is in App Store review. Modeled on
`docs/Agent-Handoff-Claude-Cursor.md`'s handoff format. **Deliverable of this pass is
this document, saved to `docs/Agent-Handoff-Grok-Next-Version.md`** — no code changes.

## The one thing you must know before touching this

`docs/THINKING-PASS-2026-08.md` (2026-08-02) ends with an explicit gate:

> Do not run another [strategy] pass until at least one of these is true: (1) 30 days
> of post-reposition App Store Search data, (2) 10+ subscribers, (3) the reposition
> demonstrably fails.

**None of these are true yet.** 1.0.6 — which carries the spotter-niche reposition
(new subtitle/keywords/description) — is still in review as of this writing. The
30-day clock has not started. Do not scope or start the big candidate feature below
(Spotter Network / mPING) until a gate trips. This handoff exists so the next agent
picks up the right work immediately when it does, instead of re-deriving strategy.

## State of the repo right now

- `main` is clean, 1.0.6 submitted, awaiting Apple review.
- AI cost gate is live: metered Cloudflare Worker proxy, per-subscriber + global daily
  caps, kill switch (shipped 1.0.5).
- Instrumentation shipped with 1.0.6: `share_completed`, `ai_request` (per feature),
  `ai_limit_reached`, `first_open`.
- Acquisition baseline captured pre-reposition in `docs/baseline-2026-08-01.md`:
  113 impressions / 27 page views / 5 downloads / 2 ratings over 8 live days. That's
  the number the reposition has to beat.

## First task on pickup: re-capture acquisition data

The moment 1.0.6 clears review and goes live:

1. Note the live date by hand (Apple's Analytics date filters won't mark the metadata
   change).
2. Re-run the same two App Store Connect Analytics views documented in
   `docs/baseline-2026-08-01.md` (Acquisition → Overview, Acquisition → Sources,
   Product Page Views by Unique Devices).
3. Watch **App Store Search impressions** specifically — that's the one metric the
   keyword/subtitle change acts on. Browse and Referrer aren't moved by this reposition.
4. Give it 30 days before drawing conclusions. A week of data at this volume is noise.

## Safe to build now, regardless of gate status

Small polish items already scoped in `docs/ROADMAP.md`, Phase 3/4 remainder. None of
these touch AI cost, paywall, or entitlements — the two things the thinking-pass doc
flagged as the actual risk:

- Push notification: rain-starting-soon, sourced from existing Minutecast data
- Live Activity variants for severe alert / radar event (reuses existing Live Activity
  infra)
- "Ask Grok" App Intent (opens chat with context), reuses existing Grok chat surface
- Radar glass HUD + glowing playhead (visual polish on existing radar view)
- Tab IA simplification (Home / Map / You) — marked optional in ROADMAP; skip if not cheap

Fine to pick these up between now and whichever gate trips first.

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
