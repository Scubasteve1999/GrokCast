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

    let url = URL(string: "\(forecastURL)?latitude=\(coords.lat)&longitude=\(coords.lon)&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weathercode&temperature_unit=fahrenheit&precipitation_unit=inch&start_date=\(start)&end_date=\(end)&timezone=auto")!

    let (data, _) = try await URLSession.shared.data(from: url)
    let response = try JSONDecoder().decode(TripOpenMeteoResponse.self, from: data)

    let days = buildDays(from: response)
    let dateRange = "\(dayFormatter.string(from: startDate)) – \(dayFormatter.string(from: endDate))"

    let avgHigh = days.map(\.high).reduce(0, +) / Double(max(days.count, 1))
    let avgPrecip = days.map { Double($0.precipChance) }.reduce(0, +) / Double(max(days.count, 1))
    let avgScore = computeTripScore(avgHigh: avgHigh, avgPrecip: avgPrecip)

    let packing = buildPackingList(days: days)

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
    let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    let url = URL(string: "\(geocodeURL)?name=\(encoded)&count=1&language=en&format=json")!
    let (data, _) = try await URLSession.shared.data(from: url)
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
      return TripDayForecast(
        date: date,
        dayLabel: dayFormatter.string(from: date),
        high: daily.temperature_2m_max[index],
        low: daily.temperature_2m_min[index],
        precipChance: daily.precipitation_probability_max[index],
        condition: weatherConditionText(code: code),
        symbolName: weatherSymbol(code: code, isDay: true)
      )
    }
  }

  private static func computeTripScore(avgHigh: Double, avgPrecip: Double) -> Int {
    var score = 80
    if avgHigh > 95 { score -= 20 }
    else if avgHigh > 85 { score -= 10 }
    else if avgHigh < 40 { score -= 15 }
    else if avgHigh < 55 { score -= 5 }

    if avgPrecip > 60 { score -= 25 }
    else if avgPrecip > 30 { score -= 10 }

    return max(10, min(100, score))
  }

  private static func buildPackingList(days: [TripDayForecast]) -> [String] {
    var items: Set<String> = ["Phone charger"]

    let maxHigh = days.map(\.high).max() ?? 70
    let minLow = days.map(\.low).min() ?? 50
    let anyRain = days.contains { $0.precipChance > 30 }
    let anySnow = days.contains { $0.symbolName.contains("snow") }

    if maxHigh > 80 { items.insert("Sunscreen"); items.insert("Sunglasses") }
    if maxHigh > 90 { items.insert("Hat"); items.insert("Water bottle") }
    if minLow < 50 { items.insert("Light jacket") }
    if minLow < 35 { items.insert("Warm coat"); items.insert("Gloves") }
    if anyRain { items.insert("Umbrella"); items.insert("Rain jacket") }
    if anySnow { items.insert("Warm boots"); items.insert("Heavy coat") }
    if maxHigh - minLow > 25 { items.insert("Layers") }

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

  private static func weatherConditionText(code: Int) -> String {
    switch code {
    case 0: return "Clear"
    case 1: return "Mainly Clear"
    case 2: return "Partly Cloudy"
    case 3: return "Overcast"
    case 45, 48: return "Foggy"
    case 51, 53, 55: return "Drizzle"
    case 61, 63, 65: return "Rain"
    case 71, 73, 75, 77: return "Snow"
    case 80, 81, 82: return "Showers"
    case 85, 86: return "Snow Showers"
    case 95, 96, 99: return "Thunderstorm"
    default: return "Mixed"
    }
  }

  private static func weatherSymbol(code: Int, isDay: Bool) -> String {
    switch code {
    case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
    case 1: return isDay ? "sun.max.fill" : "moon.fill"
    case 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
    case 3: return "cloud.fill"
    case 45, 48: return "cloud.fog.fill"
    case 51, 53, 55: return "cloud.drizzle.fill"
    case 61, 63, 65: return "cloud.rain.fill"
    case 71, 73, 75, 77: return "cloud.snow.fill"
    case 80, 81, 82: return "cloud.heavyrain.fill"
    case 85, 86: return "cloud.snow.fill"
    case 95, 96, 99: return "cloud.bolt.rain.fill"
    default: return "cloud.fill"
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
