import SwiftUI

struct RadarFeedCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      Text("Radar")
        .font(DesignTokens.Figma.Typography.subsectionLabel)
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .tracking(DesignTokens.Typography.cardLabelTracking)

      RadarPreviewCard()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Live radar preview. Opens the Radar tab.")
  }
}
