import Foundation

enum FeedAssembler {
  /// Story-day teaser paint (not feed order): Next 2 Hours, radar-relevant
  /// warning/watch, or Now is wet. Heat / air-quality advisories still earn
  /// the Alerts card via `showAlertsSlot` but do not hoist Site Doppler.
  static func isRadarStory(_ snapshot: FeedSnapshot) -> Bool {
    snapshot.hasPrecipContent || snapshot.hasRadarRelevantAlert || snapshot.isNowWet
  }

  /// Returns visible feed items in product order. Cards with no meaningful data
  /// are omitted.
  static func items(from snapshot: FeedSnapshot) -> [FeedItem] {
    FeedItem.defaultOrder.filter { shouldShow($0, in: snapshot) }
  }

  /// Error/retry chrome plus cards. Banner sits above Now so a storm user sees it without scrolling.
  /// Standalone honesty strip is calm-only (WFO). Watch/warning copy lives on the Alerts chip.
  /// Forecast-era notice is a separate seasonal caption — not the WFO second line.
  static func rows(
    items: [FeedItem],
    weatherError: String?,
    showsStandaloneHonestyStrip: Bool = false,
    showsForecastEraNotice: Bool = false
  ) -> [TodayFeedRow] {
    var rows: [TodayFeedRow] = []
    if let weatherError, !weatherError.isEmpty {
      rows.append(.errorBanner)
    }
    for item in items {
      rows.append(.item(item))
      if item == .now, showsStandaloneHonestyStrip {
        rows.append(.honestyStrip)
      }
    }
    if showsForecastEraNotice {
      insertForecastEraNotice(into: &rows)
    }
    return rows
  }

  /// Calm: directly under the WFO strip (hero, 20pt). Story day: after Your News
  /// so the iPhone 16 first viewport still peeks a news card.
  static func insertForecastEraNotice(into rows: inout [TodayFeedRow]) {
    if let idx = rows.firstIndex(of: .honestyStrip) {
      rows.insert(.forecastEraNotice, at: idx + 1)
      return
    }
    if let idx = rows.firstIndex(of: .item(.yourNews)) {
      rows.insert(.forecastEraNotice, at: idx + 1)
      return
    }
    if let idx = rows.firstIndex(of: .item(.alerts)) {
      rows.insert(.forecastEraNotice, at: idx + 1)
      return
    }
    if let idx = rows.firstIndex(of: .item(.now)) {
      rows.insert(.forecastEraNotice, at: idx + 1)
      return
    }
    rows.append(.forecastEraNotice)
  }

  static func shouldShow(_ item: FeedItem, in snapshot: FeedSnapshot) -> Bool {
    switch item {
    case .now:
      return snapshot.hasWeather
    case .alerts:
      return snapshot.showAlertsSlot
    case .hourly:
      return snapshot.hasWeather && snapshot.hasHourly
    case .health:
      return snapshot.hasWeather && snapshot.showHealth
    case .yourNews:
      return snapshot.hasLocalBriefing || snapshot.isLocalBriefingPending
    case .radar:
      return snapshot.hasWeather
    case .daily:
      return snapshot.hasWeather && snapshot.hasDaily
    case .nearby:
      return snapshot.showFireCard
    }
  }
}
