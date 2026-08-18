import Foundation

/// Holds shared radar display helpers.
/// Live radar data model lives in RadarFrame + RadarTimeline (OpenWeatherMap provider).
struct RadarDataset {
  /// Clock label for a radar frame. City timezone — same source Hourly uses —
  /// so San Francisco does not read as the phone's 1:40 PM CDT.
  static func displayTimeString(from date: Date, timeZone: TimeZone) -> String {
    displayTimeFormatter.timeZone = timeZone
    return displayTimeFormatter.string(from: date)
  }

  private static let displayTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "h:mm a"
    return formatter
  }()
}
