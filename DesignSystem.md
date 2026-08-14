# DayCast Design System

Contract for UI. Matches `DayCast/Shared/Design/DesignTokens.swift`. Do not add a color, size, or radius without updating both.

**Look:** dark weather, quiet type, solid cards, restrained glass on HUD/overlays. Not a new brand.

---

## 1. Color (`DesignTokens.Palette`)

| Token | Hex / value | Use |
|---|---|---|
| `bgPrimary` | `#05070C` | Stage behind the weather wash |
| `bgSecondary` | `#0E121A` | Secondary layers, tab bar fill |
| `cardBackground` | `#1E2430` | Default card |
| `cardElevated` | `#2C3444` | Raised / hero-adjacent card |
| `cardStroke` | white 20% | Card edge (via `cardStyle`, not raw) |
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

Radar text/accent/card aliases resolve to the rows above. Do not introduce a second radar palette.

Atmosphere in `WeatherBackgroundView` may use raw white at low opacity (particles, not chrome).

---

## 2. Type (`DesignTokens.Typography`)

SF Pro. Prefer these helpers over `.font(.caption)` or `.system(size:)`.

| Helper | Size | Weight | Use |
|---|---|---|---|
| `displayTemp()` | 96 | Semibold | Today hero temp only |
| `compactTemp()` | 44 | Semibold | Sheets, More hub |
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
| `symbol(_:)` | 13 default | Semibold | SF Symbols |

Exception: monospaced HUD digits and weather symbols may set `design: .monospaced` or a symbol point size via `symbol(_:)`.

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
| `.dayCastCard()` / `.cardStyle()` | Default cards, feed, settings groups, forecast rows |
| `.dayCastCard(elevated: true)` | Hero-adjacent / Now card |
| `.glassCardStyle()` | HUD or overlay sitting on a map/photo/sky |

Do not invent a fourth card. `.tacticalCard()` is an alias of `.dayCastCard()`.

---

## 6. Icons

SF Symbols. `Typography.symbol()` for chrome; larger sizes only for empty-state heroes.

---

## 7. Rules

1. Tokens over literals.
2. Consistency over a new accent.
3. Hero temperature stays the loudest thing on Today.
4. Widgets (`WidgetStyle`) are a later pass — they support light mode.

**Version:** matches code as of 2026-08-14  
**Owner:** Stephen Moore
