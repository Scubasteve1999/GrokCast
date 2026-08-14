import SwiftUI

struct AIInsightFeedCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      Text("AI Insight")
        .font(DesignTokens.Typography.subsection())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .tracking(DesignTokens.Typography.cardLabelTracking)

      GrokBriefCard(presentation: .figma)
    }
  }
}
