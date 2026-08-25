import SwiftUI

/// Horizontal low–high temperature span for daily forecast rows.
struct DailyTempRangeBar: View {
  @Environment(WeatherStore.self) private var store

  let low: Double
  let high: Double
  /// Optional period bounds so today's segment can sit in context of the 10-day span.
  var periodLow: Double? = nil
  var periodHigh: Double? = nil

  private let barHeight: CGFloat = 8

  var body: some View {
    HStack(spacing: DesignTokens.Spacing.space8) {
      Text(store.formatTemperatureShort(low))
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textSecondary)
        .frame(width: 32, alignment: .trailing)
        .monospacedDigit()

      GeometryReader { geo in
        let width = geo.size.width
        ZStack(alignment: .leading) {
          Capsule()
            .fill(DesignTokens.Palette.cardStroke.opacity(0.65))
            .frame(height: barHeight)

          Capsule()
            .fill(
              LinearGradient(
                colors: [
                  DesignTokens.Palette.accentCool,
                  DesignTokens.Palette.accentWarm,
                ],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(width: max(barHeight, segmentWidth(in: width)), height: barHeight)
            .offset(x: segmentOrigin(in: width))
        }
        .frame(width: width, height: barHeight, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .center)
      }
      .frame(height: barHeight)
      .frame(maxWidth: .infinity)

      Text(store.formatTemperatureShort(high))
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .frame(width: 32, alignment: .leading)
        .monospacedDigit()
    }
  }

  private var resolvedPeriodLow: Double {
    periodLow ?? low
  }

  private var resolvedPeriodHigh: Double {
    max(periodHigh ?? high, resolvedPeriodLow + 0.1)
  }

  private func segmentOrigin(in width: CGFloat) -> CGFloat {
    let span = resolvedPeriodHigh - resolvedPeriodLow
    guard span > 0 else { return 0 }
    let start = CGFloat((low - resolvedPeriodLow) / span)
    return max(0, min(width - barHeight, start * width))
  }

  private func segmentWidth(in width: CGFloat) -> CGFloat {
    let span = resolvedPeriodHigh - resolvedPeriodLow
    guard span > 0 else { return width }
    let fraction = CGFloat((high - low) / span)
    return max(barHeight, min(width, fraction * width))
  }
}
