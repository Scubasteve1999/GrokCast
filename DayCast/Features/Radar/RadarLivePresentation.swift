import Foundation

/// Live Rain presentation: a recent loop, parked on now.
///
/// HUD stale (`ChaseRadarHUDLogic`) means the *newest* scan is too old —
/// reload or fail honest. It is not a loop trim. Trimming to 15m mosaic /
/// 10m site deleted Play: IEM N0B is ~3–5 min, so a 10m cap left 1–2 frames
/// and the map froze. Mosaic 18×10m (~3h) was the other failure: Play/open
/// could sit on a 149m frame labeled Live.
///
/// Loop is about 1 hour of history. Open / resume / Live chip lands on the
/// newest scan. Old frames are playback history, not a lie.
enum RadarLivePresentation {
  static let mosaicReload: TimeInterval = 5 * 60
  static let newestFrameReload: TimeInterval = 10 * 60
  /// HUD mosaic `.stale` — newest scan only.
  static let mosaicStale: TimeInterval = 15 * 60
  /// HUD site `.stale` — newest scan only.
  static let siteStale: TimeInterval = 10 * 60
  /// Site + mosaic playback history. Not the HUD stale cap.
  static let loopWindow: TimeInterval = 60 * 60
  /// Enough N0B volumes to fill `loopWindow` at ~2–5 min/scan.
  static let siteLoopMaxFrames = 24

  static let staleUnavailableMessage = "Live radar unavailable — scan is too old."

  static var mapsGLLiveLookback: TimeInterval { loopWindow }

  static var mosaicLoopMaxFrames: Int {
    Int(loopWindow / Double(RadarTimelineConfig.liveIntervalMinutes * 60)) + 1
  }

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

  /// Oldest→newest frames inside the ~1h loop. HUD stale is not applied here.
  static func liveFrames(
    _ frames: [RadarFrame], isSiteProduct _: Bool, now: Date = Date()
  ) -> [RadarFrame] {
    frames.filter { now.timeIntervalSince($0.timestamp) <= loopWindow }
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
