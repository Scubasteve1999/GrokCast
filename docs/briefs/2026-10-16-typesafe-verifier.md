# TypeSafe Grok output verifier — experiments and design

**Date:** 2026-10-16 · **Status:** implemented, not deployed. Privacy copy pending Stephen's review.

## Why

No Grok call in DayCast returns a structured decision. Every check on Grok output is a keyword list, and two of them are broken in ways that matter:

1. **Explain Radar's hallucination guard never runs.** `RadarExplainCopy.inventsPrecipitationAtPin` returns `false` unless PoP < 20%. Below 20%, though, `fetchRadarExplanation` returns local copy without calling Grok. So Grok's radar text is never checked against the pin.
2. **The harmful-advice filter blocks safety advice.** `GrokContentFilter.containsAnyPhrase` is a substring match. "Please don't ignore the warning" contains `ignore the warning` and gets blocked. Paraphrased bad advice ("tornado warnings here are overblown, no need to head to the basement") passes.

## Experiments (Jev via TypeSafe `/v1/systemone`)

The cases are hand-written synthetic weather text, labeled by intended app behavior. The first round leans adversarial: negation, figurative verbs, paraphrase. The held-out round used realistic 3–5 sentence Grok-style replies, written *after* the questions were frozen.

| Check | Keyword heuristic | jev-1.13 | jev-1.14 |
|---|---|---|---|
| Radar grounding (20 cases) | 8/20 | 20/20 | 20/20 |
| Radar grounding, held-out (8) | 4/8 | 8/8 | 8/8 |
| Harmful advice (16) | 7/16 | 16/16 | 16/16 |
| Harmful advice, held-out (8) | 3/8 | 6/8 at 0.5 (two at exactly 0.50) | 8/8 |
| Image-intent routing (30; not shipped) | 16/30 | 29/30 | 29/30 |

- **Latency:** p50 ~190–220 ms per request, p90 ~260 ms.
- **Size:** ~480–520 input tokens per check, about $0.00002 at $0.042/Mtok. Output tokens are free.
- **Order sensitivity:** reversing the Choice option order flipped one borderline routing case on 1.13 and none on 1.14.

**Caveats.** These are small, self-written sets. They show *which kinds* of cases the keyword lists fail on, not production error rates. Re-measure if the question wording, the state shape, or the model changes.

## Design

- **Worker** (`server/grok-proxy/src/verify.js`, route `POST /v1/verify`):
  - **Gating:** Pro-only, same shared secret plus StoreKit JWS check as chat.
  - **Metering:** its own `verify` ledger bucket (`DAILY_VERIFY_LIMIT`, default 300), exempt from the global AI cap.
  - **Kill switch:** `VERIFY_DISABLED`.
  - **Model:** pinned to `jev-1.14.0` (override with `TYPESAFE_MODEL`). Never `jev-latest`, because an alias move shifts calibrated thresholds.
  - **Policy:** the thresholds live here (harmful ≥ 0.30 blocks; unsupported precipitation ≥ 0.50 blocks), so a change doesn't need an App Store release.
  - **Numbers stay in code:** the pin's PoP is bucketed into words (none / slight chance / chance / likely) before Jev sees it.
- **App** (`GrokOutputVerifier`): called after the existing keyword screen passes, on:
  - Explain Radar (radar subject when the pin forecast is loaded)
  - Today's Take and the morning brief (`GrokBriefGenerator`)
  - the alerts plain-English summary

  A `block` swaps in the existing local copy. **Additive, like NWS:** the developer-key tier, timeouts (5 s), and any non-200 return `.unavailable` and change nothing. The verifier never un-blocks keyword-filtered text, and it never spends the Grok chat allowance.

## Not done (deliberately)

- **Sky Check chat** streams to the screen, so a post-hoc verdict would retract visible text. That needs a UX decision first.
- **Un-blocking false positives** (e.g. "don't ignore the warning") needs an explicit policy call, because it loosens a safety filter.
- **Image-intent routing** (29/30 vs 16/30) adds ~200 ms before every chat message. It's a separate proposal.
- **Privacy policy / App Privacy:** TypeSafe is a new processor of AI output text. `docs/privacy.html` (third parties, lines ~39–41) needs copy, held for review. Must ship before `TYPESAFE_API_KEY` is set in production.

## Deploy

```bash
cd server/grok-proxy && npm test
wrangler secret put TYPESAFE_API_KEY   # only after the privacy copy ships
wrangler deploy
```

Watch `wrangler tail` for `verify block …` lines to see block rates. The lines contain verdicts and reasons only, never text.
