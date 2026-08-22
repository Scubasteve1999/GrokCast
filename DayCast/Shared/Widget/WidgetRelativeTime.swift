import Foundation

/// Shared relative freshness labels for Today + widget surfaces.
enum WidgetRelativeTime {
  /// Widgets dim and Today treats Open-Meteo as stale after this age.
  static let staleThreshold: TimeInterval = 3 * 3600

  static func isStale(_ fetchedAt: Date, relativeTo now: Date = Date()) -> Bool {
    now.timeIntervalSince(fetchedAt) > staleThreshold
  }

  /// Minute granularity is used until the 3h stale boundary (180m) so labels stay precise
  /// while data is considered fresh; at ≥180m, hour labels apply until `isStale` takes over.
  static func updatedLabel(for fetchedAt: Date, relativeTo now: Date = Date()) -> String {
    let interval = max(0, now.timeIntervalSince(fetchedAt))
    if interval < 60 {
      return "Updated just now"
    }
    let minutes = Int(interval / 60)
    if minutes < 180 {
      return "Updated \(minutes)m ago"
    }
    let hours = Int(interval / 3600)
    return "Updated \(hours)h ago"
  }
}
