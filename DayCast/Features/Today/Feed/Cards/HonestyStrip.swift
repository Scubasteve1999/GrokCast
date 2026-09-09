import SwiftUI

/// Persistent WFO chrome on Today. One caption line. Not official WEA.
struct HonestyStrip: View {
  let content: HonestyStripCopy.Content
  var sitsOnPhoto: Bool = true

  var body: some View {
    Text(content.primaryLine)
      .font(DesignTokens.Typography.caption())
      .foregroundStyle(
        sitsOnPhoto
          ? Color.white.opacity(0.82)
          : DesignTokens.Palette.textSecondary
      )
      .lineLimit(1)
      .minimumScaleFactor(0.85)
      .frame(
        maxWidth: .infinity,
        minHeight: TodayGlanceLayout.honestyStripCalmHeight,
        alignment: .leading
      )
      .accessibilityLabel(content.accessibilityLabel)
      .accessibilityIdentifier(DayCastAccessibility.Today.honestyStrip)
  }
}
