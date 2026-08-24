# Denser Your News — implement notes (2026-08-23)

**Baseline:** `e234b7d` (`fix(today): Hourly chips show precip % and amount`). Build stays **141**. No bump, no push, no TestFlight.

**Plan:** `scratch/alerts-local-news-2026-08-23/dense/PLAN.md`

## What landed

Data-only. Photo rail UI untouched.

`LocalBriefingParser.assemble` emits up to 3 KEY MESSAGE bullets as cards with ids `afd-{productId}-km{index}` (0-based in parse order, not compacted after skip). Remaining slots fill from filtered PNS (`pns-{productId}`). Exact-title dedupe via `seenTitles` after `collapseWhitespace`. Missing KEY MESSAGES still yields no AFD card (DISCUSSION is never a card). Freshness windows unchanged (AFD 18h / PNS 48h). `maxCards` stays 3.

All AFD cards share issuedAt, sourceName, officeID, and the AFD Safari product URL.

Hero uniqueness unchanged: two thunderstorm KEY MESSAGES walk unused stills (`NewsHeroStorm` then `NewsHeroLightning`).

## Live MEG (Olive Branch, iPhone 16 `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`)

AFDMEG `d7681823-d4be-4d15-93b2-e5d65d79dd0a` issued 2026-08-23T23:34Z. Three KEY MESSAGES (office added a third since the MEG fixture’s two):

1. Shower and thunderstorm chances increase late tonight into Monday, with organized severe weather not expected.
2. Additional chances for showers and thunderstorms are expected through midweek.
3. Near to slightly above normal temperatures are expected across the Mid-South for most of the week, but extreme heat is not expected.

Newest MEG PNS still ~2026-08-21T15:19Z (>48h) — dropped. Rail is **3 AFD cards**, no PNS. Peek of card 2 is visible on iPhone 16. Meta on card 1: `2h ago · NWS Memphis`. Heroes: storm then lightning.

Honesty chrome unchanged (Severe Outlook, No active NWS alerts, no ACTIVE NOW, no storm reports).

## Shot

`scratch/alerts-local-news-2026-08-23/dense/alerts-your-news-dense.png` — Olive Branch / MEG rail after scroll (Your News + first KEY MESSAGE + second photo peek).

Do not treat `implement/alerts-briefing.png` as current.

## Tests

iPhone 16 `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`: **473** `DayCastTests` passed, 0 failed (parser density / dedupe / cap cases + existing honesty / storm-reports / hero table).

## Out of scope (still)

UI redesign, freshness-window changes, `AlertsHonesty`, Hourly, version / push / TestFlight, HWO/NOW/SPS, TV/RSS, DISCUSSION fallback.
