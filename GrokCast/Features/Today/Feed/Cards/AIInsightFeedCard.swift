import SwiftUI

struct AIInsightFeedCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      Text("AI Insight")
        .font(DesignTokens.Figma.Typography.subsectionLabel)
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .textCase(.uppercase)
        .tracking(DesignTokens.Typography.cardLabelTracking)

      GrokBriefCard(presentation: .figma)
    }
  }
}
