# Today Your News rail — 2026-08-24

Slice: `feat(today): Your News rail on Today`  
Repo: `/Users/bigstevedev/Projects/GrokCast`. Version left at **1.0.7 / 144**. No push / TF.

## Hole

TWC puts a Your News rail on the first screen. DayCast had the same NWS AFD/PNS cards only on Alerts.

## Product

Today is home. `FeedItem.yourNews` sits **after Hourly, before Daily**. Same `LocalBriefingStore` / parser / `LocalBriefingSection` / max 3 / weather.gov tap. No second AFD/PNS fetch. Hide when items empty or location id mismatch. Alerts keeps the same rail.

Display title is `YourNewsHeadline` punch-up of the office `title`. No Grok, no 4.7 surface. Office line stays `title` for Sky Check + VoiceOver. Photos still require a real source `https` image URL.

Site Doppler hoist (`6c92700`) unchanged. Five tabs. Build 144.

## Live MEG (Olive Branch, iPhone 16 `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`)

AFD issued `2026-08-24T23:20:00+00:00`. Three KEY MESSAGES, no fresh PNS, no image URLs (text-only).

| Office title | Display title shipped |
|---|---|
| Isolated shower and thunderstorm chances will increase Tuesday morning for areas along and west of the Mississippi River. | Why Tuesday morning still has an isolated storm window. |
| Additional chances for showers and thunderstorms are expected each day through Thursday. | The Thursday storm round MEG says isn’t done yet. |
| Near to slightly above normal temperatures are expected across the Mid-South for most of the week, but extreme heat is not expected. | The Mid-South stays warm. Extreme heat? MEG says no. |

Tap URL is `https://forecast.weather.gov/product.php?site=NWS&issuedby=MEG&product=AFD&format=CI`.

## Viewport

Olive Branch is a story day (Air Quality Alert + Site Doppler hoist). First viewport is Now → Alerts → Site Doppler (`today-first.png`). Hourly + Your News sit on the next scroll. `today-your-news-peek.png` is Hourly with the rail peeking (next card peeks). Did not restack the storm glance.

## Tests

iPhone 16 `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`: **564** `DayCastTests` passed, 0 failed.

Full scheme also ran 2 pre-existing `CriticalFlowsUITests` Sky Check camera failures (out of scope).

## Shots

- `today-your-news-peek.png` — Hourly, then Your News (punchy MEG lines, text-only, next card peeking)
- `today-first.png` — true first viewport on this warned city (rail not in frame)
