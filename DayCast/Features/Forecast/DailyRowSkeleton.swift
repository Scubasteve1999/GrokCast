import SwiftUI

struct DailyRowSkeleton: View {
  var layout: DailyRowLayout = .standard
  var isToday: Bool = false

  var body: some View {
    let _ = layout
    HStack(spacing: DesignTokens.Spacing.space12) {
      ShimmerBlock(width: isToday ? 40 : 28, height: 14, cornerRadius: 4)
        .frame(width: 52, alignment: .leading)
      ShimmerBlock(width: 16, height: 16, cornerRadius: 4)
        .frame(width: 22)
      ShimmerBlock(width: nil, height: 8, cornerRadius: 4)
        .frame(maxWidth: .infinity)
      ShimmerBlock(width: 28, height: 12, cornerRadius: 3)
        .frame(width: 40, alignment: .trailing)
    }
    .padding(.vertical, DesignTokens.Spacing.space12)
  }
}
