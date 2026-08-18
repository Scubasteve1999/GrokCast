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
      case .standard:
        standardLayout
      case .figma:
        figmaLayout
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

  private var figmaLayout: some View {
    HStack(spacing: DesignTokens.Spacing.space12) {
      Text(dayLabel)
        .font(DesignTokens.Typography.body())
        .fontWeight(isToday ? .bold : .semibold)
        .foregroundStyle(
          isToday ? DesignTokens.Palette.textPrimary : DesignTokens.Palette.textSecondary
        )
        .lineLimit(1)
        .frame(width: 52, alignment: .leading)

      Image(systemName: rowSymbol)
        .font(DesignTokens.Typography.metric())
        .symbolRenderingMode(.multicolor)
        .frame(width: 28, alignment: .center)
        .accessibilityLabel(condition.displayText)

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
    .padding(.leading, DesignTokens.Spacing.space16)
    .padding(.trailing, DesignTokens.Spacing.space16)
    .padding(.vertical, DesignTokens.Spacing.space16)
    .cardStyle(
      background: isToday
        ? DesignTokens.Palette.cardElevated
        : DesignTokens.Palette.cardBackground,
      cornerRadius: DesignTokens.Layout.chipRadius,
      elevated: isToday
    )
    .overlay(alignment: .leading) {
      if isToday {
        UnevenRoundedRectangle(
          topLeadingRadius: DesignTokens.Layout.chipRadius,
          bottomLeadingRadius: DesignTokens.Layout.chipRadius,
          bottomTrailingRadius: 0,
          topTrailingRadius: 0
        )
        .fill(DesignTokens.Palette.accent)
        .frame(width: 3)
        .padding(.vertical, DesignTokens.Spacing.space8)
      }
    }
  }

  private var standardLayout: some View {
    HStack(alignment: .center, spacing: DesignTokens.Spacing.space16) {
      Text(dayLabel)
        .font(DesignTokens.Typography.headline())
        .foregroundStyle(
          isToday ? DesignTokens.Palette.textPrimary : DesignTokens.Palette.textSecondary
        )
        .lineLimit(1)
        .frame(width: 56, alignment: .leading)

      Image(systemName: rowSymbol)
        .font(DesignTokens.Typography.title())
        .symbolRenderingMode(.multicolor)
        .frame(width: 32, alignment: .center)
        .accessibilityLabel(condition.displayText)

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
      .frame(minWidth: 40, alignment: .trailing)
    }
    .padding(.vertical, DesignTokens.Spacing.space20)
    .padding(.horizontal, DesignTokens.Spacing.space20)
    .cardStyle(
      background: isToday
        ? DesignTokens.Palette.cardElevated : DesignTokens.Palette.cardBackground,
      stroke: isToday
        ? DesignTokens.Palette.accent.opacity(0.45) : DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadius
    )
    .overlay(alignment: .leading) {
      if isToday {
        UnevenRoundedRectangle(
          topLeadingRadius: DesignTokens.Card.cornerRadius,
          bottomLeadingRadius: DesignTokens.Card.cornerRadius,
          bottomTrailingRadius: 0,
          topTrailingRadius: 0
        )
        .fill(DesignTokens.Palette.accent)
        .frame(width: 4)
        .padding(.vertical, DesignTokens.Spacing.space12)
      }
    }
    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
  }
}
