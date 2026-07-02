import Foundation

enum RadarTimelineConfig {
  /// OpenWeatherMap radar `tm` requires 10-minute steps.
  static let liveMaxFrames = 18
  static let liveIntervalMinutes = 10

  static let forecastMaxFrames = 12
  /// OpenWeatherMap weather maps 2.0 PR0 uses 1-hour forecast steps.
  static let forecastIntervalMinutes = 60
  static let forecastStepDescription = "+1h"

  static let modeSwitchDelay: Duration = .milliseconds(250)

  static var forecastProbeOffset: String {
    "+\(forecastIntervalMinutes)minutes"
  }

  /// Mid-range forecast probe offset (hourly native resolution validation).
  static var forecastProbeMidOffset: String {
    "+60minutes"
  }

  /// Last timeline offset derived from frame count and interval (e.g. +660minutes).
  static var forecastProbeMaxOffset: String {
    let minutes = (forecastMaxFrames - 1) * forecastIntervalMinutes
    return "+\(minutes)minutes"
  }
}
