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
            .font(DesignTokens.Figma.Typography.subsectionLabel)
            .foregroundStyle(DesignTokens.Palette.textTertiary)
                .tracking(DesignTokens.Typography.cardLabelTracking)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }

        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.space12) {
          Text("\(aqi)")
            .font(.system(size: 40, weight: .bold, design: .rounded))
            .foregroundStyle(category.color)
            .monospacedDigit()

          VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
            Text(category.title)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(DesignTokens.Palette.textPrimary)
            Text(category.guidance)
              .font(.caption)
              .foregroundStyle(DesignTokens.Palette.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
              .lineLimit(2)
          }
        }
      }
      .padding(DesignTokens.Spacing.space16)
      .cardStyle()
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "Air quality \(aqi), \(category.title). \(category.guidance) Opens details."
    )
    .accessibilityAddTraits(.isButton)
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
            .font(.caption.weight(.semibold))
            .foregroundStyle(DesignTokens.Palette.textTertiary)
          Text("\(aqi)")
            .font(.system(size: 64, weight: .bold, design: .rounded))
            .foregroundStyle(category.color)
            .monospacedDigit()
          Text(category.title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(DesignTokens.Palette.textPrimary)
          Text(category.guidance)
            .font(.body)
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
        .padding(DesignTokens.Spacing.space16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()

        Text("Values use the US AQI scale from Open-Meteo for your selected location.")
          .font(.footnote)
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
