import Foundation

/// Template day blurb for This Week / Daily. No Grok. No invented storms.
enum DailyOutlook {
  static func sentence(
    day: DailyForecast,
    unit: TemperatureUnit,
    calendar: Calendar,
    timeZone: TimeZone
  ) -> String {
    let condition = WeatherCondition(fromWMO: day.weatherCode)
    let weekday = heading(date: day.date, calendar: calendar, timeZone: timeZone)
    let sky = condition.displayText
    let high = unit.formatShort(day.high)
    let low = unit.formatShort(day.low)
    var line = "\(weekday) \(sky.lowercased()). High \(high), low \(low)."
    if day.precipChance >= 20 {
      let type = condition.rowPrecipTypeLabel(precipChance: day.precipChance).lowercased()
      line += " \(day.precipChance)% chance of \(type)."
    }
    return line
  }

  static func heading(date: Date, calendar: Calendar, timeZone: TimeZone) -> String {
    if calendar.isDateInToday(date) { return "Today" }
    return LocationTimezone.formatter(dateFormat: "EEE, MMM d", timeZone: timeZone)
      .string(from: date)
  }

  static func weekday(date: Date, calendar: Calendar, timeZone: TimeZone) -> String {
    if calendar.isDateInToday(date) { return "Today" }
    return LocationTimezone.formatter(dateFormat: "EEE", timeZone: timeZone)
      .string(from: date)
  }

  static func dayNumber(date: Date, timeZone: TimeZone) -> String {
    LocationTimezone.formatter(dateFormat: "d", timeZone: timeZone).string(from: date)
  }
}
