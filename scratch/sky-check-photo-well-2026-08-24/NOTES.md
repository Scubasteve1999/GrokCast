# Sky Check photo well — 2026-08-24

**Repo:** `/Users/bigstevedev/Projects/GrokCast`  
**Base:** `c3dba88` (public desk) on `d01c93a` + `4a821ff`; marketing **1.0.7 (143)**  
**Commit:** `fix(grok): photography-first Sky Check photo well`  
**Slice:** parked item from `scratch/sky-check-ai-polish-2026-08-23/MVP-AGREEMENT.md` — visual only.

## What shipped

1. **No danger chrome.** Compact Sky Check card label, CTA, and stroke use `Palette.accent` / default `cardStroke` — not `Palette.danger`. SKY CHECK keeps `cloud.bolt.fill`. More hub Sky Check row tint is accent (sky), not red.
2. **Photography well.** Empty compact card is a large library well: `NewsHeroDawn` (top-aligned sky), `photo` glyph, **Check this sky**. Not a red badge. After-success stays last-check + accent **Check another**.
3. **3-chip row.** Compact Threat check / Outside now? / Outlook are equal-width chips. 2×2 SF-symbol tiles (`figmaTile`) removed. Regular chips unchanged (same three + photo chip).
4. **Public copy unchanged.** `SkyCheckDeskCopy.photoCTA` / `checkAnotherCTA` still “Check this sky” / “Check another”. No camera capture, no persisted thumbs.

## Stills (iPhone 16, `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`, iOS 26.5)

| File | What |
|------|------|
| `01-more-hub-sky-check.jpg` | More → Sky Check row; sky-blue bolt, not a red sticker |
| `02-sky-check-empty.jpg` | Empty desk: photo well + Check this sky, hedge, 3 chips, no Radar read |

## Tests

`xcodebuild` DayCastTests on iPhone 16 `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`: **497 passed**. Honesty suite: CTA verb, no Radar read, exact 3 prompt titles.

## Out of this slice

Camera capture, persist thumbs, 4.7 filter, refund, Imagine on Today, radar / wet probe / paint floor, version bump, push, TestFlight, `RadarExplainContext`, internal `StormSpotter*` / `daycast://grok` / `Tab.grok` renames, fifth tab.
