import CoreGraphics
import Foundation

/// Client-side reflectivity stops for MapsGL encoded radar (dBZ, metric).
/// Banded NWS WSR-88D base reflectivity (GR2Analyst / Iowa State mt311).
/// First stop is fully transparent so clear air does not paint.
enum MapsGLRadarPalette {
  struct Stop: Equatable {
    let dbz: Double
    let hex: String
    let alpha: Double
  }

  /// Discrete 5 dBZ steps. Do not interpolate — that smears into TV rain.
  static let interpolatesStops = false

  static let reflectivityStops: [Stop] = [
    Stop(dbz: 0, hex: "#04E9E7", alpha: 0),
    Stop(dbz: 5, hex: "#04E9E7", alpha: 1),
    Stop(dbz: 10, hex: "#019FF4", alpha: 1),
    Stop(dbz: 15, hex: "#0300F4", alpha: 1),
    Stop(dbz: 20, hex: "#02FD02", alpha: 1),
    Stop(dbz: 25, hex: "#01C501", alpha: 1),
    Stop(dbz: 30, hex: "#008E00", alpha: 1),
    Stop(dbz: 35, hex: "#FDF802", alpha: 1),
    Stop(dbz: 40, hex: "#E5BC00", alpha: 1),
    Stop(dbz: 45, hex: "#FD9500", alpha: 1),
    Stop(dbz: 50, hex: "#FD0000", alpha: 1),
    Stop(dbz: 55, hex: "#D40000", alpha: 1),
    Stop(dbz: 60, hex: "#BC0000", alpha: 1),
    Stop(dbz: 65, hex: "#F800FD", alpha: 1),
    Stop(dbz: 70, hex: "#9854C6", alpha: 1),
    Stop(dbz: 75, hex: "#FFFFFF", alpha: 1),
  ]

  /// Painted bands only — skip the clear-air stop so the key matches the map.
  static var visibleReflectivityStops: [Stop] {
    reflectivityStops.filter { $0.alpha > 0 }
  }

  /// Compact ticks a phone can read. Every value is a real palette stop.
  static let legendTickDbz: [Double] = [5, 20, 35, 50, 65]

  static func shouldUseMapsGL(overlayOn: Bool, isSiteProduct: Bool, keysPresent: Bool)
    -> Bool
  {
    overlayOn && !isSiteProduct && keysPresent
  }
}
