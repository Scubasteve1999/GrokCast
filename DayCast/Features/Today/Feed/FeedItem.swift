import Foundation

/// Ordered home-feed slots. Visibility is decided by `FeedAssembler` from a `FeedSnapshot`.
enum FeedItem: String, CaseIterable, Identifiable, Sendable {
  case now
  case alerts
  case hourly
  case health
  case yourNews
  case radar
  case daily
  case nearby

  var id: String { rawValue }

  /// Type-on-photo Now, then alert chip (when live), tonight + curve, Site
  /// Doppler, Your News, elevated Conditions, week, fire Nearby. Take /
  /// Imagine live under More (Sky Check), not this feed.
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

/// Today scrolling rows. Error banner and honesty strip are chrome, not `FeedItem`s.
enum TodayFeedRow: Equatable, Identifiable {
  case errorBanner
  case honestyStrip
  case item(FeedItem)

  var id: String {
    switch self {
    case .errorBanner: "errorBanner"
    case .honestyStrip: "honestyStrip"
    case .item(let item): item.id
    }
  }
}
