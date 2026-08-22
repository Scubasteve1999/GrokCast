import Foundation

/// Live Rain may only show a current scan.
///
/// Mosaic HUD goes red at 15m, site HUD at 10m (`ChaseRadarHUDLogic`). A 149m
/// mosaic labeled Live is a trust failure — Play used to start at the oldest
/// frame of an 18×10m / 3-hour MapsGL window. Trim to the HUD stale cap or
/// fail honest (unavailable), never leave that picture on screen.
enum RadarLivePresentation {
  static let mosaicReload: TimeInterval = 5 * 60
  static let newestFrameReload: TimeInterval = 10 * 60
  /// HUD mosaic `.stale`.
  static let mosaicStale: TimeInterval = 15 * 60
  /// HUD site `.stale`.
  static let siteStale: TimeInterval = 10 * 60

  static let staleUnavailableMessage = "Live radar unavailable — scan is too old."

  static var mapsGLLiveLookback: TimeInterval { mosaicStale }

  static func maxAgeForLive(isSiteProduct: Bool) -> TimeInterval {
    isSiteProduct ? siteStale : mosaicStale
  }

  static func newestAge(_ frames: [RadarFrame], now: Date = Date()) -> TimeInterval {
    guard let newest = frames.last?.timestamp else { return .infinity }
    return now.timeIntervalSince(newest)
  }

  static func isPresentableAsLive(
    _ frames: [RadarFrame], isSiteProduct: Bool, now: Date = Date()
  ) -> Bool {
    newestAge(frames, now: now) <= maxAgeForLive(isSiteProduct: isSiteProduct)
  }

  /// Oldest→newest frames inside the Live window. Empty = fail honest.
  static func liveFrames(
    _ frames: [RadarFrame], isSiteProduct: Bool, now: Date = Date()
  ) -> [RadarFrame] {
    let maxAge = maxAgeForLive(isSiteProduct: isSiteProduct)
    return frames.filter { now.timeIntervalSince($0.timestamp) <= maxAge }
  }

  static func compositeNeedsReload(
    newestTimestamp: Date?, lastLoadedAt: Date?, now: Date = Date()
  ) -> Bool {
    if lastLoadedAt == nil { return true }
    if let lastLoadedAt, now.timeIntervalSince(lastLoadedAt) >= mosaicReload {
      return true
    }
    if let newestTimestamp, now.timeIntervalSince(newestTimestamp) >= newestFrameReload {
      return true
    }
    if newestTimestamp == nil { return true }
    return false
  }
}
