import SwiftUI

struct HourlyRowSkeleton: View {
    var isNow: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            // Time / Now placeholder
            ShimmerBlock(width: isNow ? 32 : 28, height: 12, cornerRadius: 3)

            // Icon area
            ShimmerBlock(width: 32, height: 32, cornerRadius: 6)

            // Temperature
            ShimmerBlock(width: 28, height: 18, cornerRadius: 4)

            // Precip chance placeholder
            ShimmerBlock(width: 20, height: 10, cornerRadius: 3)
        }
        .frame(width: 52)
    }
}
