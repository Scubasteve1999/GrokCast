import SwiftUI

struct HourlyRowSkeleton: View {
  var isNow: Bool = false
  var layout: HourlyRowLayout = .standard

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
    VStack(spacing: DesignTokens.Spacing.space8) {
      ShimmerBlock(width: isNow ? 28 : 24, height: 11, cornerRadius: 3)
      ShimmerBlock(width: 24, height: 24, cornerRadius: 6)
      ShimmerBlock(width: 28, height: 15, cornerRadius: 4)
      ShimmerBlock(width: 32, height: 10, cornerRadius: 3)
    }
    .frame(width: DesignTokens.Figma.Metrics.hourlyChipWidth)
    .padding(.horizontal, DesignTokens.Spacing.space12)
    .padding(.vertical, DesignTokens.Spacing.space12)
    .background {
      RoundedRectangle(cornerRadius: DesignTokens.Figma.Metrics.chipRadius)
        .fill(
          isNow
            ? DesignTokens.Palette.cardElevated.opacity(0.92)
            : DesignTokens.Palette.cardBackground.opacity(0.55)
        )
    }
    .overlay {
      RoundedRectangle(cornerRadius: DesignTokens.Figma.Metrics.chipRadius)
        .stroke(
          isNow
            ? DesignTokens.Palette.accent.opacity(0.45)
            : DesignTokens.Palette.cardStroke,
          lineWidth: isNow ? 1.5 : DesignTokens.Card.strokeWidth
        )
    }
  }

  private var standardSkeleton: some View {
    VStack(spacing: DesignTokens.Spacing.space8) {
      ShimmerBlock(width: isNow ? 30 : 28, height: 14, cornerRadius: 3)
      ShimmerBlock(width: 32, height: 32, cornerRadius: 6)
      ShimmerBlock(width: 36, height: 22, cornerRadius: 4)
      ShimmerBlock(width: 46, height: 12, cornerRadius: 3)
      ShimmerBlock(width: 46, height: 5, cornerRadius: 2)
    }
    .frame(width: 88)
    .padding(.vertical, DesignTokens.Spacing.space16)
    .cardStyle(
      background: isNow
        ? DesignTokens.Palette.cardElevated : DesignTokens.Palette.cardBackground,
      stroke: isNow
        ? DesignTokens.Palette.accent.opacity(0.45) : DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadius
    )
  }
}
