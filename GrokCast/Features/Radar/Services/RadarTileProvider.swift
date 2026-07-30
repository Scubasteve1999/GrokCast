import Foundation

/// Selects which backend serves precipitation map tiles.
///
/// Live:     Xweather radar (when probed) → freshest IEM / RainViewer; OWM if reals >25m stale
/// Forecast: Xweather fradar → RainViewer nowcast → OpenWeatherMap PR0
enum RadarTileProvider: String, Equatable, CaseIterable {
  case rainViewer
  case xweather
  case openWeatherMap
  /// NWS NEXRAD single-site products (Velocity/SRV) via IEM RIDGE cache. Live-only.
  case iem

  static let preferredLive: RadarTileProvider = .xweather
  static let preferredForecast: RadarTileProvider = .xweather

  var displayName: String {
    switch self {
    case .rainViewer: "RainViewer"
    case .xweather: "Xweather"
    case .openWeatherMap: "OpenWeatherMap"
    case .iem: "NWS NEXRAD"
    }
  }

  /// Compact HUD label for the active mosaic/provider (not nearest-site ID).
  var hudSourceLabel: String {
    switch self {
    case .rainViewer: "RAINVIEWER"
    case .xweather: "XWEATHER"
    case .openWeatherMap: "OWM"
    case .iem: "CONUS"
    }
  }

  var liveFooterLabel: String {
    switch self {
    case .rainViewer: "Live radar · RainViewer"
    case .xweather: "Live radar · Xweather"
    case .openWeatherMap: "Radar · OpenWeatherMap"
    case .iem: "Live radar · CONUS mosaic"
    }
  }

  var forecastFooterLabel: String {
    switch self {
    case .rainViewer: "Forecast radar · RainViewer"
    case .xweather: "Forecast radar · Xweather"
    case .openWeatherMap:
      "Forecast radar · OpenWeatherMap"
    case .iem: "Forecast radar · NWS NEXRAD"
    }
  }

  /// Max zoom supported by this provider's raster tiles in Mapbox.
  var maxZoom: Double {
    switch self {
    case .rainViewer: 10
    case .xweather: 11  // Retina mosaic holds detail slightly past prior z10 cap.
    case .openWeatherMap: 7
    case .iem: 10
    }
  }
}
