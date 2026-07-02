import CoreLocation
import Foundation

@Observable
final class OpenMeteoService {
  var isLoading = false
  var error: String?

  /// Centralized helper for turning Open-Meteo (and similar future service) errors
  /// into calm, actionable user-facing strings. Mirrors/enhances the prior store logic
  /// but lives in the service for "future services" reuse (per task).
  static func userFriendlyMessage(for error: Error) -> String {
    if let urlError = error as? URLError {
      switch urlError.code {
      case .badServerResponse:
        return "Weather service is temporarily unavailable (server error). Tap RETRY in a moment."
      case .timedOut:
        return "The weather service timed out. Tap RETRY in a moment."
      case .notConnectedToInternet, .networkConnectionLost:
        return "No internet connection. Check your Wi-Fi or cellular and tap RETRY."
      case .secureConnectionFailed,
        .serverCertificateUntrusted,
        .serverCertificateHasBadDate,
        .serverCertificateHasUnknownRoot,
        .serverCertificateNotYetValid:
        return
          "Weather service connection failed (TLS/secure error). This is common in the iOS Simulator. Tap RETRY or try again in a moment."
      default:
        return "Network error: \(urlError.localizedDescription)"
      }
    }
    if error is DecodingError {
      return
        "Weather data from the service was in an unexpected format (decode failed). Tap RETRY or try again in a moment."
    }
    return error.localizedDescription
  }

  // Main forecast + current
  func fetchForecast(for location: SavedLocation) async throws -> GrokCastWeather {
    isLoading = true
    error = nil

    let url = URL(string: "https://api.open-meteo.com/v1/forecast")!
    var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
    components.queryItems = [
      URLQueryItem(name: "latitude", value: "\(location.latitude)"),
      URLQueryItem(name: "longitude", value: "\(location.longitude)"),
      URLQueryItem(
        name: "current",
        value:
          "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m"
      ),
      URLQueryItem(
        name: "hourly",
        value:
          "temperature_2m,weather_code,precipitation_probability,uv_index,rain,showers,snowfall"),
      URLQueryItem(
        name: "daily",
        value:
          "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max,rain_sum,showers_sum,snowfall_sum"
      ),
      URLQueryItem(name: "timezone", value: "auto"),
      URLQueryItem(name: "forecast_days", value: "10"),
      // Request imperial units so temps are °F and wind in MPH (matches US-focused display and prompts)
      URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
      URLQueryItem(name: "windspeed_unit", value: "mph"),
      URLQueryItem(name: "precipitation_unit", value: "inch"),
    ]

    // Launch forecast fetch and air quality (best-effort) in parallel using structured concurrency.
    // Air remains optional/non-fatal ("best effort") as before; both networks now overlap.
    // Capture the URL before the concurrent lets (avoids "captured var in concurrently-executing code").
    let forecastURL = components.url!
    async let forecastTask = URLSession.shared.data(from: forecastURL)
    async let airOpt: AirQualityResponse? = try? await fetchAirQuality(for: location)

    // Await the throwing primary separately (with try) and the best-effort air without;
    // the two async lets run their underlying work concurrently.
    let (data, response) = try await forecastTask
    let air = await airOpt

    // Do not attempt JSON decode on error responses (e.g. 502 returns HTML error page).
    // This prevents "data corrupted / not valid JSON" parsing errors on server issues.
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
        _ = String(data: data, encoding: .utf8) ?? "<non-text body>"
      // OPEN-METEO BAD HTTP STATUS (logs removed for release)
      throw URLError(
        .badServerResponse,
        userInfo: [NSLocalizedDescriptionKey: "Weather service returned HTTP \(http.statusCode)"]
      )
    }

    let decoded: OpenMeteoResponse
    do {
      decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
    } catch {
      // OPEN-METEO DECODE ERROR (logs removed)
      throw error
    }

    // Air quality already fetched in parallel above (best effort, may be nil on error/timeout)

    let weather = mapToGrokCastWeather(
      location: location,
      response: decoded,
      airQuality: air
    )

    isLoading = false
    return weather
  }

  private func fetchAirQuality(for location: SavedLocation) async throws -> AirQualityResponse {
    let url = URL(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!
    var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
    components.queryItems = [
      URLQueryItem(name: "latitude", value: "\(location.latitude)"),
      URLQueryItem(name: "longitude", value: "\(location.longitude)"),
      URLQueryItem(
        name: "hourly", value: "pm10,pm2_5,us_aqi,uv_index,alder_pollen,birch_pollen,grass_pollen"),
      URLQueryItem(name: "timezone", value: "auto"),
    ]

    let (data, response) = try await URLSession.shared.data(from: components.url!)

    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
      throw URLError(
        .badServerResponse,
        userInfo: [NSLocalizedDescriptionKey: "Air quality service HTTP \(http.statusCode)"])
    }

    return try JSONDecoder().decode(AirQualityResponse.self, from: data)
  }

  private func mapToGrokCastWeather(
    location: SavedLocation,
    response: OpenMeteoResponse,
    airQuality: AirQualityResponse?
  ) -> GrokCastWeather {

    let current = response.current
    let hourly = response.hourly
    let daily = response.daily

    let currentTemp = current?.temperature_2m ?? 0
    let feels = current?.apparent_temperature ?? currentTemp
    let humidity = current?.relative_humidity_2m ?? 50
    let wind = current?.wind_speed_10m ?? 0
    let code = current?.weather_code ?? 0
    let (symbol, text) = mapWeatherCode(code, isDay: (current?.is_day ?? 1) == 1)

    // Robust date parsing for Open-Meteo responses
    // Open-Meteo returns times in the format requested via "timezone=auto"
    let openMeteoHourFormatter: DateFormatter = {
      let f = DateFormatter()
      f.dateFormat = "yyyy-MM-dd'T'HH:mm"
      f.locale = Locale(identifier: "en_US_POSIX")
      f.timeZone = TimeZone.current
      return f
    }()

    let openMeteoDayFormatter: DateFormatter = {
      let f = DateFormatter()
      f.dateFormat = "yyyy-MM-dd"
      f.locale = Locale(identifier: "en_US_POSIX")
      f.timeZone = TimeZone.current
      return f
    }()

    // Fallback ISO parser (more lenient)
    let isoFallback = ISO8601DateFormatter()

    func parseHourlyDate(_ string: String) -> Date {
      if let date = openMeteoHourFormatter.date(from: string) { return date }
      if let date = isoFallback.date(from: string) { return date }
      // Last resort: use current time + offset so we don't collapse everything
      return Date().addingTimeInterval(Double(hourlyForecasts.count) * 3600)
    }

    func parseDailyDate(_ string: String) -> Date {
      if let date = openMeteoDayFormatter.date(from: string) { return date }
      if let date = isoFallback.date(from: string) { return date }
      return Date()
    }

    // Build hourly array (next 24)
    var hourlyForecasts: [HourlyForecast] = []
    if let h = hourly {
      let count = min(24, h.time.count)
      for i in 0..<count {
        let date = parseHourlyDate(h.time[i])
        let (sym, _) = mapWeatherCode(h.weather_code[i] ?? 0)
        hourlyForecasts.append(
          HourlyForecast(
            time: date,
            temp: h.temperature_2m[i] ?? 0,
            precipChance: h.precipitation_probability?[i] ?? 0,
            weatherCode: h.weather_code[i] ?? 0,
            symbolName: sym,
            rain: h.rain?[i] ?? nil,
            showers: h.showers?[i] ?? nil,
            snowfall: h.snowfall?[i] ?? nil
          ))
      }
    }

    // Build daily (10 days)
    var dailyForecasts: [DailyForecast] = []
    if let d = daily {
      let count = min(10, d.time.count)
      for i in 0..<count {
        let date = parseDailyDate(d.time[i])
        let (sym, _) = mapWeatherCode(d.weather_code[i] ?? 0)
        dailyForecasts.append(
          DailyForecast(
            date: date,
            high: d.temperature_2m_max[i] ?? 0,
            low: d.temperature_2m_min[i] ?? 0,
            precipChance: d.precipitation_probability_max?[i] ?? 0,
            weatherCode: d.weather_code[i] ?? 0,
            symbolName: sym,
            uvMax: d.uv_index_max?[i] ?? nil,
            rainSum: d.rain_sum?[i] ?? nil,
            showersSum: d.showers_sum?[i] ?? nil,
            snowfallSum: d.snowfall_sum?[i] ?? nil
          ))
      }
    }

    // Air quality extraction (current hour)
    var aqi: Int? = nil
    var pm25: Double? = nil
    var pollen = "Low"

    if let aq = airQuality?.hourly, !aq.time.isEmpty {
      aqi = aq.us_aqi?.first ?? nil
      pm25 = aq.pm2_5?.first ?? nil
      // Simple pollen aggregation
      let g: Double = aq.grass_pollen?.compactMap { $0 }.first ?? 0.0
      let b: Double = aq.birch_pollen?.compactMap { $0 }.first ?? 0.0
      let a: Double = aq.alder_pollen?.compactMap { $0 }.first ?? 0.0
      let maxPollen = max(g, b, a)
      if maxPollen > 50 { pollen = "High" } else if maxPollen > 20 { pollen = "Moderate" }
    }

    let high = dailyForecasts.first?.high ?? currentTemp + 5
    let low = dailyForecasts.first?.low ?? currentTemp - 8
    let precip = hourlyForecasts.first?.precipChance ?? 0
    let uv: Double =
      dailyForecasts.first?.uvMax
      ?? (hourly?.uv_index?.compactMap { $0 }.first ?? 3.0)

    return GrokCastWeather(
      location: location,
      currentTemp: currentTemp,
      feelsLike: feels,
      conditionCode: code,
      conditionText: text,
      humidity: humidity,
      windSpeed: wind,
      uvIndex: uv,
      precipitationChance: precip,
      high: high,
      low: low,
      symbolName: symbol,
      fetchedAt: Date(),
      airQualityIndex: aqi,
      pm25: pm25,
      pollenLevel: pollen,
      hourly: hourlyForecasts,
      daily: dailyForecasts
    )
  }
}
