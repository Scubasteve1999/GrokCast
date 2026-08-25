import Foundation

enum FeedAssembler {
  /// Next hour is showing, alerts/outlook slot is showing, or Now is wet.
  static func isRadarStory(_ snapshot: FeedSnapshot) -> Bool {
    snapshot.hasPrecipContent || snapshot.showAlertsSlot || snapshot.isNowWet
  }

  /// Returns visible feed items in product order. Cards with no meaningful data are omitted.
  /// Calm days keep `defaultOrder` (radar buried below Daily). Story days hoist radar
  /// after Now / Alerts / Next hour — they do not rewrite the calm spine.
  static func items(from snapshot: FeedSnapshot) -> [FeedItem] {
    var visible = FeedItem.defaultOrder.filter { shouldShow($0, in: snapshot) }
    guard isRadarStory(snapshot), let radarAt = visible.firstIndex(of: .radar) else {
      return visible
    }
    visible.remove(at: radarAt)
    let anchor: FeedItem? = {
      if visible.contains(.precip) { return .precip }
      if visible.contains(.alerts) { return .alerts }
      if visible.contains(.now) { return .now }
      return nil
    }()
    if let anchor, let idx = visible.firstIndex(of: anchor) {
      visible.insert(.radar, at: idx + 1)
    } else {
      visible.insert(.radar, at: 0)
    }
    return visible
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
    case .aiInsight:
      return snapshot.hasWeather && snapshot.showAIInsight
    case .hourly:
      return snapshot.hasWeather && snapshot.hasHourly
    case .yourNews:
      return snapshot.hasLocalBriefing
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
