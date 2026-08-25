import Foundation

/// Pure input for feed ordering / visibility. Built from stores in the UI; tested without SwiftUI.
struct FeedSnapshot: Equatable, Sendable {
  var hasWeather: Bool
  var alertCount: Int
  var hasHourly: Bool
  var hasDaily: Bool
  /// Meaningful next-hour / minutecast content (not "clear all day" empty shell).
  var hasPrecipContent: Bool
  /// Dry or wet next-event card. Feed order keeps radar after health; `hasPrecipContent` is teaser copy.
  var hasNextEvent: Bool = false
  var hasAQI: Bool
  var hasSunriseOrSunset: Bool
  /// Stage 3/4: nearest fire within threshold or fire-weather alert active.
  var showFireCard: Bool
  /// AI brief card shows whenever we have weather; the card owns loading / empty copy.
  var showAIInsight: Bool
  /// SPC Day 1 ≥ Slight, MD, or severe watch/warning — earns the Today alerts slot without NWS rows.
  var hasSevereContext: Bool = false
  /// Open-Meteo Now is a precip condition (rain / storm / snow / sleet).
  var isNowWet: Bool = false
  /// NWS AFD/PNS cards for this city (`LocalBriefingStore`). Hide the rail when false.
  var hasLocalBriefing: Bool = false

  /// NWS point alerts **or** earned severe context (outlook / MD / watch).
  var showAlertsSlot: Bool { alertCount > 0 || hasSevereContext }

  static let empty = FeedSnapshot(
    hasWeather: false,
    alertCount: 0,
    hasHourly: false,
    hasDaily: false,
    hasPrecipContent: false,
    hasAQI: false,
    hasSunriseOrSunset: false,
    showFireCard: false,
    showAIInsight: false,
    hasSevereContext: false,
    isNowWet: false,
    hasLocalBriefing: false
  )
}
