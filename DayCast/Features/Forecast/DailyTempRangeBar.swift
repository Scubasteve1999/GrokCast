import SwiftUI

enum DailyTempRangeBarLayout {
  static let barHeight: CGFloat = 5
  static let tickWidth: CGFloat = 1
  static let tickHeight: CGFloat = 9

  static func periodHigh(periodLow: Double, periodHigh: Double?, high: Double) -> Double {
    max(periodHigh ?? high, periodLow + 0.1)
  }

  static func x(
    for value: Double, periodLow: Double, periodHigh: Double, width: CGFloat
  ) -> CGFloat {
    let span = periodHigh - periodLow
    guard span > 0, width > 0 else { return 0 }
    let t = CGFloat((value - periodLow) / span)
    return max(0, min(width - tickWidth, t * width))
  }

  static func segmentOrigin(
    low: Double, periodLow: Double, periodHigh: Double, width: CGFloat
  ) -> CGFloat {
    let start = x(for: low, periodLow: periodLow, periodHigh: periodHigh, width: width)
    return max(0, min(width - barHeight, start))
  }

  static func segmentWidth(
    low: Double, high: Double, periodLow: Double, periodHigh: Double, width: CGFloat
  ) -> CGFloat {
    let span = periodHigh - periodLow
    guard span > 0 else { return width }
    let fraction = CGFloat((high - low) / span)
    return max(barHeight, min(width, fraction * width))
  }
}

/// Horizontal low–high temperature span for daily forecast rows.
struct DailyTempRangeBar: View {
  @Environment(WeatherStore.self) private var store

  let low: Double
  let high: Double
  /// Optional period bounds so today's segment can sit in context of the 10-day span.
  var periodLow: Double? = nil
  var periodHigh: Double? = nil
  /// Today-row only. 1pt tick at the current temperature on the 10-day scale.
  var nowTemperature: Double? = nil

  private var barHeight: CGFloat { DailyTempRangeBarLayout.barHeight }

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
            .frame(width: segmentWidth(in: width), height: barHeight)
            .offset(x: segmentOrigin(in: width))

          if let nowTemperature {
            Rectangle()
              .fill(DesignTokens.Palette.textPrimary)
              .frame(
                width: DailyTempRangeBarLayout.tickWidth,
                height: DailyTempRangeBarLayout.tickHeight
              )
              .offset(x: tickX(now: nowTemperature, width: width))
          }
        }
        .frame(width: width, height: DailyTempRangeBarLayout.tickHeight, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .center)
      }
      .frame(height: DailyTempRangeBarLayout.tickHeight)
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
    DailyTempRangeBarLayout.periodHigh(
      periodLow: resolvedPeriodLow, periodHigh: periodHigh, high: high)
  }

  private func segmentOrigin(in width: CGFloat) -> CGFloat {
    DailyTempRangeBarLayout.segmentOrigin(
      low: low, periodLow: resolvedPeriodLow, periodHigh: resolvedPeriodHigh, width: width)
  }

  private func segmentWidth(in width: CGFloat) -> CGFloat {
    DailyTempRangeBarLayout.segmentWidth(
      low: low, high: high, periodLow: resolvedPeriodLow, periodHigh: resolvedPeriodHigh,
      width: width)
  }

  private func tickX(now: Double, width: CGFloat) -> CGFloat {
    DailyTempRangeBarLayout.x(
      for: now, periodLow: resolvedPeriodLow, periodHigh: resolvedPeriodHigh, width: width)
  }
}
