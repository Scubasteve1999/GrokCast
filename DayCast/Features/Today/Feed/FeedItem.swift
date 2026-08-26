import Foundation

/// Ordered home-feed slots. Visibility is decided by `FeedAssembler` from a `FeedSnapshot`.
enum FeedItem: String, CaseIterable, Identifiable, Sendable {
  case now
  case alerts
  case decision
  case aiInsight
  case hourly
  case health
  case yourNews
  case radar
  case daily
  case precip
  case nearby

  var id: String { rawValue }

  /// Type-on-photo Now, then alert chip (when live), tonight + curve, Site
  /// Doppler, Your News, conditions, week, nearby. Take / Imagine live under
  /// More (Sky Check), not this feed.
  static let defaultOrder: [FeedItem] = [
    .now,
    .alerts,
    .hourly,
    .radar,
    .yourNews,
    .health,
    .daily,
    .nearby,
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
