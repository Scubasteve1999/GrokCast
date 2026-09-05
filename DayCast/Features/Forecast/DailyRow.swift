import SwiftUI

/// Day-column and VoiceOver helpers for daily chips / skeleton. The old
/// `DailyRow` table view is gone; Forecast uses `WeekDayChipStrip`.
enum DailyRow {
  static let dayColumnWidth: CGFloat = 72

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

enum DailyTempRangeBarLayout {
  static let barHeight: CGFloat = 5
}
