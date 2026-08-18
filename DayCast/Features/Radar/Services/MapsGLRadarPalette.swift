import CoreGraphics
import Foundation

/// Client-side reflectivity stops for MapsGL encoded radar (dBZ, metric).
/// First stop is fully transparent so clear air does not paint.
enum MapsGLRadarPalette {
  struct Stop: Equatable {
    let dbz: Double
    let hex: String
    let alpha: Double
  }

  /// TWC-like green → yellow → red. Transparent at 0 dBZ.
  static let reflectivityStops: [Stop] = [
    Stop(dbz: 0, hex: "#00E400", alpha: 0),
    Stop(dbz: 5, hex: "#00E400", alpha: 0.35),
    Stop(dbz: 15, hex: "#3DDB00", alpha: 0.65),
    Stop(dbz: 25, hex: "#FFFF00", alpha: 0.8),
    Stop(dbz: 35, hex: "#FF7E00", alpha: 0.88),
    Stop(dbz: 45, hex: "#FF0000", alpha: 0.92),
    Stop(dbz: 55, hex: "#99004C", alpha: 0.95),
    Stop(dbz: 65, hex: "#7E00FF", alpha: 0.97),
    Stop(dbz: 75, hex: "#FFFFFF", alpha: 1),
  ]

  static func shouldUseMapsGL(overlayOn: Bool, isSiteProduct: Bool, keysPresent: Bool)
    -> Bool
  {
    overlayOn && !isSiteProduct && keysPresent
  }
}
