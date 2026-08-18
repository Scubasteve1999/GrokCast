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
/// are implemented with Mapbox raster paint properties. We cannot add color
/// stops the tile does not have — contrast/sat/hue/fade only soften the PNG.
enum RadarColorScheme: String, CaseIterable {
  case vibrant
  case balanced

  var displayName: String {
    switch self {
    case .vibrant: "Vibrant"
    case .balanced: "Balanced"
    }
  }

  /// `raster-saturation` (-1...1). Glow needs a lift without posterizing.
  var rasterSaturation: Double {
    switch self {
    case .vibrant: 0.28
    case .balanced: -0.2
    }
  }

  /// `raster-contrast` (-1...1). Negative contrast melts the harsh pixel edges.
  var rasterContrast: Double {
    switch self {
    case .vibrant: -0.22
    case .balanced: -0.12
    }
  }

  /// `raster-brightness-min` (0...1). Lifts dark greens so light precip glows.
  var rasterBrightnessMin: Double {
    switch self {
    case .vibrant: 0.06
    case .balanced: 0.02
    }
  }

  /// Degrees. Xweather mosaics lean cyan; a small rotate reads closer to TWC green.
  var rasterHueRotate: Double {
    switch self {
    case .vibrant: -18
    case .balanced: 0
    }
  }

  /// `raster-emissive-strength`. >1 makes precip self-lit on a dark/hybrid map.
  var rasterEmissiveStrength: Double {
    switch self {
    case .vibrant: 1.45
    case .balanced: 1.1
    }
  }
}

/// Phone Radar chrome copy. Live/24-hr are product chips, not a Forecast mode.
enum RadarChromeCopy {
  static let liveChip = "Live"
  static let futureChip = "24-hr"
  static let layers = "Layers"
  static let liveAccessibility = "Live radar"
  static let futureAccessibility = "24-hour radar"

  static let autoResumeSwitch = "Auto-resume after scrub"
  static let mapOnlySwitch = "Map only"
  static let radarOverlaySwitch = "Radar overlay"
  static let fireLayerSwitch = "Fire layer"
}

/// After the one-sheet chrome, Map-only must never hide Live / 24-hr / Layers.
enum RadarChromeVisibility {
  static func showsControlSheet(mapOnly: Bool) -> Bool {
    _ = mapOnly
    return true
  }
}
