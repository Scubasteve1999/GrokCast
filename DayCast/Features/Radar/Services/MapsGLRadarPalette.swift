import CoreGraphics
import Foundation

/// Client-side reflectivity stops for MapsGL encoded radar (dBZ, metric).
/// Official NWS precip-mode (IEM N0R / weather.gov 16-level), not TWC-green.
enum MapsGLRadarPalette {
  struct Stop: Equatable {
    let dbz: Double
    let hex: String
    let alpha: Double
  }

  /// Discrete 5 dBZ steps. Do not interpolate the colorscale — that smears
  /// into watercolor. Spatial sample interpolation is a separate knob.
  static let interpolatesStops = false
  static let bandIntervalDbz: Double = 5
  /// 0 = native WSR-88D bins. Any value > 0 rounds cores into blobs.
  static let sampleSmoothing: Double = 0
  /// False = MapsGL `InterpolationMode.none`. Bicubic is what turned
  /// official 5 dBZ stops into a watercolor toy.
  static let interpolatesSamples = false

  /// Official NWS 16-level hex. 0 dBZ stays transparent so the map is not a
  /// painted sheet. Light bins are opaque enough to read without a watercolor
  /// wash; 20+ dBZ is solid so yellow/orange/red/purple cores punch.
  static let reflectivityStops: [Stop] = [
    Stop(dbz: 0, hex: "#00ECEC", alpha: 0),
    Stop(dbz: 5, hex: "#01A0F6", alpha: 0.92),
    Stop(dbz: 10, hex: "#0000F6", alpha: 0.96),
    Stop(dbz: 15, hex: "#00FF00", alpha: 0.99),
    Stop(dbz: 20, hex: "#00C800", alpha: 1),
    Stop(dbz: 25, hex: "#009000", alpha: 1),
    Stop(dbz: 30, hex: "#FFFF00", alpha: 1),
    Stop(dbz: 35, hex: "#E7C000", alpha: 1),
    Stop(dbz: 40, hex: "#FF9000", alpha: 1),
    Stop(dbz: 45, hex: "#FF0000", alpha: 1),
    Stop(dbz: 50, hex: "#D60000", alpha: 1),
    Stop(dbz: 55, hex: "#C00000", alpha: 1),
    Stop(dbz: 60, hex: "#FF00FF", alpha: 1),
    Stop(dbz: 65, hex: "#9955C9", alpha: 1),
    Stop(dbz: 70, hex: "#FFFFFF", alpha: 1),
  ]

  /// Explicit 5 dBZ breaks so MapsGL cannot fall back to a smooth gradient
  /// (`interval` default 0 interpolates). Same values as the painted stops.
  static var colorScaleBreaks: [Double] {
    stride(from: bandIntervalDbz, through: 70, by: bandIntervalDbz).map { $0 }
  }

  /// Live PNG (N0B + national fallback) keeps native bins. Linear resampling
  /// is what turned operational gates into mush.
  static let liveRasterUsesNearestResampling = true

  /// MRMS National tiles are already 5 dBZ nearest bins. Mapbox raster fade-in
  /// and dual-buffer crossfade smear those bins into jelly. Other PNG sources
  /// keep the existing playback blend.
  static func liveRasterFadeDurationMs(
    provider: RadarTileProvider,
    isAnimating: Bool,
    isFuture: Bool
  ) -> Double {
    if provider == .mrms { return 0 }
    if isAnimating { return isFuture ? 850 : 700 }
    return isFuture ? 400 : 320
  }

  /// Painted bands only — skip the clear-air stop so the key matches the map.
  /// National radar still paints 5/10 dBZ. N0B keys those to transparent, so
  /// pass `keysClearAir: true` and the legend starts at 15 dBZ green.
  static var visibleReflectivityStops: [Stop] {
    paintedReflectivityStops(keysClearAir: false)
  }

  static func paintedReflectivityStops(keysClearAir: Bool) -> [Stop] {
    if keysClearAir {
      return reflectivityStops.filter { $0.dbz >= 15 }
    }
    return reflectivityStops.filter { $0.alpha > 0 }
  }

  /// Compact ticks a phone can read. Every value is a real painted stop.
  static let legendTickDbz: [Double] = [5, 20, 35, 50, 65, 70]

  static func legendTicks(keysClearAir: Bool) -> [Double] {
    keysClearAir ? [15, 30, 45, 60, 70] : legendTickDbz
  }

  static func shouldUseMapsGL(
    overlayOn: Bool,
    isSiteProduct: Bool,
    keysPresent: Bool,
    nationalUsesMRMS: Bool = false
  ) -> Bool {
    overlayOn && !isSiteProduct && keysPresent && !nationalUsesMRMS
  }

  /// Vibrant/Balanced only retints leftover PNG. Hide it when MapsGL rain
  /// is the paint, or when a site product already ships its own NWS scale.
  static func showsRasterColorScheme(overlayOn: Bool, isSiteProduct: Bool, keysPresent: Bool)
    -> Bool
  {
    overlayOn && !isSiteProduct && !keysPresent
  }
}

/// MapsGL weather-layer ids that ride with Live Rain.
/// StormcellsTracks paths only. Positions are the white pin/tick swarm.
/// Never the Stormcells composite (cones + heat). Empty coverage is valid.
enum MapsGLLiveRainLayers {
  static let radarID = "radar"
  /// Must match `WeatherService.LayerCode` raw values in MapsGL 1.6.1.
  static let stormcellIDs = ["stormcells-tracks"]

  /// Thin dark motion only. 2.25 @ 0.92 read as a marker layer, not tracks.
  static let trackColorWhite: CGFloat = 0.07
  static let trackThickness: Double = 1.15
  static let trackOpacity: Double = 0.68

  /// Xweather stormcell GeoJSON. `general` is the dry-air nationwide tick spray.
  /// hail / rotating / tornado is SVR/TOR class. Do not label NWS SCIT.
  /// MapsGL `get` accepts these dotted paths (same as `report.cat` in their docs).
  static let traitTypeProperty = "traits.type"
  static let traitTornadoProperty = "traits.tornado"
  static let tvsProperty = "tvs"
  static let severeTraitTypes = ["hail", "rotating", "tornado"]
  static let excludedTraitType = "general"
  /// MapsGL `severe.stormcells` MVT splits each cell into Point + LineString
  /// + Polygon (forecast cone). A line layer strokes those cones as wedges.
  static let lineStringGeometryType = "LineString"

  /// Client-side match for the MapsGL layer filter. `general` plus tvs/tornado
  /// flags of 0 is the tick spray. Hail/rotation/tornado or a TVS is SVR/TOR.
  static func isSevereStormcell(
    traitType: String?, traitTornado: Int = 0, tvs: Int = 0
  ) -> Bool {
    if let traitType, severeTraitTypes.contains(traitType) { return true }
    return traitTornado == 1 || tvs == 1
  }

  /// Motion tracks only. Cone polygons and cell points must not paint.
  static func shouldPaintStormcellTrack(
    geometryType: String,
    traitType: String?,
    traitTornado: Int = 0,
    tvs: Int = 0
  ) -> Bool {
    geometryType == lineStringGeometryType
      && isSevereStormcell(
        traitType: traitType, traitTornado: traitTornado, tvs: tvs)
  }

  /// Mapbox layer `filter` JSON. LineStrings of SVR/TOR class only.
  static var mapboxStormcellTrackFilter: [Any] {
    let typeEquals: [Any] = severeTraitTypes.map {
      ["==", ["get", traitTypeProperty], $0] as [Any]
    }
    var anyClause: [Any] = ["any"]
    anyClause.append(contentsOf: typeEquals)
    anyClause.append(["==", ["get", traitTornadoProperty], 1] as [Any])
    anyClause.append(["==", ["get", tvsProperty], 1] as [Any])
    return [
      "all",
      ["==", ["geometry-type"], lineStringGeometryType] as [Any],
      anyClause,
    ]
  }

  /// Removed on host detach. Radar first, then cell motion.
  static var detachIDs: [String] { [radarID] + stormcellIDs }

  /// Host must pass the real overlay + site flags. Do not fold rainWant into
  /// overlayOn and then lie that `isSiteProduct` is false — that kept tracks
  /// on N0B. Site products and overlay-off must return false so the host
  /// detaches the layer instead of only toggling visibility.
  static func shouldShow(
    overlayOn: Bool, isSiteProduct: Bool, keysPresent: Bool, isLive: Bool = true
  ) -> Bool {
    // Tracks stay on National Live even when rain is MRMS tiles.
    isLive && overlayOn && !isSiteProduct && keysPresent
  }

  /// Add MapsGL encoded rain only for mosaic fallback. N0B uses IEM PNG.
  /// MRMS National tiles replace encoded rain; tracks still attach via shouldShow.
  static func shouldAttachRadar(
    overlayOn: Bool,
    isSiteProduct: Bool,
    keysPresent: Bool,
    nationalUsesMRMS: Bool = false
  ) -> Bool {
    MapsGLRadarPalette.shouldUseMapsGL(
      overlayOn: overlayOn,
      isSiteProduct: isSiteProduct,
      keysPresent: keysPresent,
      nationalUsesMRMS: nationalUsesMRMS)
  }
}
