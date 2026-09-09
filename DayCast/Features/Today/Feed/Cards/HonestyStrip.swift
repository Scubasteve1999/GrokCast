import SwiftUI

/// Persistent WFO chrome on Today. One caption line; ensemble disagree adds a second.
/// Not official WEA. Not a tall card.
struct HonestyStrip: View {
  let content: HonestyStripCopy.Content
  var sitsOnPhoto: Bool = true

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(content.primaryLine)
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(primaryColor)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
      if let second = content.secondLine {
        Text(second)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(secondaryColor)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
    }
    .frame(
      maxWidth: .infinity,
      minHeight: content.showsEnsembleLine
        ? TodayGlanceLayout.honestyStripEnsembleHeight
        : TodayGlanceLayout.honestyStripCalmHeight,
      alignment: .leading
    )
    .accessibilityLabel(content.accessibilityLabel)
    .accessibilityIdentifier(DayCastAccessibility.Today.honestyStrip)
  }

  private var primaryColor: Color {
    sitsOnPhoto
      ? Color.white.opacity(0.82)
      : DesignTokens.Palette.textSecondary
  }

  private var secondaryColor: Color {
    sitsOnPhoto
      ? Color.white.opacity(0.70)
      : DesignTokens.Palette.textTertiary
  }
}
