import Foundation

/// A deterministic, forecast-only brief used when Grok completes without any text.
/// Keeping this separate from the AI prompt makes the fallback honest, useful, and testable.
enum LocalWeatherBrief {
  /// Deterministic alert copy when Grok's summary is blocked by the 4.7 filter.
  static func alertsSummary(locationName: String, alerts: [NWSAlert]) -> String {
    let events = Array(NWSAlertGrouping.uniqueEvents(from: alerts).prefix(5))
    guard !events.isEmpty else {
      return "No active alerts to summarize for \(locationName)."
    }
    let list = events.joined(separator: ", ")
    let noun = events.count == 1 ? "alert is" : "alerts are"
    return
      "\(events.count) active \(noun) in effect for \(locationName), including \(list). Check the Alerts tab and follow NWS guidance."
  }

  static func make(
    weather: DayCastWeather,
    unit: TemperatureUnit,
    locationName: String,
    activeAlerts: [String],
    now: Date = Date()
  ) -> String {
    let outfit = outfitGuidance(
      feelsLike: weather.feelsLike,
      unit: unit,
      uvIndex: weather.uvIndex,
      windSpeed: weather.windSpeed
    )

    if !activeAlerts.isEmpty {
      let alertList = activeAlerts.prefix(2).joined(separator: " and ")
      return
        "Active alerts include \(alertList); check the Alerts tab and follow local guidance. \(outfit)"
    }

    guard let window = driestWindow(in: weather.hourly, now: now) else {
      return "Rain chance is currently \(weather.precipitationChance)%. \(outfit)"
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = weather.locationTimeZone
    formatter.dateFormat = "h a"
    let start = formatter.string(from: window.start)
    let end = formatter.string(from: window.end)
    let timing: String
    if window.maxPrecipChance <= 20 {
      timing =
        "The driest outdoor window is \(start)–\(end), with rain odds staying at \(window.maxPrecipChance)% or lower."
    } else {
      timing =
        "The least-wet outdoor window is \(start)–\(end), though rain odds still reach \(window.maxPrecipChance)%."
    }
    return "\(timing) \(outfit)"
  }

  private struct OutdoorWindow {
    let start: Date
    let end: Date
    let maxPrecipChance: Int
  }

  private static func driestWindow(in hourly: [HourlyForecast], now: Date) -> OutdoorWindow? {
    let upcoming = Array(hourly.filter { $0.time >= now }.prefix(12))
    guard upcoming.count >= 3 else { return nil }

    let windows = (0...(upcoming.count - 3)).map { index in
      Array(upcoming[index...(index + 2)])
    }
    let daylightWindows = windows.filter { window in
      window.allSatisfy { $0.isDay != false }
    }
    let candidates = daylightWindows.isEmpty ? windows : daylightWindows
    guard
      let best = candidates.min(by: { lhs, rhs in
        let lhsMax = lhs.map(\.precipChance).max() ?? 100
        let rhsMax = rhs.map(\.precipChance).max() ?? 100
        return lhsMax == rhsMax ? lhs[0].time < rhs[0].time : lhsMax < rhsMax
      })
    else { return nil }

    return OutdoorWindow(
      start: best[0].time,
      end: best[2].time.addingTimeInterval(60 * 60),
      maxPrecipChance: best.map(\.precipChance).max() ?? 0
    )
  }

  private static func outfitGuidance(
    feelsLike: Double,
    unit: TemperatureUnit,
    uvIndex: Double,
    windSpeed: Double
  ) -> String {
    let feelsLikeFahrenheit =
      unit == .fahrenheit ? feelsLike : (feelsLike * 9 / 5) + 32
    var guidance: String
    switch feelsLikeFahrenheit {
    case ..<40:
      guidance = "Bundle up with a warm outer layer."
    case ..<55:
      guidance = "A jacket or warm layer will help."
    case ..<70:
      guidance = "A light layer should be comfortable."
    case ..<85:
      guidance = "Comfortable, breathable layers should work well."
    default:
      guidance = "Dress light and bring water."
    }

    if uvIndex >= 6 {
      guidance += " Add sun protection."
    }
    if windSpeed >= (unit == .fahrenheit ? 25 : 40) {
      guidance += " Expect gusty conditions."
    }
    return guidance
  }
}
