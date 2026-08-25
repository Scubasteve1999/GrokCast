import Foundation

/// Ordered home-feed slots. Visibility is decided by `FeedAssembler` from a `FeedSnapshot`.
enum FeedItem: String, CaseIterable, Identifiable, Sendable {
  case now
  case alerts
  case aiInsight
  case hourly
  case yourNews
  case radar
  case daily
  case fire
  case airQuality
  case precip
  case sunMoon

  var id: String { rawValue }

  /// Calm-day spine: Now → Alerts → Next hour → Hourly → Your News → Daily, then secondaries.
  /// Story days hoist `.radar` after Next hour via `FeedAssembler` — do not restack this list.
  static let defaultOrder: [FeedItem] = [
    .now,
    .alerts,
    .precip,
    .hourly,
    .yourNews,
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
