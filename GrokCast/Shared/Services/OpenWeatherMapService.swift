import Foundation

@Observable
final class OpenWeatherMapService {
  var isLoading = false
  var error: String?

  /// Last successful data source (useful when debugging subscription status).
  private(set) var lastDataSource: DataSource?

  enum DataSource: Equatable {
    case oneCall4
    case legacy25
  }

  private static let maxRetries = 2
  private static let retryBaseDelay: TimeInterval = 1.5

  static func userFriendlyMessage(for error: Error) -> String {
    if let serviceError = error as? ServiceError {
      return serviceError.userMessage
    }
    if let urlError = error as? URLError {
      switch urlError.code {
      case .badServerResponse:
        return "OpenWeatherMap service is temporarily unavailable. Tap RETRY in a moment."
      case .timedOut:
        return "OpenWeatherMap timed out. Tap RETRY in a moment."
      case .notConnectedToInternet, .networkConnectionLost:
        return "No internet connection. Check your network and tap RETRY."
      default:
        return "Network error: \(urlError.localizedDescription)"
      }
    }
    if error is DecodingError {
      return "OpenWeatherMap returned data in an unexpected format. Tap RETRY."
    }
    return error.localizedDescription
  }

  func fetchCurrentWeather(for location: SavedLocation) async throws -> OpenWeatherMapCurrentWeather {
    isLoading = true
    error = nil
    defer { isLoading = false }

    let hybrid = try await fetchHybrid(for: location)
    return hybrid.0
  }

  func fetchForecast(for location: SavedLocation, hours: Int = 40) async throws
    -> OpenWeatherMapForecast
  {
    isLoading = true
    error = nil
    defer { isLoading = false }

    let hybrid = try await fetchHybrid(for: location)
    let maxEntries = min(max(hours, 1), 40)
    let trimmed = Array(hybrid.1.entries.prefix(maxEntries))
    return OpenWeatherMapForecast(locationName: hybrid.1.locationName, entries: trimmed)
  }

  /// Fetches current + hourly outlook for the hybrid Today/Forecast layer.
  /// Prefers One Call API 4.0; falls back to legacy 2.5 endpoints when subscription is missing.
  func fetchHybrid(for location: SavedLocation) async throws -> (
    OpenWeatherMapCurrentWeather, OpenWeatherMapForecast
  ) {
    isLoading = true
    error = nil
    defer { isLoading = false }

    if let oneCall = try? await fetchHybridOneCall(for: location) {
      lastDataSource = .oneCall4
      return oneCall
    }

    lastDataSource = .legacy25
    async let currentTask = fetchCurrentPayloadLegacy(for: location)
    async let forecastTask = fetchForecastPayloadLegacy(for: location, hours: 40)
    return try await (currentTask, forecastTask)
  }

  func fetchHourlyTimeline(for location: SavedLocation) async throws -> OpenWeatherMapForecast {
    isLoading = true
    error = nil
    defer { isLoading = false }

    if let timeline = try? await fetchHourlyTimelineOneCall(for: location) {
      lastDataSource = .oneCall4
      return timeline
    }

    lastDataSource = .legacy25
    return try await fetchForecastPayloadLegacy(for: location, hours: 40)
  }

  // MARK: - One Call API 4.0

  private func fetchHybridOneCall(for location: SavedLocation) async throws -> (
    OpenWeatherMapCurrentWeather, OpenWeatherMapForecast
  ) {
    async let currentTask = fetchCurrentOneCall(for: location)
    async let forecastTask = fetchHourlyTimelineOneCall(for: location)
    return try await (currentTask, forecastTask)
  }

  private func fetchCurrentOneCall(for location: SavedLocation) async throws
    -> OpenWeatherMapCurrentWeather
  {
    guard let url = OpenWeatherMapKeys.oneCallCurrentURL(
      lat: location.latitude,
      lon: location.longitude,
      units: "imperial"
    ) else {
      throw ServiceError.badURL
    }

    let decoded: OneCallCurrentResponse = try await requestDecodable(url: url)
    guard let point = decoded.data.first else {
      throw ServiceError.emptyResponse
    }

    return OpenWeatherMapCurrentWeather(
      locationName: location.name,
      temperatureF: point.temp,
      feelsLikeF: point.feelsLike,
      condition: point.weather.first?.description.capitalized ?? "Unknown",
      humidityPercent: point.humidity,
      windSpeedMph: point.windSpeed,
      windDirectionDegrees: point.windDeg,
      cloudCoverPercent: point.clouds,
      observedAt: Date(timeIntervalSince1970: point.dt)
    )
  }

  private func fetchHourlyTimelineOneCall(for location: SavedLocation) async throws
    -> OpenWeatherMapForecast
  {
    guard let initialURL = OpenWeatherMapKeys.oneCallHourlyTimelineURL(
      lat: location.latitude,
      lon: location.longitude,
      units: "imperial"
    ) else {
      throw ServiceError.badURL
    }

    var allPoints: [OneCallTimelineDataPoint] = []
    var nextURL: URL? = initialURL
    var pageCount = 0

    while let url = nextURL, pageCount < 3 {
      let page: OneCallTimelineResponse = try await requestDecodable(url: url)
      allPoints.append(contentsOf: page.data)
      nextURL = page.next.flatMap { URL(string: $0) }
      pageCount += 1
      if allPoints.count >= 48 { break }
    }

    let now = Date()
    let futurePoints = allPoints.filter { Date(timeIntervalSince1970: $0.dt) >= now }
    let entries = (futurePoints.isEmpty ? allPoints : futurePoints).prefix(40).map { point in
      OpenWeatherMapForecastEntry(
        time: Date(timeIntervalSince1970: point.dt),
        temperatureF: point.temp,
        condition: point.weather.first?.description.capitalized ?? "Unknown",
        precipitationChance: Int(((point.pop ?? 0) * 100).rounded()),
        windSpeedMph: point.windSpeed
      )
    }

    return OpenWeatherMapForecast(locationName: location.name, entries: Array(entries))
  }

  // MARK: - Legacy 2.5 API (fallback)

  private func fetchCurrentPayloadLegacy(for location: SavedLocation) async throws
    -> OpenWeatherMapCurrentWeather
  {
    guard let url = OpenWeatherMapKeys.weatherURL(
      lat: location.latitude,
      lon: location.longitude,
      units: "imperial"
    ) else {
      throw ServiceError.badURL
    }

    let decoded: OpenWeatherMapCurrentResponse = try await requestDecodable(url: url)
    return mapCurrentLegacy(location: location, response: decoded)
  }

  private func fetchForecastPayloadLegacy(for location: SavedLocation, hours: Int) async throws
    -> OpenWeatherMapForecast
  {
    guard let url = OpenWeatherMapKeys.forecastURL(
      lat: location.latitude,
      lon: location.longitude,
      units: "imperial",
      count: min(max(hours / 3, 1), 40)
    ) else {
      throw ServiceError.badURL
    }

    let decoded: OpenWeatherMapForecastResponse = try await requestDecodable(url: url)
    return mapForecastLegacy(location: location, response: decoded)
  }

  // MARK: - Networking

  private func requestDecodable<T: Decodable>(url: URL) async throws -> T {
    var attempt = 0
    while true {
      do {
        let (data, response) = try await URLSession.shared.data(from: url)
        try validateHTTP(response: response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
      } catch let serviceError as ServiceError where serviceError.isRateLimited && attempt < Self.maxRetries {
        attempt += 1
        let delay = Self.retryBaseDelay * pow(2, Double(attempt - 1))
        try await Task.sleep(for: .seconds(delay))
        continue
      } catch {
        throw error
      }
    }
  }

  private func validateHTTP(response: URLResponse, data: Data) throws {
    guard let http = response as? HTTPURLResponse else { return }

    if http.statusCode == 429 {
      throw ServiceError.rateLimited
    }

    guard (200..<300).contains(http.statusCode) else {
      if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let message = json["message"] as? String
      {
        if http.statusCode == 401, message.lowercased().contains("one call") {
          throw ServiceError.oneCallSubscriptionRequired(message)
        }
        throw ServiceError.http(status: http.statusCode, message: message)
      }
      throw ServiceError.http(status: http.statusCode, message: "HTTP \(http.statusCode)")
    }
  }

  private func mapCurrentLegacy(
    location: SavedLocation,
    response: OpenWeatherMapCurrentResponse
  ) -> OpenWeatherMapCurrentWeather {
    OpenWeatherMapCurrentWeather(
      locationName: response.name.isEmpty ? location.name : response.name,
      temperatureF: response.main.temp,
      feelsLikeF: response.main.feelsLike,
      condition: response.weather.first?.description.capitalized ?? "Unknown",
      humidityPercent: response.main.humidity,
      windSpeedMph: response.wind?.speed ?? 0,
      windDirectionDegrees: response.wind?.deg,
      cloudCoverPercent: response.clouds?.all ?? 0,
      observedAt: Date(timeIntervalSince1970: response.dt)
    )
  }

  private func mapForecastLegacy(
    location: SavedLocation,
    response: OpenWeatherMapForecastResponse
  ) -> OpenWeatherMapForecast {
    let entries = response.list.map { item in
      OpenWeatherMapForecastEntry(
        time: Date(timeIntervalSince1970: item.dt),
        temperatureF: item.main.temp,
        condition: item.weather.first?.description.capitalized ?? "Unknown",
        precipitationChance: Int(((item.pop ?? 0) * 100).rounded()),
        windSpeedMph: item.wind?.speed ?? 0
      )
    }

    let name = response.city.name.isEmpty ? location.name : response.city.name
    return OpenWeatherMapForecast(locationName: name, entries: entries)
  }
}

extension OpenWeatherMapService {
  enum ServiceError: Error {
    case badURL
    case emptyResponse
    case rateLimited
    case oneCallSubscriptionRequired(String)
    case http(status: Int, message: String)

    var isRateLimited: Bool {
      if case .rateLimited = self { return true }
      return false
    }

    var userMessage: String {
      switch self {
      case .badURL:
        return "OpenWeatherMap request URL is invalid."
      case .emptyResponse:
        return "OpenWeatherMap returned no weather data."
      case .rateLimited:
        return "OpenWeatherMap rate limit reached. Tap RETRY in a moment."
      case .oneCallSubscriptionRequired(let message):
        return message
      case .http(_, let message):
        return message
      }
    }
  }
}