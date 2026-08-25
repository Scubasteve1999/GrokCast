import SwiftUI

enum DailyRowLayout {
  /// Full row with temp range bar and precip details.
  case standard
  /// Figma Forecast screen: day, icon, high/low temps.
  case figma
}

struct DailyRow: View {
  let forecast: DailyForecast
  var layout: DailyRowLayout = .standard
  /// 10-day period bounds for positioning the temp range segment (presentation only).
  var periodLow: Double? = nil
  var periodHigh: Double? = nil
  /// Location calendar for "Today" / weekday (defaults to device).
  var calendar: Calendar = .current
  var timeZone: TimeZone = .current
  /// Opens day detail when set (Forecast tap-through).
  var onSelect: (() -> Void)? = nil

  private var condition: WeatherCondition {
    WeatherCondition(fromWMO: forecast.weatherCode)
  }

  private var rowSymbol: String {
    condition.rowSymbolName(precipChance: forecast.precipChance)
  }

  private var isToday: Bool {
    calendar.isDateInToday(forecast.date)
  }

  private var dayLabel: String {
    if isToday { return "Today" }
    return LocationTimezone.formatter(dateFormat: "EEE", timeZone: timeZone)
      .string(from: forecast.date)
  }

  var body: some View {
    Group {
      switch layout {
      case .standard, .figma:
        quietLayout
      }
    }
    .contentShape(Rectangle())
    .onTapGesture {
      guard let onSelect else { return }
      Haptic.selection()
      onSelect()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(rowAccessibilityLabel)
    .accessibilityAddTraits(onSelect == nil ? [] : .isButton)
    .accessibilityHint(onSelect == nil ? "" : "Opens day details")
  }

  /// One VoiceOver string for the whole row. Children stay visual-only.
  var rowAccessibilityLabel: String {
    Self.accessibilityLabel(
      day: dayLabel,
      condition: condition.displayText,
      high: Int(round(forecast.high)),
      low: Int(round(forecast.low)),
      precipChance: forecast.precipChance
    )
  }

  static func accessibilityLabel(
    day: String,
    condition: String,
    high: Int,
    low: Int,
    precipChance: Int
  ) -> String {
    var label = "\(day), \(condition). High \(high) degrees, low \(low) degrees"
    if precipChance > 0 {
      label += ". \(precipChance) percent chance of precipitation"
    }
    return label
  }

  /// One table row. The parent plate owns chrome. `layout` is unused for drawing.
  private var quietLayout: some View {
    HStack(spacing: DesignTokens.Spacing.space12) {
      Text(dayLabel)
        .font(DesignTokens.Typography.body())
        .fontWeight(isToday ? .semibold : .regular)
        .foregroundStyle(
          isToday ? DesignTokens.Palette.textPrimary : DesignTokens.Palette.textSecondary
        )
        .lineLimit(1)
        .frame(width: 52, alignment: .leading)

      Image(systemName: rowSymbol)
        .font(DesignTokens.Typography.symbol(16))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(DesignTokens.Palette.textSecondary)
        .frame(width: 22, alignment: .center)
        .accessibilityHidden(true)

      DailyTempRangeBar(
        low: forecast.low,
        high: forecast.high,
        periodLow: periodLow,
        periodHigh: periodHigh
      )
      .frame(maxWidth: .infinity)

      Group {
        if forecast.precipChance > 0 {
          Text("\(forecast.precipChance)%")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.accentCool)
            .monospacedDigit()
        } else {
          Text("—")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
      }
      .frame(width: 40, alignment: .trailing)
    }
    .padding(.vertical, DesignTokens.Spacing.space12)
  }
}
