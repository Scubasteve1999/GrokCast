import SwiftUI

/// One-line outdoor decision under Now. Not a Grok brief.
struct DecisionFeedCard: View {
  let sentence: String

  var body: some View {
    Text(sentence)
      .font(DesignTokens.Typography.headline())
      .foregroundStyle(DesignTokens.Palette.textPrimary)
      .fixedSize(horizontal: false, vertical: true)
      .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, DesignTokens.Spacing.space4)
      .padding(.vertical, DesignTokens.Spacing.space8)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("What to do now. \(sentence)")
      .accessibilityIdentifier(DayCastAccessibility.Today.decision)
  }
}
