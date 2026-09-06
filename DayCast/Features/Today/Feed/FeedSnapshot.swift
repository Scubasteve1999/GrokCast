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
  /// Weather is up but this city's briefing has not settled yet. Hold the slot.
  var isLocalBriefingPending: Bool = false
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
    isLocalBriefingPending: false,
    hasRadarRelevantAlert: false
  )
}

/// Your News rail visibility. Pending holds height so Daily cannot jump into the peek.
enum LocalBriefingSlot {
  /// Store has not settled this city yet (in flight, or still on a previous location).
  static func isPending(
    currentLocationID: String?,
    storeLocationID: String?,
    itemCount: Int,
    isRefreshing: Bool
  ) -> Bool {
    guard let currentLocationID else { return false }
    let matches = storeLocationID == currentLocationID
    if matches && itemCount > 0 { return false }
    if matches && !isRefreshing { return false }
    return true
  }
}
