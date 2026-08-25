import SwiftUI

/// Horizontal This Week / Daily chips. Selected day is a quiet rounded plate.
struct WeekDayChipStrip: View {
  let days: [DailyForecast]
  var selectedID: Date?
  var calendar: Calendar = .current
  var timeZone: TimeZone = .current
  var unit: TemperatureUnit = .fahrenheit
  var periodLow: Double?
  var periodHigh: Double?
  var onSelect: (DailyForecast) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(alignment: .top, spacing: DesignTokens.Spacing.space8) {
        ForEach(days) { day in
          chip(day)
        }
      }
    }
  }

  private func chip(_ day: DailyForecast) -> some View {
    let selected = selectedID == day.id
    let condition = WeatherCondition(fromWMO: day.weatherCode)
    let precip = DailyPrecipEmphasis.forChance(day.precipChance)
    return Button {
      Haptic.selection()
      onSelect(day)
    } label: {
      VStack(spacing: DesignTokens.Spacing.space4) {
        Text(DailyOutlook.weekday(date: day.date, calendar: calendar, timeZone: timeZone))
          .font(DesignTokens.Typography.caption())
          .fontWeight(selected ? .semibold : .regular)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .lineLimit(1)
        Text(DailyOutlook.dayNumber(date: day.date, timeZone: timeZone))
          .font(DesignTokens.Typography.callout())
          .fontWeight(.semibold)
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .monospacedDigit()
        Image(systemName: condition.rowSymbolName(precipChance: day.precipChance))
          .font(DesignTokens.Typography.symbol(18))
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .frame(height: 22)
          .accessibilityHidden(true)
        Text(unit.formatShort(day.high))
          .font(DesignTokens.Typography.callout())
          .fontWeight(.medium)
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .monospacedDigit()
        WeekChipRangeBar(
          low: day.low,
          high: day.high,
          periodLow: periodLow ?? day.low,
          periodHigh: periodHigh ?? day.high
        )
        Text(unit.formatShort(day.low))
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .monospacedDigit()
        if day.precipChance >= 20 {
          Text("\(day.precipChance)%")
            .font(DesignTokens.Typography.caption())
            .fontWeight(precip.weight)
            .foregroundStyle(precip.color)
            .monospacedDigit()
        } else {
          Text(" ")
            .font(DesignTokens.Typography.caption())
        }
      }
      .frame(width: 56)
      .padding(.vertical, DesignTokens.Spacing.space8)
      .background(
        RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
          .fill(selected ? DesignTokens.Palette.cardBackground.opacity(0.9) : Color.clear)
      )
      .overlay(
        RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
          .stroke(
            selected ? DesignTokens.Palette.cardHairline : Color.clear,
            lineWidth: DesignTokens.Card.strokeWidth
          )
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      DailyRow.accessibilityLabel(
        day: DailyOutlook.heading(date: day.date, calendar: calendar, timeZone: timeZone),
        condition: condition.displayText,
        high: Int(round(day.high)),
        low: Int(round(day.low)),
        precipChance: day.precipChance
      )
    )
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

private struct WeekChipRangeBar: View {
  let low: Double
  let high: Double
  let periodLow: Double
  let periodHigh: Double

  var body: some View {
    GeometryReader { proxy in
      let span = max(periodHigh - periodLow, 1)
      let height = proxy.size.height
      let lo = CGFloat((low - periodLow) / span)
      let hi = CGFloat((high - periodLow) / span)
      let top = (1 - hi) * height
      let bar = max((hi - lo) * height, 6)
      Capsule()
        .fill(DesignTokens.Palette.cardStroke)
        .overlay(alignment: .top) {
          Capsule()
            .fill(DesignTokens.Palette.textPrimary.opacity(0.85))
            .frame(height: bar)
            .offset(y: top)
        }
    }
    .frame(width: 4, height: 28)
  }
}
