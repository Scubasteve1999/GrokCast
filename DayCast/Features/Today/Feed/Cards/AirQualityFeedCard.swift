import SwiftUI

struct AirQualityFeedCard: View {
  let aqi: Int
  var onTap: () -> Void

  private var category: AirQualityCategory { AirQualityCategory(usAQI: aqi) }

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
        HStack {
          Text("Air Quality")
            .font(DesignTokens.Typography.subsection())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
            .tracking(DesignTokens.Typography.cardLabelTracking)
          Spacer()
          Image(systemName: "chevron.right")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }

        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.space12) {
          Text("\(aqi)")
            .font(DesignTokens.Typography.widgetTemp(40))
            .foregroundStyle(category.color)
            .monospacedDigit()

          VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
            Text(category.title)
              .font(DesignTokens.Typography.subsection())
              .foregroundStyle(DesignTokens.Palette.textPrimary)
            Text(category.guidance)
              .font(DesignTokens.Typography.caption())
              .foregroundStyle(DesignTokens.Palette.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
              .lineLimit(2)
          }
        }
      }
      .padding(DesignTokens.Spacing.space16)
      .cardStyle()
      .accessibilityHidden(true)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      Self.accessibilityLabel(aqi: aqi, title: category.title, guidance: category.guidance)
    )
  }

  /// One VoiceOver string for the whole card. Children stay visual-only.
  static func accessibilityLabel(aqi: Int, title: String, guidance: String) -> String {
    "Air quality \(aqi), \(title). \(guidance) Opens details."
  }
}

struct AirQualityDetailView: View {
  let aqi: Int
  private var category: AirQualityCategory { AirQualityCategory(usAQI: aqi) }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
          Text("US AQI")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
          Text("\(aqi)")
            .font(DesignTokens.Typography.widgetTemp(64))
            .foregroundStyle(category.color)
            .monospacedDigit()
          Text(category.title)
            .font(DesignTokens.Typography.metric())
            .foregroundStyle(DesignTokens.Palette.textPrimary)
          Text(category.guidance)
            .font(DesignTokens.Typography.body())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
        .padding(DesignTokens.Spacing.space16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()

        Text("Values use the US AQI scale from Open-Meteo for your selected location.")
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }
      .padding(DesignTokens.Spacing.space20)
      .padding(.bottom, DesignTokens.Layout.tabBarScrollClearance)
    }
    .background(DesignTokens.Palette.bgPrimary.ignoresSafeArea())
    .navigationTitle("Air Quality")
    .navigationBarTitleDisplayMode(.inline)
    .preferredColorScheme(.dark)
  }
}
