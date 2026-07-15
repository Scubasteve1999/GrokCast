import Foundation

/// NWS ridge radar products served via the Iowa Environmental Mesonet (IEM) tile cache.
enum NWSRadarProduct: String, CaseIterable, Identifiable {
  // USCOMP composite reflectivity serves N0Q (USCOMP-N0B returns 503 as of 2026-06).
  case baseReflectivity = "N0Q"
  case baseVelocity = "N0U"
  case stormRelativeVelocity = "N0S"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .baseReflectivity: "Reflectivity"
    case .baseVelocity: "Velocity"
    case .stormRelativeVelocity: "Storm Relative Velocity"
    }
  }

  /// Compact label for radar control chips (especially on iPad/narrow panels).
  var shortDisplayName: String {
    switch self {
    case .baseReflectivity: "Reflectivity"
    case .baseVelocity: "Velocity"
    case .stormRelativeVelocity: "SRV"
    }
  }

  var description: String {
    switch self {
    case .baseReflectivity:
      "Nationwide composite reflectivity (dBZ) — precipitation intensity and storm structure."
    case .baseVelocity:
      "Nearest-site base velocity — radial wind motion toward/away from the radar."
    case .stormRelativeVelocity:
      "Nearest-site storm-relative velocity — wind motion relative to storm motion."
    }
  }

  /// Nationwide composite layer (reflectivity only); velocity/SRV require a site-specific radar ID.
  var usesUSComposite: Bool {
    self == .baseReflectivity
  }

  /// IEM ridge TMS product code embedded in the layer name.
  var iemProductCode: String { rawValue }
}
