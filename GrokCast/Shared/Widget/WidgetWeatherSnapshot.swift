import Foundation

/// Lightweight weather snapshot written by the main app and read by widgets.
/// Reuses existing forecast models for stable Date-based identities.
struct WidgetWeatherSnapshot: Codable, Equatable {
  let location: SavedLocation
  let currentTemp: Double
  let conditionText: String
  let symbolName: String
  let high: Double
  let low: Double
  let hourly: [HourlyForecast]
  let fetchedAt: Date

  init(
    location: SavedLocation,
    currentTemp: Double,
    conditionText: String,
    symbolName: String,
    high: Double,
    low: Double,
    hourly: [HourlyForecast],
    fetchedAt: Date
  ) {
    self.location = location
    self.currentTemp = currentTemp
    self.conditionText = conditionText
    self.symbolName = symbolName
    self.high = high
    self.low = low
    self.hourly = hourly
    self.fetchedAt = fetchedAt
  }

  /// Builds a widget snapshot from the full app weather model.
  init(weather: GrokCastWeather) {
    location = weather.location
    currentTemp = weather.currentTemp
    conditionText = weather.conditionText
    symbolName = weather.symbolName
    high = weather.high
    low = weather.low
    hourly = Array(weather.hourly.prefix(4))
    fetchedAt = weather.fetchedAt
  }

  /// Sample data for widget placeholders and SwiftUI previews.
  static var preview: WidgetWeatherSnapshot {
    let location = SavedLocation.oliveBranch
    let now = Date()
    let hourly = (0..<4).map { offset in
      let time = Calendar.current.date(byAdding: .hour, value: offset, to: now) ?? now
      let weatherCode = offset == 0 ? 1 : 3
      return HourlyForecast(
        time: time,
        temp: 72 + Double(offset),
        precipChance: 10,
        weatherCode: weatherCode,
        symbolName: offset == 0 ? "cloud.sun.fill" : "cloud.fill",
        rain: nil,
        showers: nil,
        snowfall: nil
      )
    }
    return WidgetWeatherSnapshot(
      location: location,
      currentTemp: 72,
      conditionText: "Mainly Clear",
      symbolName: "cloud.sun.fill",
      high: 78,
      low: 62,
      hourly: hourly,
      fetchedAt: now
    )
  }
}

extension GrokCastWeather {
  /// Best-effort reconstruction from a persisted widget snapshot for instant cold-launch display.
  init(snapshot: WidgetWeatherSnapshot) {
    location = snapshot.location
    currentTemp = snapshot.currentTemp
    feelsLike = snapshot.currentTemp
    conditionCode = snapshot.hourly.first?.weatherCode ?? 0
    conditionText = snapshot.conditionText
    humidity = 0
    windSpeed = 0
    uvIndex = 0
    precipitationChance = snapshot.hourly.first?.precipChance ?? 0
    high = snapshot.high
    low = snapshot.low
    symbolName = snapshot.symbolName
    fetchedAt = snapshot.fetchedAt
    airQualityIndex = nil
    pm25 = nil
    pollenLevel = nil
    hourly = snapshot.hourly
    daily = []
  }
}
