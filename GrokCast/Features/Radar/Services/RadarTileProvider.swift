import Foundation

/// Selects which backend serves precipitation map tiles.
/// RainViewer is the international fallback for live radar.
/// IEM CONUS composite (N0Q) is the default US Reflectivity source.
/// Single-site N0B/N0S load only when the user picks Super-Res or SRV.
/// OpenWeatherMap PR0 is preferred for FUTURE when configured; Xweather fradar is last resort.
enum RadarTileProvider: String, Equatable, CaseIterable {
  case rainViewer
  case xweather
  case openWeatherMap
  /// NWS NEXRAD single-site products (Velocity/SRV) via IEM RIDGE cache. Live-only.
  case iem

  /// Default live (NOW) radar — IEM CONUS composite, else site fallback, OWM, RainViewer.
  static let preferredLive: RadarTileProvider = .iem

  /// Forecast (FUTURE) radar — OpenWeatherMap when configured, else RainViewer, else Xweather.
  static let preferredForecast: RadarTileProvider = .openWeatherMap

  var displayName: String {
    switch self {
    case .rainViewer: "RainViewer"
    case .xweather: "Xweather"
    case .openWeatherMap: "OpenWeatherMap"
    case .iem: "NWS NEXRAD"
    }
  }

  var liveFooterLabel: String {
    switch self {
    case .rainViewer: "Live radar · RainViewer"
    case .xweather: "Radar · Xweather"
    case .openWeatherMap: "Radar · OpenWeatherMap"
    case .iem: "Live radar · NWS NEXRAD"
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
    case .xweather: 10  // Aeris serves fradar past z8; the 8 cap forced overzoom blur.
    case .openWeatherMap: 7
    case .iem: 10
    }
  }
}
