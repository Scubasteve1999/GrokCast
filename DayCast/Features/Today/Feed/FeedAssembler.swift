import Foundation

enum FeedAssembler {
  /// Returns visible feed items in product order. Cards with no meaningful data are omitted.
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
      return snapshot.alertCount > 0
    case .aiInsight:
      return snapshot.hasWeather && snapshot.showAIInsight
    case .hourly:
      return snapshot.hasWeather && snapshot.hasHourly
    case .radar:
      return snapshot.hasWeather
    case .daily:
      return snapshot.hasWeather && snapshot.hasDaily
    case .fire:
      return snapshot.showFireCard
    case .airQuality:
      return snapshot.hasWeather && snapshot.hasAQI
    case .precip:
      return snapshot.hasWeather && snapshot.hasPrecipContent
    case .sunMoon:
      return snapshot.hasWeather && snapshot.hasSunriseOrSunset
    }
  }
}
