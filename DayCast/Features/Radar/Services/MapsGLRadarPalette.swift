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

  /// Official NWS 16-level hex. 0/5/10 dBZ cyan-blue stay alpha 0 so National
  /// and MapsGL do not paint a blue clear-air skirt (bilinear + LUT-snap
  /// grew one when 5/10 were opaque). National visible rain floors at 15 green.
  /// 20+ dBZ is solid so yellow/orange/red/purple cores punch.
  /// Site Doppler paint/legend floors at `Level3N0BDecoder.precipFloorDbz` (25)
  /// and uses `polarUnderlayAlpha(forDbz:)` (same hex, stronger fill).
  static let reflectivityStops: [Stop] = [
    Stop(dbz: 0, hex: "#00ECEC", alpha: 0),
    Stop(dbz: 5, hex: "#01A0F6", alpha: 0),
    Stop(dbz: 10, hex: "#0000F6", alpha: 0),
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

  /// Site Doppler / Level III only. Same discrete 5 dBZ hex as
  /// `reflectivityStops`. Fill is saturated so cells read like the High-Res
  /// green→red reference; labels still punch via halo (`text-opacity` 1 +
  /// `#f5f5f5`). Do not interpolate.
  static func polarUnderlayAlpha(forDbz dbz: Double) -> Double {
    switch dbz {
    case 15: return 0.80
    case 20: return 0.86
    case 25: return 0.90
    case 30: return 0.93
    case 35: return 0.95
    case 40: return 0.96
    case 45: return 0.97
    case 50: return 0.98
    case 55: return 0.98
    case 60: return 0.99
    case 65: return 0.99
    case 70: return 1
    default:
      return dbz < 15 ? 0 : 1
    }
  }

  /// Explicit 5 dBZ breaks so MapsGL cannot fall back to a smooth gradient
  /// (`interval` default 0 interpolates). Same values as the painted stops.
  static var colorScaleBreaks: [Double] {
    stride(from: bandIntervalDbz, through: 70, by: bandIntervalDbz).map { $0 }
  }

  /// Live PNG (N0B IEM overview) keeps native bins. Linear resampling on
  /// cartesian IEM overview is what turned operational gates into mush.
  /// National Xweather PNG fallback uses linear overzoom (same as MRMS).
  static let liveRasterUsesNearestResampling = true
  /// IEM RIDGE cartesian PNGs stop adding native detail near WebMercator z9
  /// (~250 m/px, N0B range-gate scale). Past that, IEM tiles are nearest
  /// copies of that raster (z11 ≈ 97% identical to 2× nearest of z10).
  /// Overview stays nearest so 1-pixel gates do not watercolor.
  static let iemNativeTileZoom: Double = 8.5
  /// Mapbox requests IEM tiles through this zoom so close-in cameras get a
  /// 256px tile we can palette-refine, instead of GPU-nearest overzooming z10.
  static let iemDisplayMaxZoom: Double = 12
  /// Polar N0B tiles stay native at street zoom. Mapbox must keep requesting
  /// them instead of GPU-magnifying a z12 cartesian sheet.
  static let level3DisplayMaxZoom: Double = 14

  /// MRMS tiles are opaque-blurred + bilinear then 5 dBZ LUT-snapped; Mapbox
  /// linear overzoom softens the 1 km pixel grid without a new palette. IEM PNG fallback
  /// stays nearest at overview and linear after native gate scale. Polar Metal
  /// paints constant-color gate trapezoids and does not use this raster knob.
  /// Future / forecast rasters stay linear.
  static func usesNearestResampling(
    provider: RadarTileProvider,
    isFuture: Bool,
    cameraZoom: Double,
    paintsPolarRadials: Bool = false
  ) -> Bool {
    if paintsPolarRadials { return true }
    if isFuture { return false }
    if provider == .mrms || provider == .xweather { return false }
    if provider == .iem {
      return cameraZoom <= iemNativeTileZoom
    }
    return liveRasterUsesNearestResampling
  }

  static func displayMaxZoom(
    provider: RadarTileProvider, paintsPolarRadials: Bool
  ) -> Double {
    paintsPolarRadials ? level3DisplayMaxZoom : provider.maxZoom
  }

  /// MRMS National tiles are already 5 dBZ LUT bins. Mapbox raster fade-in
  /// and dual-buffer crossfade smear those bins into jelly even with linear
  /// overzoom. Other PNG sources keep the existing playback blend.
  static func liveRasterFadeDurationMs(
    provider: RadarTileProvider,
    isAnimating: Bool,
    isFuture: Bool
  ) -> Double {
    if provider == .mrms { return 0 }
    if isAnimating { return isFuture ? 850 : 700 }
    return isFuture ? 400 : 320
  }

  /// Painted bands only — skip alpha-0 stops so the key matches the map.
  /// National floors at 15 green (`keysClearAir: false`). Site N0B
  /// (`keysClearAir: true`) floors at `Level3N0BDecoder.precipFloorDbz` (25)
  /// so the colorbar does not advertise the clear-air lime we no longer paint.
  static var visibleReflectivityStops: [Stop] {
    paintedReflectivityStops(keysClearAir: false)
  }

  static func paintedReflectivityStops(keysClearAir: Bool) -> [Stop] {
    if keysClearAir {
      return reflectivityStops.filter {
        $0.dbz >= Double(Level3N0BDecoder.precipFloorDbz)
      }
    }
    return reflectivityStops.filter { $0.alpha > 0 }
  }

  /// Compact ticks a phone can read. Every value is a real painted stop.
  /// National mosaic — starts at 15 green.
  static let legendTickDbz: [Double] = [15, 20, 35, 50, 65, 70]

  static func legendTicks(keysClearAir: Bool) -> [Double] {
    if keysClearAir {
      return [Double(Level3N0BDecoder.precipFloorDbz), 30, 45, 60, 70]
    }
    return legendTickDbz
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
