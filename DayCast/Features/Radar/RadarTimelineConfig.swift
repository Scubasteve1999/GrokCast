import Foundation

enum RadarTimelineConfig {
  /// OpenWeatherMap radar `tm` requires 10-minute steps.
  /// ~1 hour at 10-minute steps (not the old 18×10m / 3-hour window).
  static let liveMaxFrames = 7
  static let liveIntervalMinutes = 10

  static let forecastMaxFrames = 12
  /// OpenWeatherMap weather maps 2.0 PR0 uses 1-hour forecast steps.
  static let forecastIntervalMinutes = 60
  static let forecastStepDescription = "+1h"

  static let modeSwitchDelay: Duration = .milliseconds(250)
}
