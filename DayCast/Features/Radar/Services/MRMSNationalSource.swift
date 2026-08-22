import Foundation

/// Live National precip source. Chrome stays **National radar**.
/// MRMS XYZ tiles are the default paint; MapsGL encoded rain is fallback
/// when timestamps/tiles are missing or the newest frame is past HUD stale.
enum MRMSNationalSource {
  enum Override: Equatable {
    case auto
    case forceTiles
    case forceMapsGL
  }

  /// Same cap as mosaic HUD stale — newest frame only. History in the 1h loop
  /// can be older; that is Play, not a lie about now.
  static var staleThreshold: TimeInterval { RadarLivePresentation.mosaicStale }

  static func shouldPresent(
    _ frames: [RadarFrame],
    override: Override,
    now: Date = Date()
  ) -> Bool {
    switch override {
    case .forceMapsGL:
      return false
    case .forceTiles:
      return !frames.isEmpty
    case .auto:
      return RadarLivePresentation.isPresentableAsLive(
        frames, isSiteProduct: false, now: now)
    }
  }

  static func overrideForDebug() -> Override {
    #if DEBUG
      switch DebugFlags.nationalPaint {
      case .auto: return .auto
      case .forceTiles: return .forceTiles
      case .forceMapsGL: return .forceMapsGL
      }
    #else
      return .auto
    #endif
  }
}
