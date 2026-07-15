import SwiftUI

struct DailyRowSkeleton: View {
    var body: some View {
        HStack {
            ShimmerBlock(width: 40, height: 16, cornerRadius: 4)
                .frame(width: 52, alignment: .leading)

            ShimmerBlock(width: 24, height: 24, cornerRadius: 6)
                .frame(width: 28)

            Spacer()

            ShimmerBlock(width: 32, height: 12, cornerRadius: 3)

            HStack(spacing: 10) {
                ShimmerBlock(width: 28, height: 16, cornerRadius: 4)
                ShimmerBlock(width: 28, height: 16, cornerRadius: 4)
            }
            .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}
