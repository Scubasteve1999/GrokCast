import Foundation

/// Selects which backend serves precipitation map tiles.
/// RainViewer is the default for live radar (free tier).
/// Xweather (fradar) is preferred for FUTURE forecast precipitation when configured.
enum RadarTileProvider: String, Equatable, CaseIterable {
  case rainViewer
  case xweather
  case openWeatherMap

  /// Default live (NOW) radar — works without a paid Maps plan.
  static let preferredLive: RadarTileProvider = .rainViewer

  /// Forecast (FUTURE) radar — prefer Xweather fradar (keys embedded), fallback RainViewer/OWM.
  static let preferredForecast: RadarTileProvider = .xweather

  var displayName: String {
    switch self {
    case .rainViewer: "RainViewer"
    case .xweather: "Xweather"
    case .openWeatherMap: "OpenWeatherMap"
    }
  }

  var liveFooterLabel: String {
    switch self {
    case .rainViewer: "Live radar · RainViewer"
    case .xweather: "Radar · Xweather"
    case .openWeatherMap: "Radar · OpenWeatherMap"
    }
  }

  var forecastFooterLabel: String {
    switch self {
    case .rainViewer: "Forecast radar · RainViewer"
    case .xweather: "Forecast radar · Xweather"
    case .openWeatherMap:
      "Forecast radar · OpenWeatherMap"
    }
  }

  /// Max zoom supported by this provider's raster tiles in Mapbox.
  var maxZoom: Double {
    switch self {
    case .rainViewer: 10
    case .xweather: 8
    case .openWeatherMap: 7
    }
  }
}
