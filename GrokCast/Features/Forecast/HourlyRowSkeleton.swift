import SwiftUI

struct HourlyRowSkeleton: View {
  var isNow: Bool = false

  var body: some View {
    VStack(spacing: 9) {
      // Time / Now placeholder
      ShimmerBlock(width: isNow ? 30 : 28, height: 14, cornerRadius: 3)

      // Icon area
      ShimmerBlock(width: 32, height: 32, cornerRadius: 6)

      // Temperature
      ShimmerBlock(width: 36, height: 22, cornerRadius: 4)

      // Precip + bar placeholder
      ShimmerBlock(width: 46, height: 12, cornerRadius: 3)
      ShimmerBlock(width: 46, height: 5, cornerRadius: 2)
    }
    .frame(width: 88)
    .padding(.vertical, DesignTokens.Spacing.space16)
    .cardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadius
    )
  }
}
