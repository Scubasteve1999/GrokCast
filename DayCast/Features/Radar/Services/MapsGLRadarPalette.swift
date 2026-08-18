import CoreGraphics
import Foundation

/// Client-side reflectivity stops for MapsGL encoded radar (dBZ, metric).
/// Graphic TWC-style rain: green-first hard bands, drizzle/clear-air hidden.
enum MapsGLRadarPalette {
  struct Stop: Equatable {
    let dbz: Double
    let hex: String
    let alpha: Double
  }

  /// Discrete 5 dBZ steps. Do not interpolate — that smears into watercolor.
  static let interpolatesStops = false
  static let bandIntervalDbz: Double = 5

  static let reflectivityStops: [Stop] = [
    Stop(dbz: 0, hex: "#0B7A2B", alpha: 0),
    Stop(dbz: 15, hex: "#0B7A2B", alpha: 0),
    Stop(dbz: 20, hex: "#0B7A2B", alpha: 1),
    Stop(dbz: 25, hex: "#1DB954", alpha: 1),
    Stop(dbz: 30, hex: "#3DDC6A", alpha: 1),
    Stop(dbz: 35, hex: "#F5E000", alpha: 1),
    Stop(dbz: 40, hex: "#F0B400", alpha: 1),
    Stop(dbz: 45, hex: "#FF8A00", alpha: 1),
    Stop(dbz: 50, hex: "#FF3D00", alpha: 1),
    Stop(dbz: 55, hex: "#E00000", alpha: 1),
    Stop(dbz: 60, hex: "#B00000", alpha: 1),
    Stop(dbz: 65, hex: "#D400C8", alpha: 1),
  ]

  /// Painted bands only — skip the clear-air stops so the key matches the map.
  static var visibleReflectivityStops: [Stop] {
    reflectivityStops.filter { $0.alpha > 0 }
  }

  /// Compact ticks a phone can read. Every value is a real painted stop.
  static let legendTickDbz: [Double] = [20, 35, 50, 65]

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
