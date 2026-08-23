import SwiftUI

/// Shared first-run chrome so welcome, permission, empty, and denied
/// feel like Today’s feed — not a generic SF Symbol card.
enum TodayFirstRunStyle {
  static let cardRadius = DesignTokens.Card.cornerRadiusLarge
  static let cardPadding = DesignTokens.Spacing.space24
  static let glyphCanvas: CGFloat = 104
}

struct TodayWeatherGlyph: View {
  enum Kind {
    case weather
    case location
    case city
  }

  var kind: Kind = .weather
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      Circle()
        .fill(
          RadialGradient(
            colors: [
              glow.opacity(0.42),
              glow.opacity(0.12),
              Color.clear,
            ],
            center: .center,
            startRadius: 6,
            endRadius: 50
          )
        )
        .frame(width: TodayFirstRunStyle.glyphCanvas, height: TodayFirstRunStyle.glyphCanvas)

      if kind == .weather {
        Image(systemName: "sun.max.fill")
          .font(.system(size: 56, weight: .semibold))
          .foregroundStyle(DesignTokens.Palette.accentWarm.opacity(0.38))
          .blur(radius: reduceMotion ? 0 : 8)
      }

      Image(systemName: symbolName)
        .font(.system(size: kind == .weather ? 48 : 40, weight: .semibold))
        .symbolRenderingMode(.palette)
        .foregroundStyle(primaryTint, secondaryTint)
        .symbolEffect(.pulse, options: .repeating, isActive: animates)
        .shadow(color: glow.opacity(0.45), radius: 12, y: 4)
    }
    .frame(width: TodayFirstRunStyle.glyphCanvas, height: TodayFirstRunStyle.glyphCanvas)
    .accessibilityHidden(true)
  }

  private var symbolName: String {
    switch kind {
    case .weather: "cloud.sun.fill"
    case .location: "location.fill"
    case .city: "location.circle.fill"
    }
  }

  private var primaryTint: Color {
    switch kind {
    case .weather: DesignTokens.Palette.accentCool
    case .location, .city: DesignTokens.Palette.accent
    }
  }

  private var secondaryTint: Color {
    switch kind {
    case .weather: DesignTokens.Palette.accentWarm
    case .location, .city: DesignTokens.Palette.textPrimary
    }
  }

  private var glow: Color {
    switch kind {
    case .weather: DesignTokens.Palette.accentWarm
    case .location, .city: DesignTokens.Palette.accent
    }
  }

  private var animates: Bool {
    !reduceMotion && kind != .city
  }
}

struct TodayTrustRow: View {
  var body: some View {
    HStack(spacing: DesignTokens.Spacing.space8) {
      trustItem("sun.max.fill", TodayCopy.trustNow)
      middot
      trustItem("exclamationmark.triangle.fill", TodayCopy.trustAlerts)
      middot
      trustItem("cloud.rain.fill", TodayCopy.trustNextHour)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "\(TodayCopy.trustNow), \(TodayCopy.trustAlerts), \(TodayCopy.trustNextHour)")
  }

  private var middot: some View {
    Text("·")
      .font(DesignTokens.Typography.caption())
      .foregroundStyle(DesignTokens.Palette.textTertiary)
  }

  private func trustItem(_ symbol: String, _ title: String) -> some View {
    HStack(spacing: DesignTokens.Spacing.space4) {
      Image(systemName: symbol)
        .font(DesignTokens.Typography.micro())
      Text(title)
        .font(DesignTokens.Typography.caption())
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
    .foregroundStyle(DesignTokens.Palette.textTertiary)
  }
}

struct TodayPrimaryCTA: View {
  let title: String
  var systemImage: String? = nil
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: DesignTokens.Spacing.space8) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(DesignTokens.Typography.headline())
        }
        Text(title)
          .font(DesignTokens.Typography.headline())
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, DesignTokens.Spacing.space12)
      .padding(.horizontal, DesignTokens.Spacing.space16)
    }
    .buttonStyle(.borderedProminent)
    .tint(DesignTokens.Palette.accent)
    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
  }
}

struct TodayFirstRunCard<Content: View>: View {
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(spacing: DesignTokens.Spacing.space16) {
      content()
    }
    .padding(TodayFirstRunStyle.cardPadding)
    .frame(maxWidth: .infinity)
    .elevatedCardStyle(
      background: DesignTokens.Palette.cardElevated,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: TodayFirstRunStyle.cardRadius
    )
  }
}

/// Centers the card when it fits; scrolls so Dynamic Type cannot clip the CTA.
struct TodayFirstRunStage<Content: View>: View {
  @ViewBuilder var content: () -> Content

  var body: some View {
    GeometryReader { geo in
      ScrollView {
        VStack(spacing: 0) {
          Spacer(minLength: DesignTokens.Spacing.space24)
          content()
            .padding(.horizontal, DesignTokens.Spacing.space20)
            .readableContentWidth(ReadableContentWidth.compact)
          Spacer(minLength: DesignTokens.Spacing.space24)
        }
        .frame(minHeight: geo.size.height)
        .frame(maxWidth: .infinity)
      }
    }
  }
}

struct TodayStatusPill: View {
  let text: String

  var body: some View {
    HStack(spacing: DesignTokens.Spacing.space8) {
      ProgressView()
        .tint(DesignTokens.Palette.textPrimary)
        .controlSize(.small)
      Text(text)
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(Color.black.opacity(0.38), in: Capsule())
    .overlay(
      Capsule()
        .stroke(Color.white.opacity(0.18), lineWidth: DesignTokens.Card.strokeWidth)
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel(text)
    .accessibilityIdentifier(DayCastAccessibility.Today.statusPill)
  }
}

struct TodayMessageBanner: View {
  enum Tone {
    case danger
    case warning
  }

  let message: String
  var isOffline: Bool = false
  var tone: Tone = .danger
  let actionTitle: String
  let action: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: DesignTokens.Spacing.space12) {
      Image(systemName: iconName)
        .font(DesignTokens.Typography.headline())
        .foregroundStyle(tint)
        .padding(.top, 1)

      Text(message)
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(tint)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: DesignTokens.Spacing.space8)

      Button(actionTitle, action: action)
        .font(DesignTokens.Typography.caption())
        .buttonStyle(.bordered)
        .tint(tint)
        .controlSize(.small)
        .fixedSize()
    }
    .padding(DesignTokens.Spacing.space12)
    .background(tint.opacity(0.15))
    .overlay(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
        .stroke(tint.opacity(0.35), lineWidth: DesignTokens.Card.strokeWidth)
    )
    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous))
  }

  private var tint: Color {
    tone == .warning ? DesignTokens.Palette.warning : DesignTokens.Palette.danger
  }

  private var iconName: String {
    if isOffline { return "wifi.slash" }
    if tone == .warning { return "location.slash" }
    return "exclamationmark.triangle.fill"
  }
}
