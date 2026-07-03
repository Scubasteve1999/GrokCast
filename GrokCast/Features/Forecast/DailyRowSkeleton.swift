import SwiftUI

struct DailyRowSkeleton: View {
  var layout: DailyRowLayout = .standard

  var body: some View {
    Group {
      switch layout {
      case .standard:
        standardSkeleton
      case .figma:
        figmaSkeleton
      }
    }
  }

  private var figmaSkeleton: some View {
    HStack(spacing: DesignTokens.Spacing.space12) {
      ShimmerBlock(width: 28, height: 15, cornerRadius: 4)
      ShimmerBlock(width: 22, height: 22, cornerRadius: 6)
      ShimmerBlock(width: 28, height: 15, cornerRadius: 4)
      ShimmerBlock(width: 28, height: 15, cornerRadius: 4)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, DesignTokens.Spacing.space12)
    .padding(.horizontal, DesignTokens.Spacing.space16)
    .cardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadiusCompact
    )
  }

  private var standardSkeleton: some View {
    HStack {
      ShimmerBlock(width: 46, height: 18, cornerRadius: 4)
        .frame(width: 56, alignment: .leading)

      ShimmerBlock(width: 28, height: 28, cornerRadius: 6)
        .frame(width: 32)

      Spacer()

      HStack(spacing: 16) {
        HStack(spacing: 12) {
          ShimmerBlock(width: 36, height: 22, cornerRadius: 4)
          ShimmerBlock(width: 30, height: 18, cornerRadius: 4)
        }
        .monospacedDigit()

        // Precip placeholder (always present)
        ShimmerBlock(width: 46, height: 13, cornerRadius: 3)
      }
    }
    .padding(.vertical, DesignTokens.Spacing.space16)
    .padding(.horizontal, DesignTokens.Spacing.space16)
    .cardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadius
    )
  }
}
