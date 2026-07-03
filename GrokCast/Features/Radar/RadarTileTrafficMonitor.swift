#if DEBUG
import Foundation

/// DEBUG-only estimates of radar tile fetch pressure during playback.
/// Logs when frame transitions exceed a threshold so you can spot RainViewer/OWM overuse.
enum RadarTileTrafficMonitor {
  private static var frameTransitions = 0
  private static var uniqueTileKeys = Set<String>()
  private static var estimatedTileRequests = 0
  private static var lastLoggedSummary = Date.distantPast

  /// Rough viewport tile count at a given zoom (256px tiles, ~1 screen + prefetch ring).
  static func estimatedViewportTiles(zoom: Int, prefetchDelta: Int) -> Int {
    let base = max(4, Int(pow(2.0, Double(min(zoom, 8) - 4)) * 4))
    let prefetchMultiplier = 1 + (prefetchDelta * 2)
    return base * prefetchMultiplier
  }

  static func recordFrameTransition(
    tileKey: String,
    provider: RadarTileProvider,
    zoom: Int,
    prefetchDelta: Int,
    isAnimating: Bool
  ) {
    frameTransitions += 1
    let isNewKey = uniqueTileKeys.insert(tileKey).inserted
    if isNewKey {
      estimatedTileRequests += estimatedViewportTiles(zoom: zoom, prefetchDelta: prefetchDelta)
    }

    if frameTransitions == 1 || frameTransitions % 12 == 0 {
      print(
        "[RadarTiles] frame #\(frameTransitions) provider=\(provider.displayName)"
          + " zoom=\(zoom) prefetchΔ=\(prefetchDelta) anim=\(isAnimating)"
          + " uniqueKeys=\(uniqueTileKeys.count)"
          + " estRequests≈\(estimatedTileRequests)"
      )
    }

    let now = Date()
    if now.timeIntervalSince(lastLoggedSummary) > 120 {
      logSessionSummary()
      lastLoggedSummary = now
    }
  }

  static func logSessionSummary() {
    guard frameTransitions > 0 else { return }
    print(
      "[RadarTiles] session summary — transitions=\(frameTransitions)"
        + " uniqueFrames=\(uniqueTileKeys.count)"
        + " estTileRequests≈\(estimatedTileRequests)"
    )
  }

  static func resetSession() {
    frameTransitions = 0
    uniqueTileKeys.removeAll()
    estimatedTileRequests = 0
    lastLoggedSummary = Date.distantPast
  }
}
#endif
