import SwiftUI

// MARK: - Centralized Design Tokens (Modern Dark Professional)

/// Lightweight design tokens extracted from repeated card, typography, and visual patterns
/// used across TodayView, ForecastView, and related components.
/// Goal: single source of truth for consistent dark theme without over-engineering.
enum DesignTokens {

  // MARK: - GrokCast Color Palette (exact from redesign spec)
  enum Palette {
    static let bgPrimary = SwiftUI.Color(hex: "#0B0D14")
    static let bgSecondary = SwiftUI.Color(hex: "#11141C")
    static let cardBackground = SwiftUI.Color(hex: "#1A1F2B")
    static let cardElevated = SwiftUI.Color(hex: "#22283A")
    static let cardStroke = SwiftUI.Color(hex: "#2F3648")
    static let textPrimary = SwiftUI.Color(hex: "#F1F3F8")
    static let textSecondary = SwiftUI.Color(hex: "#A8AEC0")
    static let textTertiary = SwiftUI.Color(hex: "#6B7280")
    static let accent = SwiftUI.Color(hex: "#5B8DEE")
    static let accentWarm = SwiftUI.Color(hex: "#F5A35C")
    static let accentCool = SwiftUI.Color(hex: "#5BC4E8")
    static let success = SwiftUI.Color(hex: "#4ADE80")
    static let warning = SwiftUI.Color(hex: "#FACC15")
    static let danger = SwiftUI.Color(hex: "#F87171")

    // Radar-specific tokens for consistency with radar tab polish (per task spec)
    static let radarCardBackground = SwiftUI.Color(hex: "#161B22")
    static let radarCardStroke = SwiftUI.Color(hex: "#30363D")
    static let radarTextPrimary = SwiftUI.Color(hex: "#E6EDF3")
    static let radarTextSecondary = SwiftUI.Color(hex: "#8B949E")
    static let radarAccent = SwiftUI.Color(hex: "#58A6FF")
    static let radarTrack = SwiftUI.Color(hex: "#21262D")
    static let radarProgress = SwiftUI.Color(hex: "#58A6FF")
  }

  // MARK: - Spacing Scale (exact 8pt system from DesignSystem.md v1)
  enum Spacing {
    static let space2: CGFloat = 2
    static let space4: CGFloat = 4
    static let space8: CGFloat = 8
    static let space12: CGFloat = 12
    static let space16: CGFloat = 16
    static let space20: CGFloat = 20
    static let space24: CGFloat = 24
    static let space32: CGFloat = 32
    static let space40: CGFloat = 40
    static let space48: CGFloat = 48
  }

  // MARK: - Corner Radius (exact from DesignSystem.md v1)
  enum Radius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
  }

  // MARK: - Card Styling (updated for new palette)
  enum Card {
    /// Primary card background using new palette
    static let background = DesignTokens.Palette.cardBackground

    /// Elevated card background
    static let elevated = DesignTokens.Palette.cardElevated

    /// Subtle card border
    static let stroke = DesignTokens.Palette.cardStroke

    /// Default card radius (DesignSystem v1 radiusMedium). TacticalCard + most rows.
    static let cornerRadius: CGFloat = DesignTokens.Radius.medium

    /// Compact card / row radius (hourly cards, daily rows).
    static let cornerRadiusCompact: CGFloat = DesignTokens.Radius.small

    /// Medium row radius (some forecast rows, welcome states).
    static let cornerRadiusMedium: CGFloat = DesignTokens.Radius.medium

    /// Large / hero card radius (DesignSystem v1 radiusLarge).
    static let cornerRadiusLarge: CGFloat = DesignTokens.Radius.large

    /// Small utility (badges, small pills).
    static let cornerRadiusSmall: CGFloat = DesignTokens.Radius.small

    /// Standard stroke width for cards.
    static let strokeWidth: CGFloat = 1
  }

  // MARK: - Typography & Tracking
  enum Typography {
    /// Tracking used for uppercase labels on cards.
    static let cardLabelTracking: CGFloat = 1.2

    /// Tight tracking for time / small labels.
    static let tightTracking: CGFloat = 0.3

    /// Hero / section header tracking.
    static let headerTracking: CGFloat = 1.5

    /// Large hero temperature on Today and marketing screenshots.
    static func heroTemperature() -> Font {
      .system(size: 92, weight: .black, design: .rounded)
    }
  }

  // MARK: - Other Repeated Values (from dark theme work)
  enum Opacity {
    /// Very subtle white for icons / secondary text.
    static let subtleWhite: Double = 0.55

    /// Icon / secondary.
    static let iconWhite: Double = 0.65

    /// Hero condition text.
    static let heroCondition: Double = 0.92

    /// Freshness / fine print.
    static let finePrint: Double = 0.5

    /// High/low labels.
    static let highLowLabel: Double = 0.6
  }
}

// MARK: - Reusable Card Styling Modifier

/// Applies the standard card background + stroke + clip using GrokCast palette.
/// Updated for AccuWeather IA + GrokCast visual style redesign.
struct CardStyle: ViewModifier {
  var background: SwiftUI.Color = DesignTokens.Palette.cardBackground
  var stroke: SwiftUI.Color = DesignTokens.Palette.cardStroke
  var cornerRadius: CGFloat = DesignTokens.Card.cornerRadius
  var strokeWidth: CGFloat = DesignTokens.Card.strokeWidth

  func body(content: Content) -> some View {
    content
      .background(background)
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius)
          .stroke(stroke, lineWidth: strokeWidth)
      )
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
  }
}

extension View {
  /// Applies the canonical card styling using GrokCast palette.
  func cardStyle(
    background: SwiftUI.Color = DesignTokens.Palette.cardBackground,
    stroke: SwiftUI.Color = DesignTokens.Palette.cardStroke,
    cornerRadius: CGFloat = DesignTokens.Card.cornerRadius,
    strokeWidth: CGFloat = DesignTokens.Card.strokeWidth
  ) -> some View {
    modifier(
      CardStyle(
        background: background,
        stroke: stroke,
        cornerRadius: cornerRadius,
        strokeWidth: strokeWidth
      )
    )
  }

  /// Convenience for the classic TacticalCard look with new palette.
  func tacticalCard() -> some View {
    cardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadius
    )
  }

  /// Elevated / "now" variant.
  func elevatedCard() -> some View {
    cardStyle(
      background: DesignTokens.Palette.cardElevated,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadiusCompact
    )
  }

  func elevatedShadow() -> some View {
    self.shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
  }

  func elevatedCardStyle(
    background: SwiftUI.Color = DesignTokens.Palette.cardBackground,
    stroke: SwiftUI.Color = DesignTokens.Palette.cardStroke,
    cornerRadius: CGFloat = DesignTokens.Card.cornerRadius,
    strokeWidth: CGFloat = DesignTokens.Card.strokeWidth
  ) -> some View {
    cardStyle(
      background: background, stroke: stroke, cornerRadius: cornerRadius, strokeWidth: strokeWidth
    )
    .elevatedShadow()
  }

  /// Frosted glass card used by score, minutecast, Grok brief, and settings groups.
  func glassCardStyle(
    cornerRadius: CGFloat = DesignTokens.Card.cornerRadius,
    strokeTint: Color = DesignTokens.Palette.cardStroke
  ) -> some View {
    background(
      RoundedRectangle(cornerRadius: cornerRadius)
        .fill(.ultraThinMaterial)
        .background(
          RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DesignTokens.Palette.cardBackground.opacity(0.55))
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: cornerRadius)
        .stroke(strokeTint, lineWidth: DesignTokens.Card.strokeWidth)
    )
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
  }
}

// MARK: - Color + Hex (moved here for central access; used by DynamicBackground and theme tints)

extension Color {
  /// Parses #RRGGBB or #RRGGBBAA. Falls back to a very dark neutral.
  init(hex: String) {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

    var rgb: UInt64 = 0
    guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
      self.init(.sRGB, red: 0.06, green: 0.06, blue: 0.06, opacity: 1)
      return
    }

    let length = hexSanitized.count
    var r: Double = 0
    var g: Double = 0
    var b: Double = 0
    var a: Double = 1

    if length == 6 {
      r = Double((rgb & 0xFF0000) >> 16) / 255.0
      g = Double((rgb & 0x00FF00) >> 8) / 255.0
      b = Double(rgb & 0x0000FF) / 255.0
    } else if length == 8 {
      r = Double((rgb & 0xFF00_0000) >> 24) / 255.0
      g = Double((rgb & 0x00FF_0000) >> 16) / 255.0
      b = Double((rgb & 0x0000_FF00) >> 8) / 255.0
      a = Double(rgb & 0x0000_00FF) / 255.0
    } else {
      r = 0.06
      g = 0.06
      b = 0.06
    }

    self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
  }
}
