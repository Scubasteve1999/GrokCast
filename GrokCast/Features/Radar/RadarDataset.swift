import Foundation

/// Holds shared radar display helpers.
/// Live radar data model lives in RadarFrame + RadarTimeline (OpenWeatherMap provider).
struct RadarDataset {
  /// Shared local-time formatter for NOW radar labels (timeline scrubber + state header).
  static func displayTimeString(from date: Date) -> String {
    displayTimeFormatter.timeZone = .current
    return displayTimeFormatter.string(from: date)
  }

  private static let displayTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter
  }()
}
