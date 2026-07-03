import SwiftUI

/// Horizontal low–high temperature span for daily forecast rows.
struct DailyTempRangeBar: View {
  @Environment(WeatherStore.self) private var store

  let low: Double
  let high: Double

  var body: some View {
    HStack(spacing: 4) {
      Text(store.formatTemperatureShort(low))
        .font(.caption2)
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .frame(width: 28, alignment: .trailing)
        .monospacedDigit()

      Capsule()
        .fill(
          LinearGradient(
            colors: [DesignTokens.Palette.accentCool, DesignTokens.Palette.accentWarm],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .frame(width: 52, height: 5)
        .overlay {
          Capsule()
            .stroke(DesignTokens.Palette.cardStroke.opacity(0.5), lineWidth: 0.5)
        }

      Text(store.formatTemperatureShort(high))
        .font(.caption2.weight(.semibold))
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .frame(width: 28, alignment: .leading)
        .monospacedDigit()
    }
  }
}
