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

  /// Storm-first glance: Now → Alerts → Next hour → Hourly → Daily, then secondaries.
  /// Do not reorder casually — personalization comes later.
  static let defaultOrder: [FeedItem] = [
    .now,
    .alerts,
    .precip,
    .hourly,
    .daily,
    .aiInsight,
    .radar,
    .fire,
    .airQuality,
    .sunMoon,
  ]

  var analyticsName: String { rawValue }
}

/// Today scrolling rows. Error banner is chrome above cards, not a `FeedItem`.
enum TodayFeedRow: Equatable, Identifiable {
  case errorBanner
  case item(FeedItem)

  var id: String {
    switch self {
    case .errorBanner: "errorBanner"
    case .item(let item): item.id
    }
  }
}
