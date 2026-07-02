import Foundation

/// User-facing radar products for the control panel.
/// Reflectivity uses the composite providers (RainViewer live / Xweather forecast).
/// Site products come from the nearest NEXRAD site via IEM RIDGE tiles
/// (US only, live only — see IEMRadarService). IEM archives exactly N0B + N0S
/// nationally (verified 2026-07); plain base velocity (N0U) is not scan-listable.
enum RadarProduct: String, CaseIterable, Identifiable {
  case reflectivity
  case superResReflectivity
  case stormRelativeVelocity

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .reflectivity: "Reflectivity"
    case .superResReflectivity: "Super-Res"
    case .stormRelativeVelocity: "SRV"
    }
  }

  /// IEM RIDGE product code for single-site tiles (nil = composite pipeline).
  var iemCode: String? {
    switch self {
    case .reflectivity: nil
    case .superResReflectivity: "N0B"
    case .stormRelativeVelocity: "N0S"
    }
  }

  var isSiteProduct: Bool { iemCode != nil }

  /// SRV shows radial velocity (toward/away legend); the others show dBZ.
  var isVelocityProduct: Bool { self == .stormRelativeVelocity }
}

/// Client-side color treatment for the Mapbox radar raster layer.
/// Provider tiles (RainViewer/Xweather/IEM) ship fixed palettes, so schemes
/// are implemented with Mapbox raster paint properties.
enum RadarColorScheme: String, CaseIterable {
  case vibrant
  case balanced

  var displayName: String {
    switch self {
    case .vibrant: "Vibrant"
    case .balanced: "Balanced"
    }
  }

  /// `raster-saturation` (-1...1). Vibrant keeps the native palette.
  var rasterSaturation: Double {
    switch self {
    case .vibrant: 0.0
    case .balanced: -0.5
    }
  }

  /// `raster-contrast` (-1...1).
  var rasterContrast: Double {
    switch self {
    case .vibrant: 0.0
    case .balanced: -0.15
    }
  }
}
