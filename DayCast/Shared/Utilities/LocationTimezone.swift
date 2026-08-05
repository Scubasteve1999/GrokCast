import Foundation

/// Location-aware calendar / formatter helpers for weather display.
/// Prefer these over `Calendar.current` when labeling a remote city's forecast.
enum LocationTimezone {
  static func timeZone(for identifier: String?) -> TimeZone {
    identifier.flatMap { TimeZone(identifier: $0) } ?? .current
  }

  static func calendar(for identifier: String?) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone(for: identifier)
    return calendar
  }

  static func formatter(dateFormat: String, timeZone: TimeZone) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = dateFormat
    formatter.timeZone = timeZone
    return formatter
  }
}
