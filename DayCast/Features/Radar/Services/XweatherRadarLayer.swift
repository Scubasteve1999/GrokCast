import Foundation

/// Xweather map layer identifiers for live vs forecast radar tiles.
enum XweatherRadarLayer: String, Equatable {
  /// Global mosaic: ground radar + satellite-derived fill where radar is sparse.
  /// Best consumer-looking live precipitation layer on Raster Maps.
  case radarGlobal = "radar-global"
  /// Ground-based radar composite (regional coverage; gaps stay empty).
  case radar
  /// Forecast radar based on models (GFS, NAM, or HRRR).
  case fradar
}
