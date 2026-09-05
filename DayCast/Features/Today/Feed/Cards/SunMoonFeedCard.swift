import SwiftUI

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
