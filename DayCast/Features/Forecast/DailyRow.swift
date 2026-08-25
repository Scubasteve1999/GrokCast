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
  /// Current temperature for the Today-row tick. Ignored on other days.
  var nowTemperature: Double? = nil
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
    Self.dayHeading(date: forecast.date, isToday: isToday, timeZone: timeZone)
  }

  private var weekdayLabel: String {
    if isToday { return "Today" }
    return LocationTimezone.formatter(dateFormat: "EEE", timeZone: timeZone)
      .string(from: forecast.date)
  }

  private var dayNumberLabel: String? {
    Self.dayNumber(date: forecast.date, isToday: isToday, timeZone: timeZone)
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

  static func dayHeading(date: Date, isToday: Bool, timeZone: TimeZone) -> String {
    if isToday { return "Today" }
    let weekday = LocationTimezone.formatter(dateFormat: "EEE", timeZone: timeZone)
      .string(from: date)
    if let number = dayNumber(date: date, isToday: false, timeZone: timeZone) {
      return "\(weekday) \(number)"
    }
    return weekday
  }

  static func dayNumber(date: Date, isToday: Bool, timeZone: TimeZone) -> String? {
    if isToday { return nil }
    return LocationTimezone.formatter(dateFormat: "d", timeZone: timeZone).string(from: date)
  }

  static func precipEmphasis(_ chance: Int) -> DailyPrecipEmphasis {
    DailyPrecipEmphasis.forChance(chance)
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
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text(weekdayLabel)
          .font(DesignTokens.Typography.body())
          .fontWeight(isToday ? .semibold : .regular)
          .foregroundStyle(
            isToday ? DesignTokens.Palette.textPrimary : DesignTokens.Palette.textSecondary
          )
          .lineLimit(1)
        if let dayNumberLabel {
          Text(dayNumberLabel)
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
            .monospacedDigit()
            .lineLimit(1)
        }
      }
      .frame(width: DailyRow.dayColumnWidth, alignment: .leading)

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
        periodHigh: periodHigh,
        nowTemperature: isToday ? nowTemperature : nil
      )
      .frame(maxWidth: .infinity)

      Group {
        if forecast.precipChance > 0 {
          let emphasis = Self.precipEmphasis(forecast.precipChance)
          Text("\(forecast.precipChance)%")
            .font(DesignTokens.Typography.caption())
            .fontWeight(emphasis.weight)
            .foregroundStyle(emphasis.color)
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

  static let dayColumnWidth: CGFloat = 72
}

enum DailyPrecipEmphasis: Equatable {
  /// 0 — em dash, tertiary.
  case none
  /// 1–19 — noise. Tertiary, regular.
  case quiet
  /// 20–49 — worth showing. Accent, regular.
  case notable
  /// 50+ — a real storm day. Accent, semibold.
  case high

  static func forChance(_ chance: Int) -> DailyPrecipEmphasis {
    if chance <= 0 { return .none }
    if chance < 20 { return .quiet }
    if chance >= 50 { return .high }
    return .notable
  }

  var color: Color {
    switch self {
    case .none, .quiet: return DesignTokens.Palette.textTertiary
    case .notable, .high: return DesignTokens.Palette.accentCool
    }
  }

  var weight: Font.Weight {
    switch self {
    case .high: return .semibold
    case .none, .quiet, .notable: return .regular
    }
  }
}
