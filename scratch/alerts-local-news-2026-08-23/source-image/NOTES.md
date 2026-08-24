# Your News photos only from source image URLs (2026-08-23)

**Baseline:** `d859f0c` (`fix(alerts): Your News photo only when it matches the headline`). Build stays **141**. No bump, no push, no TestFlight.

**Ask:** only show a photo when the NWS/source product includes a real image URL. Bundled `NewsHero*` keyword stock is not “from the source.”

## Reality check

`api.weather.gov` AFD/PNS product JSON has no media fields (text only). Live MEG AFD `d7681823-d4be-4d15-93b2-e5d65d79dd0a` issued `2026-08-23T23:34:00+00:00` — `productText` has **zero** `https://` URLs. Newest MEG PNS (`2026-08-21T15:19Z`, NWR Oxford back in service) is >48h and also has no image URLs. Olive Branch Your News is therefore **text-only cards**. That is correct and honest.

## What landed

- `LocalBriefingItem.imageURL: URL?`. Stable ids unchanged (`afd-{id}-km{i}` / `pns-{id}`).
- `LocalBriefingParser.firstImageURL(in:)` scans product text for `https://` URLs. Keeps path `.jpg/.jpeg/.png/.webp/.gif`, or `media.weather.gov`, or weather.gov / noaa.gov paths under `/images/` `/media/` `/img/` `/graphics/`. First valid per product. Soft-fail → nil. Never invents. `http://` rejected. Trailing punctuation stripped.
- Assemble copies that URL onto AFD KEY MESSAGE cards (shared product) and each PNS card. KEY MESSAGE bullets without a URL stay `nil`.
- Deleted `LocalBriefingHero` (keyword matching + uniqueness walk). Rail no longer references `NewsHero*` assets. Asset files left on disk.
- `YourNewsCard`: `AsyncImage` 16:9, continuous 20pt corners, `scaledToFill`, clipped, only when `imageURL != nil`. Load fail / nil → text-only (headline + `{relative} · {source}`), top-aligned, no empty hole.
- Attribution stays text (`NWS Memphis`). No NWS logo.

Assemble density, freshness windows, and `AlertsHonesty` untouched.

## Live MEG (Olive Branch, iPhone 16 `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`)

Three AFD KEY MESSAGES, no fresh PNS:

| # | Headline | Photo |
|---|---|---|
| 1 | Shower and thunderstorm chances increase late tonight into Monday, with organized severe weather not expected. | **none** |
| 2 | Additional chances for showers and thunderstorms are expected through midweek. | **none** |
| 3 | Near to slightly above normal temperatures are expected across the Mid-South for most of the week, but extreme heat is not expected. | **none** |

Meta: `3h ago · NWS Memphis`. No 16:9, no stock still, no placeholder.

## Shots

- `alerts-your-news-text-only.png` — Alerts, Your News rail, two text-only KEY MESSAGE cards (second peeking). Honest empty photos.

Do not treat `hero-match/alerts-your-news-photos.png` as current (those were keyword `NewsHero*` stills).

## Tests

iPhone 16 `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`: **478** `DayCastTests` passed, 0 failed (PNS fixture with `https://media.weather.gov/meg/survey.jpg` → `imageURL` set; AFD KEY MESSAGE without URL → nil; `product.php` / office / alerts links rejected; first valid image URL wins; `.jpeg` on a non-NOAA host kept; `http://` rejected).

## Out of scope (still)

Keyword/stock hero fallback, Imagine stills, TV/RSS/NewsAPI, denser KEY MESSAGE assemble, `AlertsHonesty` / freshness, version bump, push, TestFlight.
