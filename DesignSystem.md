# GrokCast Design System v1

**Purpose**: This document defines the visual language, spacing, typography, and component rules for GrokCast. All future UI work should follow these rules for consistency and professional quality.

> **Bright sky exception (Today, Forecast, Alerts).** **Today**, **Forecast**, and **Alerts** intentionally depart from the dark-first palette below: they use a full-bleed, condition + day/night **bright sky** backdrop (`TodaySkyBackground`) with translucent frosted cards and white text — an Apple-Weather-style look. Tokens and components live in `GrokCast/Features/Today/TodayBrightTheme.swift` (`.todayGlassCard`, `TodayBright.*`, `.skyTextShadow()`) and shared sections in `TodayAppleSections.swift`. Spacing/radius still use `DesignTokens`. **Radar, Grok AI, Locations, and Settings** follow the dark system defined here. When editing the bright tabs, extend `TodayBright`/`todayGlassCard`; everywhere else, use the tokens below.

---

## 1. Color Palette

Use these exact color tokens. Do not introduce new colors without updating this system.

| Token             | Hex       | Usage                                      | Notes |
|-------------------|-----------|--------------------------------------------|-------|
| `bgPrimary`       | `#0B0D14` | Main screen background                     | Deepest background |
| `bgSecondary`     | `#11141C` | Secondary background layers                | Subtle lift |
| `cardBackground`  | `#1A1F2B` | Default card / surface background          | Main card color |
| `cardElevated`    | `#22283A` | Elevated or pressed card states            | Higher elevation |
| `cardStroke`      | `#2F3648` | Subtle card borders (use sparingly)        | Low contrast |
| `textPrimary`     | `#F1F3F8` | Primary text, large temperature            | High contrast |
| `textSecondary`   | `#A8AEC0` | Labels and secondary information           | Medium contrast |
| `textTertiary`    | `#6B7280` | Small details and captions                 | Low emphasis |
| `accent`          | `#5B8DEE` | Buttons, links, active states              | Main interactive color |
| `accentWarm`      | `#F5A35C` | Warm temperatures and sun elements         | Temperature feedback |
| `accentCool`      | `#5BC4E8` | Cool temperatures and precipitation        | Temperature feedback |
| `success`         | `#4ADE80` | Positive states                            | Good air quality, clear skies |
| `warning`         | `#FACC15` | Warning states                             | UV index, moderate alerts |
| `danger`          | `#F87171` | Severe / danger states                     | Severe weather alerts |

**Rule**: Stick to this palette. Temperature values should use `accentWarm` or `accentCool` when it adds meaningful visual feedback.

---

## 2. Typography

| Element              | Size     | Weight      | Color            | Usage |
|----------------------|----------|-------------|------------------|-------|
| **Hero Temperature** | 108–120pt| Black/Heavy | `textPrimary`    | Main temperature in Today hero |
| **Large Title**      | 34pt     | Bold        | `textPrimary`    | Screen titles |
| **Title**            | 28pt     | Semibold    | `textPrimary`    | Section headers |
| **Headline**         | 20pt     | Semibold    | `textPrimary`    | Card titles, important labels |
| **Body**             | 17pt     | Regular     | `textPrimary`    | Main body text |
| **Callout**          | 16pt     | Medium      | `textSecondary`  | Secondary info |
| **Subheadline**      | 15pt     | Regular     | `textSecondary`  | Supporting text |
| **Footnote**         | 13pt     | Regular     | `textTertiary`   | Small details, timestamps |
| **Caption**          | 12pt     | Regular     | `textTertiary`   | Very small labels |

**Rules**:
- Limit to 2–3 font weights maximum.
- Hero temperature must feel dominant (significantly larger than surrounding text).
- Maintain consistent line height and letter spacing.

---

## 3. Spacing Scale

Use this 8pt-based scale:

| Token      | Value | Common Usage |
|------------|-------|--------------|
| `space2`   | 2pt   | Fine adjustments |
| `space4`   | 4pt   | Tiny gaps |
| `space8`   | 8pt   | Small gaps, icon padding |
| `space12`  | 12pt  | Tight spacing |
| `space16`  | 16pt  | Standard card internal padding |
| `space20`  | 20pt  | Preferred card internal padding |
| `space24`  | 24pt  | Default section spacing |
| `space32`  | 32pt  | Generous section gaps |
| `space40`  | 40pt  | Large breathing room |
| `space48`  | 48pt  | Very generous spacing |

**Rule**: Prefer `space16`, `space24`, and `space32` for most layout work. Avoid random spacing values.

---

## 4. Corner Radius

| Token           | Value | Usage |
|-----------------|-------|-------|
| `radiusSmall`   | 8pt   | Pills, tags, small elements |
| `radiusMedium`  | 16pt  | Default card radius (most common) |
| `radiusLarge`   | 24pt  | Hero cards, prominent surfaces |
| `radiusXLarge`  | 32pt  | Very large containers (rare) |

**Rule**: Be consistent. Most cards should use `radiusMedium`.

---

## 5. Card & Surface System

- **Default Card**: Background = `cardBackground`, Corner Radius = `radiusMedium`, subtle shadow
- **Elevated Card**: Background = `cardElevated`, slightly stronger shadow
- **Internal Padding**: Minimum `space16`, preferred `space20`
- **Stroke**: Use `cardStroke` only when necessary for definition (keep very low contrast)

**Recommended Shadow (SwiftUI)**:
```swift
// Default card
.shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)

// Elevated card
.shadow(color: .black.opacity(0.20), radius: 12, x: 0, y: 6)
```

---

## 6. Iconography

- Primary icon set: **SF Symbols** (recommended for consistency)
- Size guidelines:
  - Small: 16–20pt
  - Medium: 24–28pt
  - Large / Hero: 36–48pt+
- Keep icon weight and rendering mode consistent across the app.

---

## 7. Layout & Hierarchy Principles

- The **hero temperature** should be the most visually dominant element on the Today screen.
- Use clear section separation with generous vertical spacing (`space32`–`space40` between major sections).
- Inside cards, maintain consistent internal padding (`space16`–`space20`).
- Prioritize **scannability** — users should understand current conditions in under 3 seconds.
- Apply `accentWarm` and `accentCool` thoughtfully for temperature-related elements.
- Maintain strong visual hierarchy: biggest = most important.

---

## 8. General Rules

- **Consistency over creativity** in spacing, radius, and colors.
- Never hardcode colors, spacing, or radius values — always reference the tokens above.
- When in doubt, increase spacing slightly rather than making things feel cramped.
- Temperature display should feel premium and dominant.
- All components should feel intentional and polished.

---

**Version**: v1  
**Last Updated**: June 24, 2026  
**Owner**: Stephen Moore (GrokCast)
