import SwiftUI

struct DailyRowSkeleton: View {
  var layout: DailyRowLayout = .standard
  var isToday: Bool = false

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
      ShimmerBlock(width: isToday ? 40 : 28, height: 15, cornerRadius: 4)
        .frame(width: 52, alignment: .leading)
      ShimmerBlock(width: 22, height: 22, cornerRadius: 6)
        .frame(width: 28)
      ShimmerBlock(width: nil, height: 8, cornerRadius: 4)
        .frame(maxWidth: .infinity)
      ShimmerBlock(width: 36, height: 12, cornerRadius: 4)
        .frame(width: 56, alignment: .trailing)
    }
    .padding(.vertical, DesignTokens.Spacing.space16)
    .padding(.horizontal, DesignTokens.Spacing.space16)
    .background {
      RoundedRectangle(cornerRadius: DesignTokens.Figma.Metrics.chipRadius)
        .fill(
          isToday
            ? DesignTokens.Palette.cardElevated.opacity(0.95)
            : DesignTokens.Palette.cardBackground.opacity(0.55)
        )
    }
    .overlay(alignment: .leading) {
      if isToday {
        UnevenRoundedRectangle(
          topLeadingRadius: DesignTokens.Figma.Metrics.chipRadius,
          bottomLeadingRadius: DesignTokens.Figma.Metrics.chipRadius,
          bottomTrailingRadius: 0,
          topTrailingRadius: 0
        )
        .fill(DesignTokens.Palette.accent.opacity(0.7))
        .frame(width: 3)
        .padding(.vertical, DesignTokens.Spacing.space8)
      }
    }
    .overlay {
      RoundedRectangle(cornerRadius: DesignTokens.Figma.Metrics.chipRadius)
        .stroke(
          isToday
            ? DesignTokens.Palette.accent.opacity(0.35)
            : DesignTokens.Palette.cardStroke,
          lineWidth: DesignTokens.Card.strokeWidth
        )
    }
  }

  private var standardSkeleton: some View {
    HStack(spacing: DesignTokens.Spacing.space16) {
      ShimmerBlock(width: isToday ? 44 : 46, height: 18, cornerRadius: 4)
        .frame(width: 56, alignment: .leading)

      ShimmerBlock(width: 28, height: 28, cornerRadius: 6)
        .frame(width: 32)

      ShimmerBlock(width: nil, height: 8, cornerRadius: 4)
        .frame(maxWidth: .infinity)

      ShimmerBlock(width: 46, height: 13, cornerRadius: 3)
        .frame(minWidth: 52, alignment: .trailing)
    }
    .padding(.vertical, DesignTokens.Spacing.space16)
    .padding(.horizontal, DesignTokens.Spacing.space16)
    .cardStyle(
      background: isToday
        ? DesignTokens.Palette.cardElevated : DesignTokens.Palette.cardBackground,
      stroke: isToday
        ? DesignTokens.Palette.accent.opacity(0.4) : DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadius
    )
  }
}
