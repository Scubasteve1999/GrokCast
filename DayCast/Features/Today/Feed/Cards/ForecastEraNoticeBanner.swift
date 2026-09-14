import SwiftUI

/// One quiet caption on Today. Not the WFO honesty strip. Not a confidence badge.
struct ForecastEraNoticeBanner: View {
  var sitsOnPhoto: Bool = false
  let onOpen: () -> Void
  let onDismiss: () -> Void

  var body: some View {
    HStack(spacing: DesignTokens.Spacing.space8) {
      Button(action: {
        Haptic.impact(.light)
        onOpen()
      }) {
        HStack(spacing: DesignTokens.Spacing.space8) {
          Text(ForecastEraNotice.Copy.banner)
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(primaryColor)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, alignment: .leading)
          Image(systemName: "chevron.right")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(secondaryColor)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(ForecastEraNotice.Copy.bannerAccessibility)
      .accessibilityHint("Shows what this means")
      .accessibilityAddTraits(.isButton)
      .accessibilityIdentifier(DayCastAccessibility.Today.forecastEraNotice)

      Button(action: {
        Haptic.impact(.light)
        onDismiss()
      }) {
        Image(systemName: "xmark")
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(secondaryColor)
          .frame(width: 28, height: 28)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(ForecastEraNotice.Copy.dismiss)
      .accessibilityIdentifier(DayCastAccessibility.Today.forecastEraNoticeDismiss)
    }
    .frame(
      maxWidth: .infinity,
      minHeight: TodayGlanceLayout.forecastEraNoticeHeight,
      alignment: .leading
    )
  }

  private var primaryColor: Color {
    sitsOnPhoto ? Color.white.opacity(0.82) : DesignTokens.Palette.textSecondary
  }

  private var secondaryColor: Color {
    sitsOnPhoto ? Color.white.opacity(0.70) : DesignTokens.Palette.textTertiary
  }
}
