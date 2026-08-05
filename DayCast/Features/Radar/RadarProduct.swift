import Foundation

/// User-facing radar products for the control panel.
/// Reflectivity uses composite providers (Xweather live preferred, then IEM/RainViewer).
/// Site products come from the nearest NEXRAD site via IEM RIDGE tiles
/// (US only, live only — see IEMRadarService). IEM archives exactly N0B + N0S
/// nationally (verified 2026-07); plain base velocity (N0U) is not scan-listable.
enum RadarProduct: String, CaseIterable, Identifiable {
  // Raw values are explicit because they back the tip-dismissal defaults keys —
  // renaming a case must not silently resurrect a dismissed tip.
  case reflectivity = "reflectivity"
  case superResReflectivity = "superResReflectivity"
  case stormRelativeVelocity = "stormRelativeVelocity"

  var id: String { rawValue }

  /// Plain-language name for chips, panel header, and share text. Deliberately
  /// non-technical — casual users never learn "reflectivity"/"SRV".
  /// Use `technicalName` for anything a model reads (see GrokAIViewModel).
  var displayName: String {
    switch self {
    case .reflectivity: "Rain"
    case .superResReflectivity: "Detail rain"
    case .stormRelativeVelocity: "Storm winds"
    }
  }

  /// Unambiguous meteorological name for LLM prompts. Grok understands
  /// "storm-relative velocity"; it can't do much with "Storm winds".
  var technicalName: String {
    switch self {
    case .reflectivity: "composite reflectivity"
    case .superResReflectivity: "super-resolution base reflectivity (N0B)"
    case .stormRelativeVelocity: "storm-relative velocity (N0S)"
    }
  }

  /// Chase HUD shorthand — the strip is too narrow for "Storm winds", and
  /// chasers read SRV faster than any plain-language label.
  var shortCode: String {
    switch self {
    case .reflectivity: "RAIN"
    case .superResReflectivity: "DETAIL"
    case .stormRelativeVelocity: "SRV"
    }
  }

  /// One-line explainer shown under the product chips the first time a site
  /// product is used, so clear-air clutter doesn't read as a bug.
  var userTip: String? {
    switch self {
    case .reflectivity: nil
    case .superResReflectivity: "Grainy circle near the radar is clutter, not rain."
    case .stormRelativeVelocity:
      "Green = toward radar · red = away. Look for tight couplets in storms."
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

/// Remembers which product tips the user has dismissed (once per product, forever).
enum RadarTipStore {
  private static func key(for product: RadarProduct) -> String {
    "radar.tipDismissed.\(product.rawValue)"
  }

  static func isDismissed(_ product: RadarProduct) -> Bool {
    UserDefaults.standard.bool(forKey: key(for: product))
  }

  static func dismiss(_ product: RadarProduct) {
    UserDefaults.standard.set(true, forKey: key(for: product))
  }
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

  /// `raster-saturation` (-1...1). Vibrant slightly boosts precip readability.
  var rasterSaturation: Double {
    switch self {
    case .vibrant: 0.15
    case .balanced: -0.35
    }
  }

  /// `raster-contrast` (-1...1).
  var rasterContrast: Double {
    switch self {
    case .vibrant: 0.08
    case .balanced: -0.1
    }
  }
}
