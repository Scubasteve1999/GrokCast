import Foundation

/// Xweather map layer identifiers for live vs forecast radar tiles.
enum XweatherRadarLayer: String, Equatable {
  /// Live / past radar composite.
  case radar
  /// Forecast radar based on models (GFS, NAM, or HRRR).
  case fradar
}
