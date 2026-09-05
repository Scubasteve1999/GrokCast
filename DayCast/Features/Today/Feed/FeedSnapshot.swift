import Foundation

/// Pure input for feed ordering / visibility. Built from stores in the UI; tested without SwiftUI.
struct FeedSnapshot: Equatable, Sendable {
  var hasWeather: Bool
  var alertCount: Int
  var hasHourly: Bool
  var hasDaily: Bool
  /// Meaningful next-hour / minutecast content (not "clear all day" empty shell).
  var hasPrecipContent: Bool
  /// Stage 3/4: nearest fire within threshold or fire-weather alert active.
  var showFireCard: Bool
  /// Elevated AQI, NWS air-quality alert, or low visibility. Calm days hide Conditions.
  var showHealth: Bool = false
  /// Open-Meteo Now is a precip condition (rain / storm / snow / sleet).
  var isNowWet: Bool = false
  /// NWS AFD/PNS cards for this city (`LocalBriefingStore`). Hide the rail when false.
  var hasLocalBriefing: Bool = false
  /// Warning/watch that belongs on radar. Heat and air-quality advisories stay false.
  var hasRadarRelevantAlert: Bool = false

  /// Live official NWS point alerts only. Outlook / MD never keep this slot.
  var showAlertsSlot: Bool { alertCount > 0 }

  static let empty = FeedSnapshot(
    hasWeather: false,
    alertCount: 0,
    hasHourly: false,
    hasDaily: false,
    hasPrecipContent: false,
    showFireCard: false,
    showHealth: false,
    isNowWet: false,
    hasLocalBriefing: false,
    hasRadarRelevantAlert: false
  )
}
