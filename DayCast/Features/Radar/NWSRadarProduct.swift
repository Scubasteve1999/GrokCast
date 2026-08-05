import Foundation

enum NWSRadarProduct: String, CaseIterable, Identifiable {
  case reflectivity = "N0Q"
  case superResReflectivity = "N0B"
  // IEM RIDGE serves base velocity as N0U (N0V returns 503 — verified 2026-07).
  case velocity = "N0U"
  case stormRelativeVelocity = "N0S"
  case correlationCoefficient = "N0C"
  case differentialReflectivity = "N0X"
  case compositeReflectivity = "NCR"

  var id: String { rawValue }
  var iemCode: String { rawValue }

  var displayName: String {
    switch self {
    case .reflectivity: return "Reflectivity"
    case .superResReflectivity: return "Super-Res Reflectivity"
    case .velocity: return "Velocity"
    case .stormRelativeVelocity: return "Storm Relative Velocity"
    case .correlationCoefficient: return "Correlation Coefficient"
    case .differentialReflectivity: return "Differential Reflectivity"
    case .compositeReflectivity: return "Composite Reflectivity"
    }
  }

  static func from(iemCode: String) -> NWSRadarProduct? {
    Self(rawValue: iemCode)
  }

  /// Returns the best available product for a site based on IEM's product list.
  static func bestAvailable(preferred: NWSRadarProduct, available: [NWSRadarProduct])
    -> NWSRadarProduct
  {
    if available.contains(preferred) { return preferred }

    if preferred == .reflectivity || preferred == .superResReflectivity {
      if available.contains(.reflectivity) { return .reflectivity }
      if available.contains(.superResReflectivity) { return .superResReflectivity }
    }

    return available.first ?? preferred
  }
}
