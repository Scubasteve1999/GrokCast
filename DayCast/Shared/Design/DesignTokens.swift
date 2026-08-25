import SwiftUI

// MARK: - DayCast design tokens — Apple Weather calm

/// Single source of truth for dark weather UI: quiet type, solid surfaces, restrained motion.
enum DesignTokens {

  // MARK: - Palette (layered weather — strong bg/card separation)

  enum Palette {
    /// Deep stage behind weather wash.
    static let bgPrimary = SwiftUI.Color(hex: "#05070C")
    static let bgSecondary = SwiftUI.Color(hex: "#0E121A")
    /// Mid surface for secondary cards.
    static let cardBackground = SwiftUI.Color(hex: "#1E2430")
    /// Raised surface for hero-adjacent / primary blocks.
    static let cardElevated = SwiftUI.Color(hex: "#2C3444")
    static let cardStroke = SwiftUI.Color.white.opacity(0.20)
    static let textPrimary = SwiftUI.Color.white
    static let textSecondary = SwiftUI.Color.white.opacity(0.78)
    static let textTertiary = SwiftUI.Color.white.opacity(0.52)
    static let accent = SwiftUI.Color(hex: "#8BB8F0")
    static let accentWarm = SwiftUI.Color(hex: "#F0B07A")
    static let accentCool = SwiftUI.Color(hex: "#9AC4E8")
    static let success = SwiftUI.Color(hex: "#34C759")
    static let warning = SwiftUI.Color(hex: "#FFD60A")
    static let danger = SwiftUI.Color(hex: "#FF453A")

    /// Radar-only chrome (track on the map). Everything else uses text/accent.
    static let radarTrack = SwiftUI.Color.white.opacity(0.16)
    static var radarProgress: SwiftUI.Color { accent }
    static var radarAccent: SwiftUI.Color { accent }
    static var radarCardBackground: SwiftUI.Color { cardBackground }
    static var radarCardStroke: SwiftUI.Color { cardStroke }
    static var radarTextPrimary: SwiftUI.Color { textPrimary }
    static var radarTextSecondary: SwiftUI.Color { textSecondary }
  }

  // MARK: - Spacing (8pt)

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

  enum Radius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 22
    static let xLarge: CGFloat = 28
  }

  enum Card {
    static let cornerRadiusCompact: CGFloat = DesignTokens.Radius.small
    static let cornerRadius: CGFloat = DesignTokens.Radius.medium
    static let cornerRadiusMedium: CGFloat = DesignTokens.Radius.medium
    static let cornerRadiusLarge: CGFloat = DesignTokens.Radius.large
    static let strokeWidth: CGFloat = 1
  }

  // MARK: - Typography (SF Pro, calm — no display black / shouting caps)

  enum Typography {
    /// Legacy aliases — prefer the named fonts below.
    static let cardLabelTracking: CGFloat = 0
    static let tightTracking: CGFloat = 0
    static let headerTracking: CGFloat = 0

    /// Hero temperature — TWC-scale display number on the sky.
    static func displayTemp() -> Font {
      .system(size: 96, weight: .semibold)
    }

    /// Today first-glance temp. Large enough to read; short enough that Your News peeks.
    static func todayTemp() -> Font {
      .system(size: Layout.todayTempSize, weight: .semibold)
    }

    /// Back-compat for call sites still using the old name.
    static func heroTemperature() -> Font { displayTemp() }

    /// Compact temperature (sheets, More hub). Hero stays `displayTemp()`.
    static func compactTemp() -> Font { .system(size: 44, weight: .semibold) }
    /// Home-screen widget temperature (rounded, compact).
    static func widgetTemp(_ size: CGFloat = 36) -> Font {
      .system(size: size, weight: .semibold, design: .rounded)
    }

    static func title() -> Font { .system(size: 28, weight: .semibold) }
    static func studioTitle() -> Font { .system(size: 24, weight: .semibold) }
    static func headline() -> Font { .system(size: 17, weight: .semibold) }
    static func body() -> Font { .system(size: 17, weight: .regular) }
    static func monoBody() -> Font { .system(size: 17, weight: .regular, design: .monospaced) }
    static func callout() -> Font { .system(size: 15, weight: .regular) }
    static func subsection() -> Font { .system(size: 15, weight: .semibold) }
    static func caption() -> Font { .system(size: 13, weight: .regular) }
    static func metric() -> Font { .system(size: 20, weight: .medium) }
    static func micro() -> Font { .system(size: 12, weight: .regular) }
    static func symbol(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .semibold) }
  }

  /// Decorative motion (particles, shimmer sweeps). Off under Reduce Motion / Low Power.
  enum Motion {
    @MainActor
    static var allowDecorative: Bool {
      if ProcessInfo.processInfo.isLowPowerModeEnabled { return false }
      // Accessibility is checked at view level via environment; default true for token helpers.
      return true
    }
  }

  enum Opacity {
    static let iconWhite: Double = 0.55
  }

  enum Layout {
    static let horizontalPadding: CGFloat = Spacing.space20
    static let topPadding: CGFloat = Spacing.space16
    static let tabBarScrollClearance: CGFloat = Spacing.space48 + Spacing.space48
    static let bottomPadding: CGFloat = tabBarScrollClearance
    static let sectionSpacing: CGFloat = Spacing.space24
    static let cardPadding: CGFloat = Spacing.space16
    static let cardInnerSpacing: CGFloat = Spacing.space8
    static let cardRadius: CGFloat = Radius.medium
    static let chipRadius: CGFloat = Radius.small
    static let searchRadius: CGFloat = Radius.small
    static let heroIconSize: CGFloat = 44
    static let hourlyRowHeight: CGFloat = 100
    static let hourlyChipWidth: CGFloat = 72
    /// Today Now temp. Keep below `displayTemp` so Your News peeks on iPhone 16.
    static let todayTempSize: CGFloat = 72
  }

  /// Temporary aliases. Prefer `Typography` / `Layout`.
  enum Figma {
    enum Typography {
      static let screenTitle = DesignTokens.Typography.title()
      static let studioTitle = DesignTokens.Typography.studioTitle()
      static let sectionLabel = DesignTokens.Typography.caption()
      static let subsectionLabel = DesignTokens.Typography.subsection()
      static let cardHeadline = DesignTokens.Typography.headline()
      static let rowTitle = DesignTokens.Typography.body()
      static let rowSubtitle = DesignTokens.Typography.caption()
      static let body = DesignTokens.Typography.callout()
      static let chipTime = DesignTokens.Typography.caption()
      static let chipTemp = DesignTokens.Typography.metric()
      static let locationLabel = DesignTokens.Typography.caption()
    }

    enum Metrics {
      static let horizontalPadding = Layout.horizontalPadding
      static let topPadding = Layout.topPadding
      static let bottomPadding = Layout.bottomPadding
      static let sectionSpacing = Layout.sectionSpacing
      static let cardPadding = Layout.cardPadding
      static let cardInnerSpacing = Layout.cardInnerSpacing
      static let cardRadius = Layout.cardRadius
      static let chipRadius = Layout.chipRadius
      static let searchRadius = Layout.searchRadius
      static let heroIconSize = Layout.heroIconSize
      static let hourlyRowHeight = Layout.hourlyRowHeight
      static let hourlyChipWidth = Layout.hourlyChipWidth
    }
  }
}

// MARK: - Card styling

struct CardStyle: ViewModifier {
  var background: SwiftUI.Color = DesignTokens.Palette.cardBackground
  var stroke: SwiftUI.Color = DesignTokens.Palette.cardStroke
  var cornerRadius: CGFloat = DesignTokens.Card.cornerRadius
  var strokeWidth: CGFloat = DesignTokens.Card.strokeWidth
  var elevated: Bool = false

  func body(content: Content) -> some View {
    content
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(background)
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
              LinearGradient(
                colors: [
                  Color.white.opacity(elevated ? 0.14 : 0.08),
                  Color.white.opacity(0.02),
                  Color.clear,
                ],
                startPoint: .top,
                endPoint: .bottom
              )
            )
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(
            LinearGradient(
              colors: [
                Color.white.opacity(elevated ? 0.42 : 0.28),
                Color.white.opacity(0.08),
                stroke.opacity(0.5),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: elevated ? 1.25 : 1
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      // Stacked shadows = clearer separation from the stage.
      .shadow(color: Color.black.opacity(0.55), radius: elevated ? 28 : 18, x: 0, y: elevated ? 16 : 10)
      .shadow(color: Color.black.opacity(0.35), radius: elevated ? 6 : 4, x: 0, y: elevated ? 3 : 2)
  }
}

extension View {
  func cardStyle(
    background: SwiftUI.Color = DesignTokens.Palette.cardBackground,
    stroke: SwiftUI.Color = DesignTokens.Palette.cardStroke,
    cornerRadius: CGFloat = DesignTokens.Card.cornerRadius,
    strokeWidth: CGFloat = DesignTokens.Card.strokeWidth,
    elevated: Bool = false
  ) -> some View {
    modifier(
      CardStyle(
        background: background,
        stroke: stroke,
        cornerRadius: cornerRadius,
        strokeWidth: strokeWidth,
        elevated: elevated
      )
    )
  }

  func dayCastCard(elevated: Bool = false) -> some View {
    cardStyle(elevated: elevated)
  }

  func tacticalCard() -> some View {
    dayCastCard()
  }

  func elevatedCard() -> some View {
    cardStyle(
      background: DesignTokens.Palette.cardElevated,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadius,
      elevated: true
    )
  }

  /// Soft depth without “gamey” neon glow.
  func elevatedShadow() -> some View {
    self
      .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
      .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
  }

  func elevatedCardStyle(
    background: SwiftUI.Color = DesignTokens.Palette.cardElevated,
    stroke: SwiftUI.Color = DesignTokens.Palette.cardStroke,
    cornerRadius: CGFloat = DesignTokens.Card.cornerRadius,
    strokeWidth: CGFloat = DesignTokens.Card.strokeWidth
  ) -> some View {
    cardStyle(
      background: background, stroke: stroke, cornerRadius: cornerRadius, strokeWidth: strokeWidth
    )
    .elevatedShadow()
  }

  /// Soft fill + light top highlight (depth without ultraThinMaterial stack).
  func glassCardStyle(
    cornerRadius: CGFloat = DesignTokens.Card.cornerRadius,
    strokeTint: Color = DesignTokens.Palette.cardStroke
  ) -> some View {
    background(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(
          LinearGradient(
            colors: [
              DesignTokens.Palette.cardElevated.opacity(0.95),
              DesignTokens.Palette.cardBackground,
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .stroke(
          LinearGradient(
            colors: [
              Color.white.opacity(0.18),
              Color.white.opacity(0.06),
            ],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: DesignTokens.Card.strokeWidth
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    .elevatedShadow()
  }
}

// MARK: - Color hex

extension Color {
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
