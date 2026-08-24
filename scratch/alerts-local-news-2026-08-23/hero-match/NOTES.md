# Your News photo only when it matches the headline (2026-08-23)

**Baseline:** `76a1b28` (`feat(alerts): denser Your News from AFD KEY MESSAGES`). Build stays **141**. No bump, no push, no TestFlight.

**Ask:** “the images need to match the headlines. pull images from that headline or dont show one.”

## Bug

`LocalBriefingHero.matching` always returned a still (unmatched → `.sky`). `uniqueHeroes` then walked unused crops when the preferred one was already on the rail, so a temperature KEY MESSAGE could inherit storm / lightning / flood.

## What landed (UI / picker only)

Assemble / denser KEY MESSAGE logic / freshness / `AlertsHonesty` untouched. Existing `NewsHero*` JPEGs stay; matching rules change.

- `matching(title:)` → `LocalBriefingHero?`. Strict imagery cues only:
  - lightning → `.lightning`
  - flood / inundat → `.flood`
  - wildfire / smoke / haze / fire weather → `.haze`
  - storm / severe / hail / tornado / thunderstorm / tstm → `.storm`
  - clear / sunny / fair / dry / pleasant / high pressure → `.dawn`
  - else **nil** (no default `.sky`; `watch` / `warning` / `wind` alone are not enough)
- `uniqueHeroes` returns `[LocalBriefingHero?]`. Nil stays nil. If the preferred still is taken, the only alternate is storm↔lightning when the title still contains storm / thunder / tstm. Otherwise duplicate the honest still, or nothing. Never walk unused flood / haze / dawn / sky onto a different headline.
- `YourNewsCard.hero` is optional. Nil omits the 16:9 entirely (headline + meta, tap still opens Safari). No gray hole, no SF Symbol placeholder. Rail `HStack` is top-aligned so a text-only card does not float in the photo well.

## Live MEG (Olive Branch, iPhone 16 `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`)

AFDMEG issued 2026-08-23T23:34Z. Three KEY MESSAGES, no fresh PNS (newest still >48h):

| # | Headline | Photo |
|---|---|---|
| 1 | Shower and thunderstorm chances increase late tonight into Monday, with organized severe weather not expected. | `NewsHeroStorm` |
| 2 | Additional chances for showers and thunderstorms are expected through midweek. | `NewsHeroLightning` (honest storm-family alternate) |
| 3 | Near to slightly above normal temperatures are expected across the Mid-South for most of the week, but extreme heat is not expected. | **none** (text-only card) |

Honesty chrome unchanged (Severe Outlook, No active NWS alerts, no ACTIVE NOW, no storm reports).

## Shots

- `alerts-your-news-photos.png` — rest position: card 1 storm still + card 2 lightning peek.
- `alerts-your-news-hero-match.png` — rail scrolled: card 2 lightning peek + card 3 **text-only** temperature KEY MESSAGE (no 16:9, no placeholder).

Do not treat `implement/alerts-briefing.png` as current.

## Tests

iPhone 16 `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`: **478** `DayCastTests` passed, 0 failed (unmatched temp → nil; two thunderstorms → storm + lightning, never flood; uniqueness must not lie; third thunderstorm duplicates storm rather than flood; live MEG trio → storm / lightning / nil).

## Out of scope (still)

TV / NewsAPI / remote images, Imagine still regeneration, assemble / freshness / `AlertsHonesty`, version bump, push, TestFlight.
