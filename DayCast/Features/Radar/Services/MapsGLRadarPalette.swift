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

  static let reflectivityStops: [Stop] = [
    Stop(dbz: 0, hex: "#00ECEC", alpha: 0),
    Stop(dbz: 5, hex: "#01A0F6", alpha: 1),
    Stop(dbz: 10, hex: "#0000F6", alpha: 1),
    Stop(dbz: 15, hex: "#00FF00", alpha: 1),
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

  /// Painted bands only — skip the clear-air stop so the key matches the map.
  static var visibleReflectivityStops: [Stop] {
    reflectivityStops.filter { $0.alpha > 0 }
  }

  /// Compact ticks a phone can read. Every value is a real painted stop.
  static let legendTickDbz: [Double] = [5, 20, 35, 50, 65, 70]

  static func shouldUseMapsGL(overlayOn: Bool, isSiteProduct: Bool, keysPresent: Bool)
    -> Bool
  {
    overlayOn && !isSiteProduct && keysPresent
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

  /// Removed on host detach. Radar first, then cell motion.
  static var detachIDs: [String] { [radarID] + stormcellIDs }

  static func shouldShow(
    overlayOn: Bool, isSiteProduct: Bool, keysPresent: Bool, isLive: Bool = true
  ) -> Bool {
    isLive
      && MapsGLRadarPalette.shouldUseMapsGL(
        overlayOn: overlayOn, isSiteProduct: isSiteProduct, keysPresent: keysPresent)
  }
}
