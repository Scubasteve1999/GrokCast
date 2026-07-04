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
  /// Daily rows for cold-launch Forecast hydration; omitted in older persisted snapshots.
  let daily: [DailyForecast]
  let fetchedAt: Date

  /// Optional GrokCast Score (0–100) for widgets and Watch complications.
  let grokCastScore: Int?
  let grokCastScoreLabel: String?
  let minutecastMessage: String?
  /// First line of the daily Grok brief for medium widget / lock screen flair.
  let grokBriefOneLiner: String?

  private enum CodingKeys: String, CodingKey {
    case location
    case currentTemp
    case conditionText
    case symbolName
    case high
    case low
    case hourly
    case daily
    case fetchedAt
    case grokCastScore
    case grokCastScoreLabel
    case minutecastMessage
    case grokBriefOneLiner
  }

  init(
    location: SavedLocation,
    currentTemp: Double,
    conditionText: String,
    symbolName: String,
    high: Double,
    low: Double,
    hourly: [HourlyForecast],
    daily: [DailyForecast] = [],
    fetchedAt: Date,
    grokCastScore: Int? = nil,
    grokCastScoreLabel: String? = nil,
    minutecastMessage: String? = nil,
    grokBriefOneLiner: String? = nil
  ) {
    self.location = location
    self.currentTemp = currentTemp
    self.conditionText = conditionText
    self.symbolName = symbolName
    self.high = high
    self.low = low
    self.hourly = hourly
    self.daily = daily
    self.fetchedAt = fetchedAt
    self.grokCastScore = grokCastScore
    self.grokCastScoreLabel = grokCastScoreLabel
    self.minutecastMessage = minutecastMessage
    self.grokBriefOneLiner = grokBriefOneLiner
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    location = try container.decode(SavedLocation.self, forKey: .location)
    currentTemp = try container.decode(Double.self, forKey: .currentTemp)
    conditionText = try container.decode(String.self, forKey: .conditionText)
    symbolName = try container.decode(String.self, forKey: .symbolName)
    high = try container.decode(Double.self, forKey: .high)
    low = try container.decode(Double.self, forKey: .low)
    hourly = try container.decode([HourlyForecast].self, forKey: .hourly)
    daily = try container.decodeIfPresent([DailyForecast].self, forKey: .daily) ?? []
    fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
    grokCastScore = try container.decodeIfPresent(Int.self, forKey: .grokCastScore)
    grokCastScoreLabel = try container.decodeIfPresent(String.self, forKey: .grokCastScoreLabel)
    minutecastMessage = try container.decodeIfPresent(String.self, forKey: .minutecastMessage)
    grokBriefOneLiner = try container.decodeIfPresent(String.self, forKey: .grokBriefOneLiner)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(location, forKey: .location)
    try container.encode(currentTemp, forKey: .currentTemp)
    try container.encode(conditionText, forKey: .conditionText)
    try container.encode(symbolName, forKey: .symbolName)
    try container.encode(high, forKey: .high)
    try container.encode(low, forKey: .low)
    try container.encode(hourly, forKey: .hourly)
    if !daily.isEmpty {
      try container.encode(daily, forKey: .daily)
    }
    try container.encode(fetchedAt, forKey: .fetchedAt)
    try container.encodeIfPresent(grokCastScore, forKey: .grokCastScore)
    try container.encodeIfPresent(grokCastScoreLabel, forKey: .grokCastScoreLabel)
    try container.encodeIfPresent(minutecastMessage, forKey: .minutecastMessage)
    try container.encodeIfPresent(grokBriefOneLiner, forKey: .grokBriefOneLiner)
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
    daily = Array(weather.daily.prefix(10))
    fetchedAt = weather.fetchedAt
    grokCastScore = nil
    grokCastScoreLabel = nil
    minutecastMessage = nil
    grokBriefOneLiner = nil
  }

  /// Builds a widget snapshot with score, minutecast, and optional Grok one-liner.
  init(
    weather: GrokCastWeather,
    grokCastScore: Int,
    grokCastScoreLabel: String,
    minutecastMessage: String,
    grokBriefOneLiner: String?
  ) {
    location = weather.location
    currentTemp = weather.currentTemp
    conditionText = weather.conditionText
    symbolName = weather.symbolName
    high = weather.high
    low = weather.low
    hourly = Array(weather.hourly.prefix(4))
    daily = Array(weather.daily.prefix(10))
    fetchedAt = weather.fetchedAt
    self.grokCastScore = grokCastScore
    self.grokCastScoreLabel = grokCastScoreLabel
    self.minutecastMessage = minutecastMessage
    self.grokBriefOneLiner = grokBriefOneLiner
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
    let daily = (0..<5).map { offset in
      let date = Calendar.current.date(byAdding: .day, value: offset, to: now) ?? now
      let symbols = ["sun.max.fill", "cloud.sun.fill", "cloud.fill", "cloud.rain.fill", "sun.max.fill"]
      let codes = [0, 2, 3, 61, 0]
      return DailyForecast(
        date: date,
        high: 78 + Double(offset),
        low: 62 - Double(offset),
        precipChance: offset == 3 ? 70 : (offset == 2 ? 30 : 0),
        weatherCode: codes[offset],
        symbolName: symbols[offset],
        uvMax: 6,
        rainSum: offset == 3 ? 0.4 : nil,
        showersSum: nil,
        snowfallSum: nil
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
      daily: daily,
      fetchedAt: now,
      grokCastScore: 82,
      grokCastScoreLabel: "Go Outside",
      minutecastMessage: "No precipitation for at least 2 hours",
      grokBriefOneLiner: "Light jacket this morning; great afternoon for a walk."
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
    daily = snapshot.daily
    minutely15 = []
  }
}
