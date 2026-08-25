import SwiftUI

struct SunMoonFeedCard: View {
  let sunrise: Date?
  let sunset: Date?
  var timeZone: TimeZone = .current
  var onTap: () -> Void

  private var moon: (phase: MoonPhase, illumination: Double) {
    MoonPhase.phase(on: Date())
  }

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
        HStack {
          Text("Sun & Moon")
            .font(DesignTokens.Typography.subsection())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
            .tracking(DesignTokens.Typography.cardLabelTracking)
          Spacer()
          Image(systemName: "chevron.right")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }

        HStack(spacing: DesignTokens.Spacing.space16) {
          sunColumn
          Divider().frame(height: 44)
          moonColumn
        }
      }
      .padding(DesignTokens.Spacing.space16)
      .cardStyle()
      .accessibilityHidden(true)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilitySummary)
  }

  private var sunColumn: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
      Label(formatTime(sunrise), systemImage: "sunrise.fill")
        .font(DesignTokens.Typography.subsection())
        .foregroundStyle(DesignTokens.Palette.accentWarm)
      Label(formatTime(sunset), systemImage: "sunset.fill")
        .font(DesignTokens.Typography.subsection())
        .foregroundStyle(DesignTokens.Palette.accentCool)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var moonColumn: some View {
    HStack(spacing: DesignTokens.Spacing.space8) {
      Image(systemName: moon.phase.symbolName)
        .font(DesignTokens.Typography.subsection())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .symbolRenderingMode(.hierarchical)
      VStack(alignment: .leading, spacing: 2) {
        Text(moon.phase.displayName)
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Text("\(Int(round(moon.illumination * 100)))% lit")
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func formatTime(_ date: Date?) -> String {
    guard let date else { return "--:--" }
    return LocationTimezone.formatter(dateFormat: "h:mm a", timeZone: timeZone)
      .string(from: date)
  }

  private var accessibilitySummary: String {
    Self.accessibilityLabel(
      sunrise: formatTime(sunrise),
      sunset: formatTime(sunset),
      phase: moon.phase.displayName,
      litPercent: Int(round(moon.illumination * 100))
    )
  }

  /// One VoiceOver string for the whole card. Children stay visual-only.
  static func accessibilityLabel(
    sunrise: String,
    sunset: String,
    phase: String,
    litPercent: Int
  ) -> String {
    "Sun and moon. Sunrise \(sunrise), sunset \(sunset). \(phase), \(litPercent) percent illuminated. Opens details."
  }
}

struct SunMoonDetailView: View {
  let sunrise: Date?
  let sunset: Date?
  var timeZone: TimeZone = .current

  private var moon: (phase: MoonPhase, illumination: Double) {
    MoonPhase.phase(on: Date())
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        SunriseSunsetCard(sunrise: sunrise, sunset: sunset, timeZone: timeZone)

        HStack(spacing: DesignTokens.Spacing.space12) {
          Image(systemName: moon.phase.symbolName)
            .font(DesignTokens.Typography.symbol(36))
            .foregroundStyle(DesignTokens.Palette.textPrimary)
            .symbolRenderingMode(.hierarchical)
          VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
            Text(moon.phase.displayName)
              .font(DesignTokens.Typography.headline())
              .foregroundStyle(DesignTokens.Palette.textPrimary)
            Text(
              "About \(Int(round(moon.illumination * 100)))% of the moon is illuminated tonight."
            )
            .font(DesignTokens.Typography.callout())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
          }
        }
        .padding(DesignTokens.Spacing.space16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
      }
      .padding(DesignTokens.Spacing.space20)
      .padding(.bottom, DesignTokens.Layout.tabBarScrollClearance)
    }
    .background(DesignTokens.Palette.bgPrimary.ignoresSafeArea())
    .navigationTitle("Sun & Moon")
    .navigationBarTitleDisplayMode(.inline)
    .preferredColorScheme(.dark)
  }
}
