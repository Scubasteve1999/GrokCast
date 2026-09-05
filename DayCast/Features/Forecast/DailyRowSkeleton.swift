import SwiftUI

struct DailyRowSkeleton: View {
  var isToday: Bool = false

  var body: some View {
    HStack(spacing: DesignTokens.Spacing.space12) {
      ShimmerBlock(width: isToday ? 40 : 36, height: 14, cornerRadius: 4)
        .frame(width: DailyRow.dayColumnWidth, alignment: .leading)
      ShimmerBlock(width: 16, height: 16, cornerRadius: 4)
        .frame(width: 22)
      ShimmerBlock(width: nil, height: DailyTempRangeBarLayout.barHeight, cornerRadius: 2.5)
        .frame(maxWidth: .infinity)
      ShimmerBlock(width: 28, height: 12, cornerRadius: 3)
        .frame(width: 40, alignment: .trailing)
    }
    .padding(.vertical, DesignTokens.Spacing.space12)
  }
}
