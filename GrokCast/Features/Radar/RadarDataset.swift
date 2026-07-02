import Foundation

/// Holds shared radar display helpers.
/// Live radar data model lives in RadarFrame + RadarTimeline (OpenWeatherMap provider).
struct RadarDataset {
  /// Shared local-time formatter for NOW radar labels (timeline scrubber + state header).
  static func displayTimeString(from date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: date)
  }
}
