import SwiftUI

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
