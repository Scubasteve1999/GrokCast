import Foundation

/// Selects which backend serves precipitation map tiles.
///
/// Live National: NOAA MRMS XYZ (when timestamps are fresh) → MapsGL rain
///                over Xweather/IEM/RainViewer frames.
/// Live site:     Level III N0B polar (IEM N0B PNG fallback) / IEM N0S.
/// Forecast:      Xweather fradar → NOAA HRRR via IEM (CONUS) → RainViewer nowcast
///                → OpenWeatherMap PR0
enum RadarTileProvider: String, Equatable, CaseIterable {
  case rainViewer
  case xweather
  case openWeatherMap
  /// NWS NEXRAD single-site products (Velocity/SRV) via IEM RIDGE cache. Live-only.
  case iem
  /// NOAA MRMS MergedReflectivityQCComposite, pre-tiled on Mac/CDN. Live National.
  case mrms
  /// NOAA HRRR model simulated reflectivity via the IEM tile cache. Forecast-only, CONUS.
  case hrrr

  static let preferredLive: RadarTileProvider = .xweather
  static let preferredForecast: RadarTileProvider = .xweather

  var displayName: String {
    switch self {
    case .rainViewer: "RainViewer"
    case .xweather: "Xweather"
    case .openWeatherMap: "OpenWeatherMap"
    case .iem: "NWS NEXRAD"
    case .mrms: "National radar"
    case .hrrr: "NOAA HRRR"
    }
  }

  /// Compact HUD label for the active mosaic/provider (not nearest-site ID).
  var hudSourceLabel: String {
    switch self {
    case .rainViewer: "RAINVIEWER"
    case .xweather: "XWEATHER"
    case .openWeatherMap: "OWM"
    case .iem: "CONUS"
    case .mrms: "NATIONAL"
    case .hrrr: "HRRR"
    }
  }

  var liveFooterLabel: String {
    switch self {
    case .rainViewer: "Live radar · RainViewer"
    case .xweather: "Live radar · Xweather"
    case .openWeatherMap: "Radar · OpenWeatherMap"
    case .iem: "Live radar · National radar"
    case .mrms: "Live radar · National radar"
    case .hrrr: "Model radar · NOAA HRRR"
    }
  }

  var forecastFooterLabel: String {
    switch self {
    case .rainViewer: "Forecast radar · RainViewer"
    case .xweather: "Forecast radar · Xweather"
    case .openWeatherMap:
      "Forecast radar · OpenWeatherMap"
    case .iem: "Forecast radar · NWS NEXRAD"
    case .mrms: "Forecast radar · National radar"
    case .hrrr: "Forecast · \(forecastSourceLabel ?? displayName)"
    }
  }

  /// What the 12-hr HUD names instead of the product when frames are model output, not
  /// observed radar. Nil for providers whose forecast reads as radar.
  var forecastSourceLabel: String? {
    switch self {
    case .hrrr: "NOAA HRRR model"
    case .rainViewer, .xweather, .openWeatherMap, .iem, .mrms: nil
    }
  }

  /// Max zoom supported by this provider's raster tiles in Mapbox.
  var maxZoom: Double {
    switch self {
    case .rainViewer: 10
    case .xweather: 11  // Retina mosaic holds detail slightly past prior z10 cap.
    case .openWeatherMap: 7
    case .iem: MapsGLRadarPalette.iemDisplayMaxZoom
    case .mrms: 8
    case .hrrr: 8  // 3 km model grid; deeper zoom only magnifies pixels.
    }
  }
}
