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
  /// - real local precip stays on Site Doppler
  /// - dry, failed, or stale Site Doppler presents National radar when available
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
    return .siteDoppler
  }
}
