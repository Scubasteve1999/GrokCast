import Foundation

/// Selects which backend serves precipitation map tiles.
///
/// Live National: NOAA MRMS XYZ (when timestamps are fresh) → MapsGL rain
///                over Xweather/IEM/RainViewer frames.
/// Live site:     Level III N0B polar (IEM N0B PNG fallback) / IEM N0S.
/// Forecast:      Xweather fradar → RainViewer nowcast → OpenWeatherMap PR0
enum RadarTileProvider: String, Equatable, CaseIterable {
  case rainViewer
  case xweather
  case openWeatherMap
  /// NWS NEXRAD single-site products (Velocity/SRV) via IEM RIDGE cache. Live-only.
  case iem
  /// NOAA MRMS MergedReflectivityQCComposite, pre-tiled on Mac/CDN. Live National.
  case mrms

  static let preferredLive: RadarTileProvider = .xweather
  static let preferredForecast: RadarTileProvider = .xweather

  /// Log / DEBUG only. User chrome uses `liveFooterLabel` / product `displayName`.
  var displayName: String {
    switch self {
    case .rainViewer: "RainViewer"
    case .xweather: "Xweather"
    case .openWeatherMap: "OpenWeatherMap"
    case .iem: "NWS NEXRAD"
    case .mrms: "National radar"
    }
  }

  /// Compact HUD label for the active mosaic/provider (not nearest-site ID).
  /// Log / DEBUG only — do not put this on user chrome.
  var hudSourceLabel: String {
    switch self {
    case .rainViewer: "RAINVIEWER"
    case .xweather: "XWEATHER"
    case .openWeatherMap: "OWM"
    case .iem: "CONUS"
    case .mrms: "NATIONAL"
    }
  }

  /// User-visible live footer. National tile backends share one skill name;
  /// Site Doppler is product chrome in `RadarStatusFooterCopy`.
  var liveFooterLabel: String {
    RadarChromeCopy.liveFooterNational
  }

  /// User-visible 24-hr footer. Never names RainViewer / Xweather / OpenWeatherMap.
  var forecastFooterLabel: String {
    RadarChromeCopy.forecastFooter
  }

  /// Max zoom supported by this provider's raster tiles in Mapbox.
  var maxZoom: Double {
    switch self {
    case .rainViewer: 10
    case .xweather: 11  // Retina mosaic holds detail slightly past prior z10 cap.
    case .openWeatherMap: 7
    case .iem: MapsGLRadarPalette.iemDisplayMaxZoom
    case .mrms: 8
    }
  }
}
