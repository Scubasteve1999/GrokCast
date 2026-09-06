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
  private static let showLightningLayerKey = "radar.pref.showLightningLayer"
  private static let playbackSpeedKey = "radar.pref.playbackSpeed"
  private static let radarOpacityKey = "radar.pref.radarOpacity"
  private static let chaseDeclutteredKey = "radar.pref.chaseDecluttered"
  /// One-time: leftover 0.95 factory default washed out the basemap.
  private static let translucentDefaultMigratedKey = "radar.pref.translucentDefaultMigrated"
  /// Factory default before the underlay restore. Migrated down once.
  static let legacyOpaqueRadarOpacity: Double = 0.95

  /// Matches the Display sheet / panel slider. Out-of-range values would either
  /// wash the layer out or make it opaque enough to hide the base map.
  /// Max stays 1.0 so Layers can still push a solid sheet; do not default there.
  static let radarOpacityRange: ClosedRange<Double> = 0.4...1.0
  static let defaultRadarOpacity: Double = 0.76

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
      migrateBasemapIfNeeded()
      return store.string(forKey: baseMapStyleKey).flatMap(RadarBaseMapStyle.init(rawValue:))
        ?? .dark
    }
    set { store.set(newValue.rawValue, forKey: baseMapStyleKey) }
  }

  /// One-time: Hybrid/Satellite was the leftover postcard canvas.
  private static let quietBasemapMigratedKey = "radar.pref.quietBasemapMigrated"
  /// One-time: Light was the leftover “quiet gray” default.
  private static let darkWorkstationMigratedKey = "radar.pref.darkWorkstationMigrated"

  /// Apply leftover-basemap migrations in one pass. Hybrid/Satellite must not
  /// write Light as an intermediate that the Light→Dark hop would then consume.
  /// Users can still pick Hybrid or Light after both flags are set.
  private static func migrateBasemapIfNeeded() {
    let quietDone = store.object(forKey: quietBasemapMigratedKey) != nil
    let darkDone = store.object(forKey: darkWorkstationMigratedKey) != nil
    if quietDone && darkDone { return }

    let raw = store.string(forKey: baseMapStyleKey)
    let isPostcard =
      raw == RadarBaseMapStyle.satelliteStreets.rawValue
      || raw == RadarBaseMapStyle.satellite.rawValue
    let isLight = raw == RadarBaseMapStyle.light.rawValue

    if !quietDone && isPostcard {
      store.set(RadarBaseMapStyle.dark.rawValue, forKey: baseMapStyleKey)
    } else if !darkDone && isLight {
      store.set(RadarBaseMapStyle.dark.rawValue, forKey: baseMapStyleKey)
    }

    store.set(true, forKey: quietBasemapMigratedKey)
    store.set(true, forKey: darkWorkstationMigratedKey)
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

  /// Defaults ON for Live Radar. Absence must be distinguished from stored `false`.
  static var showLightningLayer: Bool {
    get { store.object(forKey: showLightningLayerKey) as? Bool ?? true }
    set { store.set(newValue, forKey: showLightningLayerKey) }
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
      migrateOpaqueDefaultIfNeeded()
      guard let stored = store.object(forKey: radarOpacityKey) as? Double else {
        return defaultRadarOpacity
      }
      return clampedRadarOpacity(stored)
    }
    set { store.set(clampedRadarOpacity(newValue), forKey: radarOpacityKey) }
  }

  /// Existing installs stored the old 0.95 factory default. Move that one
  /// value down so they see geography under precip; a user who later pushes
  /// the slider back to 0.95 keeps it after this flag is set.
  private static func migrateOpaqueDefaultIfNeeded() {
    if store.object(forKey: translucentDefaultMigratedKey) != nil { return }
    if let stored = store.object(forKey: radarOpacityKey) as? Double,
      abs(stored - legacyOpaqueRadarOpacity) < 0.0001
    {
      store.set(defaultRadarOpacity, forKey: radarOpacityKey)
    }
    store.set(true, forKey: translucentDefaultMigratedKey)
  }

  /// Map-only: slims the chase HUD to SCAN. Does not hide the Live/24-hr sheet.
  static var chaseDecluttered: Bool {
    get { store.bool(forKey: chaseDeclutteredKey) }
    set { store.set(newValue, forKey: chaseDeclutteredKey) }
  }
}
