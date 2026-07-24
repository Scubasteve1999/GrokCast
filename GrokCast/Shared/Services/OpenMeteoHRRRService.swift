import Foundation

/// Fetches CONUS HRRR 15-minute precip via Open-Meteo's GFS API.
/// Soft-fails to `nil` — never throws into UI layers.
final class OpenMeteoHRRRService: Sendable {

  /// Rough CONUS bbox (same spirit as NWS silence).
  static let conusLatitudeRange: ClosedRange<Double> = 24...50
  static let conusLongitudeRange: ClosedRange<Double> = -125...(-66)

  private let baseURL = URL(string: "https://api.open-meteo.com/v1/gfs")!
  private let session: URLSession

  /// Next 90 minutes in 15-minute steps.
  private let forecastSteps = 6

  init(session: URLSession = .shared) {
    self.session = session
  }

  static func isCONUS(latitude: Double, longitude: Double) -> Bool {
    conusLatitudeRange.contains(latitude) && conusLongitudeRange.contains(longitude)
  }

  /// Returns mapped minutely slots, or `nil` on non-CONUS / transport / decode failure.
  func fetchMinutely15(
    latitude: Double,
    longitude: Double
  ) async -> [MinutelyForecast]? {
    guard Self.isCONUS(latitude: latitude, longitude: longitude) else { return nil }

    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
    components.queryItems = [
      URLQueryItem(name: "latitude", value: String(latitude)),
      URLQueryItem(name: "longitude", value: String(longitude)),
      URLQueryItem(
        name: "minutely_15",
        value: "precipitation,precipitation_probability"
      ),
      URLQueryItem(name: "models", value: "ncep_hrrr_conus_15min"),
      URLQueryItem(name: "forecast_minutely_15", value: String(forecastSteps)),
      URLQueryItem(name: "timezone", value: "auto"),
      URLQueryItem(name: "precipitation_unit", value: "inch"),
    ]

    guard let url = components.url else { return nil }

    do {
      let (data, response) = try await session.data(from: url)
      guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode)
      else { return nil }

      let decoded = try JSONDecoder().decode(OpenMeteoHRRRResponse.self, from: data)
      guard let minutely = decoded.minutely_15, !minutely.time.isEmpty else { return nil }

      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone(identifier: decoded.timezone ?? "UTC")
        ?? TimeZone(secondsFromGMT: 0)
      formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

      let isoFallback = ISO8601DateFormatter()

      var slots: [MinutelyForecast] = []
      slots.reserveCapacity(minutely.time.count)
      for i in 0..<minutely.time.count {
        let timeString = minutely.time[i]
        let date =
          formatter.date(from: timeString)
          ?? isoFallback.date(from: timeString)
          ?? Date().addingTimeInterval(Double(i) * 15 * 60)
        let precip = openMeteoValue(minutely.precipitation, at: i) ?? 0
        let chance = openMeteoValue(minutely.precipitation_probability, at: i) ?? 0
        slots.append(
          MinutelyForecast(
            time: date,
            precipitation: precip,
            precipChance: chance
          ))
      }

      let cutoff = Date().addingTimeInterval(-60)
      let upcoming = Array(slots.lazy.filter { $0.time >= cutoff }.prefix(forecastSteps))
      return upcoming.isEmpty ? nil : upcoming
    } catch {
      return nil
    }
  }
}

// MARK: - Decode (GFS / HRRR minutely only)

private struct OpenMeteoHRRRResponse: Decodable {
  let timezone: String?
  let minutely_15: Minutely15?
}
