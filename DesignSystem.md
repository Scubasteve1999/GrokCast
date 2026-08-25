# DayCast Design System

Contract for UI. Matches `DayCast/Shared/Design/DesignTokens.swift`. Do not add a color, size, or radius without updating both.

**Look:** dark weather product — photography / sky wash, quiet type, **flat plates** with a 1pt hairline, one shadow. Numbers, curves, maps. Not a glossy indie sticker pack. Not a new brand.

Reference still: `scratch/today-hourly-graph-2026-08-24/today-first-viewport.png`.

---

## 1. Color (`DesignTokens.Palette`)

| Token | Hex / value | Use |
|---|---|---|
| `bgPrimary` | `#05070C` | Stage behind the weather wash |
| `bgSecondary` | `#0E121A` | Secondary layers, tab bar fill |
| `cardBackground` | `#1E2430` | Default card |
| `cardElevated` | `#2C3444` | Raised / hero-adjacent card |
| `cardStroke` | white 20% | **Fill / track only** — range bars, score ring, dry minutecast, Settings divider. Not the default plate rim. |
| `cardHairline` | white 10% | Default `.cardStyle()` / `.glassCardStyle()` rim |
| `textPrimary` | white | Body, values, titles |
| `textSecondary` | white 78% | Labels |
| `textTertiary` | white 52% | Captions, chevrons |
| `accent` | `#8BB8F0` | Interactive, radar playhead |
| `accentWarm` | `#F0B07A` | Warm temps |
| `accentCool` | `#9AC4E8` | Cool temps / precip |
| `success` | `#34C759` | Good AQI |
| `warning` | `#FFD60A` | UV, aging scan |
| `danger` | `#FF453A` | Severe alerts |
| `radarTrack` | white 16% | Radar timeline track only |

Radar text/accent/card aliases resolve to the rows above. Do not introduce a second radar palette. Do not retint `cardStroke` to quiet cards.

Atmosphere in `WeatherBackgroundView` may use raw white at low opacity (particles, not chrome).

---

## 2. Type (`DesignTokens.Typography`)

SF Pro. Prefer these helpers over `.font(.caption)` or `.system(size:)`.

| Helper | Size | Weight | Use |
|---|---|---|---|
| `todayTemp()` | 72 | Semibold | **Today first-glance** temp (`Layout.todayTempSize`) |
| `displayTemp()` | 96 | Semibold | Not the Today peek hero — sheets / marketing only |
| `compactTemp()` | 44 | Semibold | Sheets, More hub |
| `widgetTemp(_:)` | 36 default | Semibold rounded | Widget numbers; Now **hero** condition glyph |
| `title()` | 28 | Semibold | Screen titles |
| `studioTitle()` | 24 | Semibold | Briefing Studio |
| `headline()` | 17 | Semibold | Card titles |
| `body()` | 17 | Regular | Primary copy, rows |
| `monoBody()` | 17 | Regular mono | API keys, codes |
| `callout()` | 15 | Regular | Supporting copy |
| `subsection()` | 15 | Semibold | Section labels in cards |
| `caption()` | 13 | Regular | Meta, timestamps |
| `metric()` | 20 | Medium | Compact numbers |
| `micro()` | 12 | Regular | Dense HUD / ticks |
| `symbol(_:)` | 13 default | Semibold | SF Symbols **chrome** |

Exception: monospaced HUD digits and weather symbols may set `design: .monospaced` or a symbol point size via `symbol(_:)`.

Editorial labels are title-case, not shouting caps.

---

## 3. Spacing (`DesignTokens.Spacing` + `Layout`)

8pt scale: 2, 4, 8, 12, 16, 20, 24, 32, 40, 48.

| Layout | Value |
|---|---|
| `horizontalPadding` | 20 |
| `topPadding` | 16 |
| `sectionSpacing` | 24 |
| `cardPadding` | 16 |
| `cardInnerSpacing` | 8 |
| `tabBarScrollClearance` | 96 |

Prefer 16 / 24 / 32 for layout. No one-off 10 / 14 / 18 paddings in feature views.

Today first viewport is `TodayGlanceLayout` (iPhone 16 852pt). Your News must peek. Do not buy height by deleting hoist, AQI, or the rail.

---

## 4. Radius

| Token | Value | Use |
|---|---|---|
| `Radius.small` | 12 | Chips, search, HUD pills |
| `Radius.medium` | 16 | Default cards |
| `Radius.large` | 22 | Hero surfaces |
| `Radius.xLarge` | 28 | Rare |

---

## 5. Surfaces

| Modifier | When |
|---|---|
| `.dayCastCard()` / `.cardStyle()` | Default plates: solid fill, **1pt flat `cardHairline`**, one shadow. No glossy rim gradient. |
| `.dayCastCard(elevated: true)` | Hero-adjacent / Now-adjacent plate. Same drawing, slightly deeper shadow. |
| `.glassCardStyle()` | HUD or overlay on a map/photo/sky. Glass fill kept; rim is always `cardHairline`. `strokeTint` is unused. |

Do not invent a fourth card. `.tacticalCard()` is an alias of `.dayCastCard()`.

Explicit `stroke: Palette.cardStroke` stays a **flat 0.20** hairline (fill/track token, not a retint). Tab bar selected state is type weight (`textPrimary` + semibold), not an accent pill. Location chips and Today alert chips use `cardHairline` — not accent 0.35/0.7 or tint 0.45 rims. Radar HUD paints its own glass; `.fresh` has no extra rim, stale/aging keep a 1.5pt operational stroke. Live/24-hr and 1x/2x/3x are type weight on `radarTrack`.

---

## 6. Icons

SF Symbols for **chrome** (tabs, chevrons, play/pause), empty-state heroes, and severity dots.

**Hero condition glyph:** at most one, and only on Now (`widgetTemp(36)`). Hourly (Today + Forecast) has **zero** condition glyphs — curve + numbers. Daily icons are secondary, ≤16pt hierarchical. Do not put a dense SF weather strip on a section; that reads as Minecraft.

Prefer numbers, curves, photography, and maps as the face of a weather section.

---

## 7. Rules

1. Tokens over literals.
2. Consistency over a new accent.
3. Hero temperature stays the loudest thing on Today (`todayTemp()` 72).
4. Widgets (`WidgetStyle`) are a later pass — they support light mode. Skipped in the visual-system program (Stephen 2026-08-24).

**Version:** matches code as of 2026-08-24  
**Owner:** Stephen Moore
