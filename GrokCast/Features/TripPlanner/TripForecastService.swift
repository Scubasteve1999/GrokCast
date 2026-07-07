import Foundation

struct TripDayForecast: Identifiable {
  let date: Date
  let dayLabel: String
  let high: Double
  let low: Double
  let precipChance: Int
  let condition: String
  let symbolName: String

  var id: Date { date }
}

struct TripForecastResult {
  let locationName: String
  let dateRange: String
  let days: [TripDayForecast]
  let averageScore: Int?
  let packingSuggestions: [String]?
  let grokAdvice: String?
}

enum TripForecastService {
  private static let geocodeURL = "https://geocoding-api.open-meteo.com/v1/search"
  private static let forecastURL = "https://api.open-meteo.com/v1/forecast"

  private static let dayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEE, MMM d"
    return f
  }()

  private static let isoDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
  }()

  @MainActor
  static func fetchForecast(
    destination: String,
    startDate: Date,
    endDate: Date,
    store: WeatherStore
  ) async throws -> TripForecastResult {
    let coords = try await geocode(destination)

    let start = isoDateFormatter.string(from: startDate)
    let end = isoDateFormatter.string(from: endDate)
    let tempUnit = store.temperatureUnit.openMeteoTemperatureUnit

    var forecastComponents = URLComponents(string: forecastURL)!
    forecastComponents.queryItems = [
      URLQueryItem(name: "latitude", value: String(coords.lat)),
      URLQueryItem(name: "longitude", value: String(coords.lon)),
      URLQueryItem(
        name: "daily",
        value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max,weathercode"),
      URLQueryItem(name: "temperature_unit", value: tempUnit),
      URLQueryItem(name: "precipitation_unit", value: "inch"),
      URLQueryItem(name: "start_date", value: start),
      URLQueryItem(name: "end_date", value: end),
      URLQueryItem(name: "timezone", value: "auto"),
    ]
    guard let url = forecastComponents.url else { throw TripPlannerError.locationNotFound }

    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      throw URLError(.badServerResponse)
    }
    let decoded = try JSONDecoder().decode(TripOpenMeteoResponse.self, from: data)

    let days = buildDays(from: decoded)
    let dateRange = "\(dayFormatter.string(from: startDate)) – \(dayFormatter.string(from: endDate))"

    let isCelsius = store.temperatureUnit == .celsius
    let avgHigh = days.map(\.high).reduce(0, +) / Double(max(days.count, 1))
    let avgPrecip = days.map { Double($0.precipChance) }.reduce(0, +) / Double(max(days.count, 1))
    let avgScore = computeTripScore(avgHigh: avgHigh, avgPrecip: avgPrecip, isCelsius: isCelsius)

    let packing = buildPackingList(days: days, isCelsius: isCelsius)

    var grokAdvice: String?
    if GrokAuthResolver.canAccessGrok(subscription: SubscriptionManager.shared) {
      grokAdvice = await fetchGrokAdvice(
        destination: coords.name,
        days: days,
        store: store
      )
    }

    return TripForecastResult(
      locationName: coords.name,
      dateRange: dateRange,
      days: days,
      averageScore: avgScore,
      packingSuggestions: packing,
      grokAdvice: grokAdvice
    )
  }

  private static func geocode(_ query: String) async throws -> (lat: Double, lon: Double, name: String) {
    var components = URLComponents(string: geocodeURL)!
    components.queryItems = [
      URLQueryItem(name: "name", value: query),
      URLQueryItem(name: "count", value: "1"),
      URLQueryItem(name: "language", value: "en"),
      URLQueryItem(name: "format", value: "json"),
    ]
    guard let url = components.url else { throw TripPlannerError.locationNotFound }
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      throw URLError(.badServerResponse)
    }
    let result = try JSONDecoder().decode(GeocodeResponse.self, from: data)
    guard let first = result.results?.first else {
      throw TripPlannerError.locationNotFound
    }
    let name = [first.name, first.admin1, first.country]
      .compactMap { $0 }
      .prefix(2)
      .joined(separator: ", ")
    return (first.latitude, first.longitude, name)
  }

  private static func buildDays(from response: TripOpenMeteoResponse) -> [TripDayForecast] {
    let daily = response.daily
    return zip(0..<daily.time.count, daily.time).map { index, dateStr in
      let date = isoDateFormatter.date(from: dateStr) ?? Date()
      let code = daily.weathercode[index]
      let (symbol, text) = mapWeatherCode(code, isDay: true)
      return TripDayForecast(
        date: date,
        dayLabel: dayFormatter.string(from: date),
        high: daily.temperature_2m_max[index],
        low: daily.temperature_2m_min[index],
        precipChance: daily.precipitation_probability_max[index],
        condition: text,
        symbolName: symbol
      )
    }
  }

  private static func computeTripScore(avgHigh: Double, avgPrecip: Double, isCelsius: Bool) -> Int {
    var score = 80

    let extremeHot: Double = isCelsius ? 35 : 95
    let hot: Double = isCelsius ? 29 : 85
    let cold: Double = isCelsius ? 4 : 40
    let cool: Double = isCelsius ? 13 : 55

    if avgHigh > extremeHot { score -= 20 }
    else if avgHigh > hot { score -= 10 }
    else if avgHigh < cold { score -= 15 }
    else if avgHigh < cool { score -= 5 }

    if avgPrecip > 60 { score -= 25 }
    else if avgPrecip > 30 { score -= 10 }

    return max(10, min(100, score))
  }

  private static func buildPackingList(days: [TripDayForecast], isCelsius: Bool) -> [String] {
    var items: Set<String> = ["Phone charger"]

    let maxHigh = days.map(\.high).max() ?? (isCelsius ? 21 : 70)
    let minLow = days.map(\.low).min() ?? (isCelsius ? 10 : 50)
    let anyRain = days.contains { $0.precipChance > 30 }
    let anySnow = days.contains { $0.symbolName.contains("snow") }

    let hotThreshold: Double = isCelsius ? 27 : 80
    let veryHotThreshold: Double = isCelsius ? 32 : 90
    let coolThreshold: Double = isCelsius ? 10 : 50
    let coldThreshold: Double = isCelsius ? 2 : 35
    let swingThreshold: Double = isCelsius ? 14 : 25

    if maxHigh > hotThreshold { items.insert("Sunscreen"); items.insert("Sunglasses") }
    if maxHigh > veryHotThreshold { items.insert("Hat"); items.insert("Water bottle") }
    if minLow < coolThreshold { items.insert("Light jacket") }
    if minLow < coldThreshold { items.insert("Warm coat"); items.insert("Gloves") }
    if anyRain { items.insert("Umbrella"); items.insert("Rain jacket") }
    if anySnow { items.insert("Warm boots"); items.insert("Heavy coat") }
    if maxHigh - minLow > swingThreshold { items.insert("Layers") }

    return items.sorted()
  }

  @MainActor
  private static func fetchGrokAdvice(
    destination: String,
    days: [TripDayForecast],
    store: WeatherStore
  ) async -> String? {
    let summary = days.map { "\($0.dayLabel): \($0.condition), \(Int($0.high))°/\(Int($0.low))°, \($0.precipChance)% precip" }
      .joined(separator: "\n")

    let prompt = """
      I'm traveling to \(destination). Here's the forecast:
      \(summary)

      Give me a 2-3 sentence travel weather tip — what to expect and any scheduling advice. Be conversational and specific.
      """

    do {
      var response = ""
      for try await chunk in store.grokBuildService.streamChat(messages: [.init(role: "user", content: prompt)]) {
        response += chunk
      }
      return response.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
      return nil
    }
  }

}

enum TripPlannerError: LocalizedError {
  case locationNotFound

  var errorDescription: String? {
    switch self {
    case .locationNotFound: return "Couldn't find that location. Try a different city name."
    }
  }
}

private struct GeocodeResponse: Decodable {
  let results: [GeocodeResult]?
}

private struct GeocodeResult: Decodable {
  let latitude: Double
  let longitude: Double
  let name: String?
  let admin1: String?
  let country: String?
}

private struct TripOpenMeteoResponse: Decodable {
  let daily: TripDailyData
}

private struct TripDailyData: Decodable {
  let time: [String]
  let temperature_2m_max: [Double]
  let temperature_2m_min: [Double]
  let precipitation_probability_max: [Int]
  let weathercode: [Int]
}
