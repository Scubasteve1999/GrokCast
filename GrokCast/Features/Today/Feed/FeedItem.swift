import Foundation

/// Ordered home-feed slots. Visibility is decided by `FeedAssembler` from a `FeedSnapshot`.
enum FeedItem: String, CaseIterable, Identifiable, Sendable {
  case now
  case alerts
  case aiInsight
  case hourly
  case radar
  case daily
  case fire
  case airQuality
  case precip
  case sunMoon

  var id: String { rawValue }

  /// Product default order (TWC-style). Do not reorder casually — personalization comes later.
  static let defaultOrder: [FeedItem] = [
    .now,
    .alerts,
    .aiInsight,
    .hourly,
    .radar,
    .daily,
    .fire,
    .airQuality,
    .precip,
    .sunMoon,
  ]

  var analyticsName: String { rawValue }
}
