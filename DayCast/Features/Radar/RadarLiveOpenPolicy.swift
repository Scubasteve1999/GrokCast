import Foundation

/// Default Live open: never strand the user on a blank Site Doppler map.
/// Internal mosaic names stay; this policy only chooses what to present.
enum RadarLiveOpenPolicy {
  enum Product: Equatable {
    case siteDoppler
    case nationalRadar
  }

  /// On Live open / first Live entry:
  /// - explicit Site Doppler tap stays (dry local inspect is allowed)
  /// - real local precip (newest scan, inside the local camera) stays on Site Doppler
  /// - dry, failed, stale, or still-unknown Site Doppler presents National when available
  static func productToPresent(
    userExplicitlyChoseSiteDoppler: Bool,
    siteDopplerLoaded: Bool,
    siteHasPrecipInLiveWindow: Bool,
    siteFailedOrStale: Bool,
    nationalAvailable: Bool
  ) -> Product {
    if userExplicitlyChoseSiteDoppler { return .siteDoppler }
    if !nationalAvailable { return .siteDoppler }
    if siteDopplerLoaded && siteHasPrecipInLiveWindow { return .siteDoppler }
    if siteFailedOrStale { return .nationalRadar }
    if siteDopplerLoaded && !siteHasPrecipInLiveWindow { return .nationalRadar }
    // Site still loading: don't greet with a blank Site Doppler map.
    return .nationalRadar
  }

  /// Read-only Live-open product for a local wet/dry now. Does not fetch tiles.
  /// National is assumed available. Today teaser does not use this — the
  /// preview is always National radar.
  static func productMatchingLocalNow(hasPrecip: Bool) -> Product {
    productToPresent(
      userExplicitlyChoseSiteDoppler: false,
      siteDopplerLoaded: true,
      siteHasPrecipInLiveWindow: hasPrecip,
      siteFailedOrStale: false,
      nationalAvailable: true
    )
  }

  static func clearHint(siteID: String?) -> String {
    if let siteID, !siteID.isEmpty { return "\(siteID) is clear" }
    return "Local is clear"
  }
}
