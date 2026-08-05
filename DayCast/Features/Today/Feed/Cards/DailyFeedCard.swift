import SwiftUI

struct DailyFeedCard: View {
  let weather: DayCastWeather
  @State private var expandedDayID: Date?

  private var days: [DailyForecast] {
    Array(weather.daily.prefix(10))
  }

  private var periodLow: Double? { days.map(\.low).min() }
  private var periodHigh: Double? { days.map(\.high).max() }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      Text("Daily")
        .font(DesignTokens.Figma.Typography.subsectionLabel)
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .tracking(DesignTokens.Typography.cardLabelTracking)

      VStack(spacing: DesignTokens.Spacing.space8) {
        ForEach(days) { day in
          VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
            DailyRow(
              forecast: day,
              layout: .figma,
              periodLow: periodLow,
              periodHigh: periodHigh,
              calendar: weather.locationCalendar,
              timeZone: weather.locationTimeZone,
              onSelect: {
                withAnimation(.easeInOut(duration: 0.2)) {
                  if expandedDayID == day.id {
                    expandedDayID = nil
                  } else {
                    expandedDayID = day.id
                  }
                }
                Analytics.track(.feedCardTap, parameters: ["card": "daily_row"])
              }
            )

            if expandedDayID == day.id {
              dailyExpandedDetail(day)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
          }
        }
      }
    }
    .padding(DesignTokens.Spacing.space16)
    .cardStyle()
    .accessibilityElement(children: .contain)
  }

  @ViewBuilder
  private func dailyExpandedDetail(_ day: DailyForecast) -> some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
      if let uv = day.uvMax {
        Text("UV max \(Int(round(uv)))")
          .font(.caption)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      }
      let liq = (day.rainSum ?? 0) + (day.showersSum ?? 0)
      let sn = day.snowfallSum ?? 0
      if liq > 0 || sn > 0 {
        Text(precipDetail(liquid: liq, snow: sn))
          .font(.caption)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      }
      Text("\(day.precipChance)% chance of precipitation")
        .font(.caption)
        .foregroundStyle(DesignTokens.Palette.textSecondary)
    }
    .padding(.horizontal, DesignTokens.Spacing.space16)
    .padding(.bottom, DesignTokens.Spacing.space8)
  }

  private func precipDetail(liquid: Double, snow: Double) -> String {
    if snow > 0.05 {
      return String(format: "Snow %.1f in", snow)
    }
    if liquid > 0.01 {
      return String(format: "Rain %.2f in", liquid)
    }
    return "Little or no accumulation"
  }
}
