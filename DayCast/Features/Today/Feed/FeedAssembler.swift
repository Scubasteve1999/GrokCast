import Foundation

enum FeedAssembler {
  /// Story-day teaser copy (not feed order): Next 2 Hours, official alerts, or Now is wet.
  static func isRadarStory(_ snapshot: FeedSnapshot) -> Bool {
    snapshot.hasPrecipContent || snapshot.showAlertsSlot || snapshot.isNowWet
  }

  /// Returns visible feed items in product order. Cards with no meaningful data
  /// are omitted. Empty alerts stay gone; the decision line and Next 2 Hours
  /// are not plates on this feed.
  static func items(from snapshot: FeedSnapshot) -> [FeedItem] {
    FeedItem.defaultOrder.filter { shouldShow($0, in: snapshot) }
  }

  /// Error/retry chrome plus cards. Banner sits above Now so a storm user sees it without scrolling.
  static func rows(items: [FeedItem], weatherError: String?) -> [TodayFeedRow] {
    var rows: [TodayFeedRow] = []
    if let weatherError, !weatherError.isEmpty {
      rows.append(.errorBanner)
    }
    rows.append(contentsOf: items.map(TodayFeedRow.item))
    return rows
  }

  static func shouldShow(_ item: FeedItem, in snapshot: FeedSnapshot) -> Bool {
    switch item {
    case .now:
      return snapshot.hasWeather
    case .alerts:
      return snapshot.showAlertsSlot
    case .decision, .precip:
      return false
    case .aiInsight:
      return false
    case .hourly:
      return snapshot.hasWeather && snapshot.hasHourly
    case .health:
      return snapshot.hasWeather
    case .yourNews:
      return snapshot.hasLocalBriefing
    case .radar:
      return snapshot.hasWeather
    case .daily:
      return snapshot.hasWeather && snapshot.hasDaily
    case .nearby:
      return snapshot.showFireCard
        || (snapshot.hasWeather && snapshot.hasSunriseOrSunset)
    }
  }
}
