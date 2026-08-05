import Foundation

/// Radar display choices the user makes, restored on the next launch.
///
/// Deliberately excludes the Live/Forecast mode and the selected product. Site
/// products (Super-Res, SRV) resolve against the nearest NEXRAD site, so restoring
/// one after the user has travelled would ask a different radar for a product it
/// may not carry — and Forecast is entitlement-gated. Both reset to their safe
/// defaults instead.
enum RadarPreferences {
  /// Overridable so tests run against an isolated suite. The unit-test bundle is
  /// hosted by the app and shares its `standard` domain, so asserting defaults
  /// against it depends on whatever the app last wrote.
  ///
  /// `nonisolated(unsafe)` because `UserDefaults` is itself thread-safe and this is
  /// only reassigned from test setup.
  nonisolated(unsafe) static var store: UserDefaults = .standard

  private static let colorSchemeKey = "radar.pref.colorScheme"
  private static let baseMapStyleKey = "radar.pref.baseMapStyle"
  private static let showRadarOverlayKey = "radar.pref.showRadarOverlay"
  private static let showFireLayerKey = "radar.pref.showFireLayer"
  private static let playbackSpeedKey = "radar.pref.playbackSpeed"
  private static let radarOpacityKey = "radar.pref.radarOpacity"

  /// Matches the Display sheet / panel slider. Out-of-range values would either
  /// wash the layer out or make it opaque enough to hide the base map.
  static let radarOpacityRange: ClosedRange<Double> = 0.4...1.0
  static let defaultRadarOpacity: Double = 0.85

  static func clampedRadarOpacity(_ value: Double) -> Double {
    guard value.isFinite else { return defaultRadarOpacity }
    return min(max(value, radarOpacityRange.lowerBound), radarOpacityRange.upperBound)
  }

  static var colorScheme: RadarColorScheme {
    get {
      store.string(forKey: colorSchemeKey).flatMap(RadarColorScheme.init(rawValue:)) ?? .vibrant
    }
    set { store.set(newValue.rawValue, forKey: colorSchemeKey) }
  }

  static var baseMapStyle: RadarBaseMapStyle {
    get {
      store.string(forKey: baseMapStyleKey).flatMap(RadarBaseMapStyle.init(rawValue:))
        ?? .satelliteStreets
    }
    set { store.set(newValue.rawValue, forKey: baseMapStyleKey) }
  }

  /// Defaults to true, so absence has to be distinguished from a stored `false` —
  /// `UserDefaults.bool(forKey:)` returns false for both.
  static var showRadarOverlay: Bool {
    get { store.object(forKey: showRadarOverlayKey) as? Bool ?? true }
    set { store.set(newValue, forKey: showRadarOverlayKey) }
  }

  static var showFireLayer: Bool {
    get { store.bool(forKey: showFireLayerKey) }
    set { store.set(newValue, forKey: showFireLayerKey) }
  }

  /// Clamped on the way in as well as out: a value outside the supported range
  /// would divide the frame interval into something unwatchable (or by zero).
  static var playbackSpeed: Double {
    get {
      guard let stored = store.object(forKey: playbackSpeedKey) as? Double else {
        return RadarPlayback.defaultPlaybackSpeed
      }
      return RadarPlayback.clampedPlaybackSpeed(stored)
    }
    set { store.set(RadarPlayback.clampedPlaybackSpeed(newValue), forKey: playbackSpeedKey) }
  }

  /// Raster layer alpha. Clamped both ways so a bad stored value cannot hide the
  /// map or vanish the radar on restore.
  static var radarOpacity: Double {
    get {
      guard let stored = store.object(forKey: radarOpacityKey) as? Double else {
        return defaultRadarOpacity
      }
      return clampedRadarOpacity(stored)
    }
    set { store.set(clampedRadarOpacity(newValue), forKey: radarOpacityKey) }
  }
}
