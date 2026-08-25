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
  func fetchForecast(for location: SavedLocation, units: TemperatureUnit = .fahrenheit) async throws
    -> DayCastWeather
  {
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
          "temperature_2m,relative_humidity_2m,apparent_temperature,dew_point_2m,is_day,precipitation,weather_code,wind_speed_10m,wind_direction_10m,visibility,surface_pressure,cloud_cover"
      ),
      URLQueryItem(
        name: "hourly",
        value:
          "temperature_2m,apparent_temperature,relative_humidity_2m,dew_point_2m,weather_code,precipitation_probability,uv_index,rain,showers,snowfall,is_day,wind_speed_10m,wind_direction_10m,visibility,surface_pressure,cloud_cover"
      ),
      URLQueryItem(
        name: "daily",
        value:
          "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max,rain_sum,showers_sum,snowfall_sum,sunrise,sunset"
      ),
      URLQueryItem(
        name: "minutely_15",
        value: "precipitation,precipitation_probability"
      ),
      URLQueryItem(name: "timezone", value: "auto"),
      URLQueryItem(name: "forecast_days", value: "10"),
      URLQueryItem(name: "temperature_unit", value: units.openMeteoTemperatureUnit),
      URLQueryItem(name: "windspeed_unit", value: units.openMeteoWindSpeedUnit),
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

    let weather = OpenMeteoWeatherMapper.map(
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
        name: "hourly",
        value:
          "pm10,pm2_5,us_aqi,uv_index,alder_pollen,birch_pollen,grass_pollen,ragweed_pollen"),
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

}

enum OpenMeteoWeatherMapper {
  static func map(
    location: SavedLocation,
    response: OpenMeteoResponse,
    airQuality: AirQualityResponse?,
    fetchedAt: Date = Date()
  ) -> DayCastWeather {

    let current = response.current
    let hourly = response.hourly
    let daily = response.daily

    let currentTemp = current?.temperature_2m ?? 0
    let feels = current?.apparent_temperature ?? currentTemp
    let humidity = current?.relative_humidity_2m ?? 50
    let wind = current?.wind_speed_10m ?? 0
    let code = current?.weather_code ?? 0
    let (symbol, text) = mapWeatherCode(code, isDay: (current?.is_day ?? 1) == 1)
    let currentWindDirection = current?.wind_direction_10m
    let currentDewPoint = current?.dew_point_2m
    let currentVisibility = current?.visibility
    let currentPressure = current?.surface_pressure
    let currentCloudCover = current?.cloud_cover

    // Robust date parsing for Open-Meteo responses.
    // `timezone=auto` returns wall-clock strings in the *location* timezone.
    let responseTimeZone =
      response.timezone.flatMap { TimeZone(identifier: $0) } ?? TimeZone.current
    var locationCalendar = Calendar(identifier: .gregorian)
    locationCalendar.timeZone = responseTimeZone

    let openMeteoHourFormatter: DateFormatter = {
      let f = DateFormatter()
      f.dateFormat = "yyyy-MM-dd'T'HH:mm"
      f.locale = Locale(identifier: "en_US_POSIX")
      f.timeZone = responseTimeZone
      return f
    }()

    let openMeteoDayFormatter: DateFormatter = {
      let f = DateFormatter()
      f.dateFormat = "yyyy-MM-dd"
      f.locale = Locale(identifier: "en_US_POSIX")
      f.timeZone = responseTimeZone
      return f
    }()

    // Fallback ISO parser (more lenient)
    let isoFallback = ISO8601DateFormatter()

    func parseHourlyDate(_ string: String) -> Date {
      if let date = openMeteoHourFormatter.date(from: string) { return date }
      if let date = isoFallback.date(from: string) { return date }
      // Last resort: use current time + offset so we don't collapse everything
      return Date().addingTimeInterval(Double(allHourlyForecasts.count) * 3600)
    }

    func parseDailyDate(_ string: String) -> Date {
      if let date = openMeteoDayFormatter.date(from: string) { return date }
      if let date = isoFallback.date(from: string) { return date }
      return Date()
    }

    // Build hourly array — keep the next 24 hours from "now", not midnight.
    var allHourlyForecasts: [HourlyForecast] = []
    if let h = hourly {
      for i in 0..<h.time.count {
        let date = parseHourlyDate(h.time[i])
        let weatherCode = openMeteoValue(h.weather_code, at: i) ?? 0
        let hourIsDay = openMeteoValue(h.is_day, at: i).map { $0 == 1 }
        let (sym, _) = mapWeatherCode(weatherCode, isDay: hourIsDay ?? true)
        allHourlyForecasts.append(
          HourlyForecast(
            time: date,
            temp: openMeteoValue(h.temperature_2m, at: i) ?? 0,
            precipChance: openMeteoValue(h.precipitation_probability, at: i) ?? 0,
            weatherCode: weatherCode,
            symbolName: sym,
            rain: openMeteoValue(h.rain, at: i),
            showers: openMeteoValue(h.showers, at: i),
            snowfall: openMeteoValue(h.snowfall, at: i),
            isDay: hourIsDay,
            feelsLike: openMeteoValue(h.apparent_temperature, at: i),
            humidity: openMeteoValue(h.relative_humidity_2m, at: i),
            dewPoint: openMeteoValue(h.dew_point_2m, at: i),
            windSpeed: openMeteoValue(h.wind_speed_10m, at: i),
            windDirection: openMeteoValue(h.wind_direction_10m, at: i),
            uvIndex: openMeteoValue(h.uv_index, at: i),
            visibilityMeters: openMeteoValue(h.visibility, at: i),
            pressureHPa: openMeteoValue(h.surface_pressure, at: i),
            cloudCoverPercent: openMeteoValue(h.cloud_cover, at: i)
          ))
      }
    }
    let hourStart =
      locationCalendar.dateInterval(of: .hour, for: Date())?.start
      ?? Date().addingTimeInterval(-60)
    let hourlyForecasts = Array(
      allHourlyForecasts.lazy.filter { $0.time >= hourStart }.prefix(HourlyGraphHours.fullLimit)
    )

    // Build daily (10 days) — derive precip % + weather code from hourly when daily aggregates disagree.
    var dailyForecasts: [DailyForecast] = []
    if let d = daily {
      let count = min(10, d.time.count)
      for i in 0..<count {
        let date = parseDailyDate(d.time[i])
        let slices =
          hourly.map { h in
            OpenMeteoDailyDerivation.hourlySlices(
              for: date,
              hourly: h,
              parseHour: parseHourlyDate,
              calendar: locationCalendar
            )
          } ?? []
        let apiPrecip = openMeteoValue(d.precipitation_probability_max, at: i) ?? 0
        let precipChance = OpenMeteoDailyDerivation.derivedPrecipChance(
          dailyAPI: apiPrecip, slices: slices)
        let apiCode = openMeteoValue(d.weather_code, at: i) ?? 0
        let weatherCode = OpenMeteoDailyDerivation.derivedWeatherCode(
          dailyAPI: apiCode, precipChance: precipChance, slices: slices)
        let (sym, _) = mapWeatherCode(weatherCode, isDay: true)
        let sunriseDate: Date? = d.sunrise.flatMap { $0.count > i ? parseHourlyDate($0[i]) : nil }
        let sunsetDate: Date? = d.sunset.flatMap { $0.count > i ? parseHourlyDate($0[i]) : nil }
        dailyForecasts.append(
          DailyForecast(
            date: date,
            high: openMeteoValue(d.temperature_2m_max, at: i) ?? 0,
            low: openMeteoValue(d.temperature_2m_min, at: i) ?? 0,
            precipChance: precipChance,
            weatherCode: weatherCode,
            symbolName: sym,
            uvMax: openMeteoValue(d.uv_index_max, at: i),
            rainSum: openMeteoValue(d.rain_sum, at: i),
            showersSum: openMeteoValue(d.showers_sum, at: i),
            snowfallSum: openMeteoValue(d.snowfall_sum, at: i),
            sunrise: sunriseDate,
            sunset: sunsetDate
          ))
      }
    }

    // Air quality: nearest hour to now, not midnight (hourly[0]).
    var aqi: Int? = nil
    var pm25: Double? = nil
    var pm10: Double? = nil
    var pollen: String? = nil
    var pollenConditions: PollenConditions? = nil

    if let aq = airQuality?.hourly, !aq.time.isEmpty {
      let aqTimeZone =
        airQuality?.timezone.flatMap { TimeZone(identifier: $0) } ?? responseTimeZone
      var aqCalendar = Calendar(identifier: .gregorian)
      aqCalendar.timeZone = aqTimeZone
      let aqHourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = aqTimeZone
        return f
      }()
      let aqDates = aq.time.map { aqHourFormatter.date(from: $0) ?? isoFallback.date(from: $0) }
      let aqHourStart = aqCalendar.dateInterval(of: .hour, for: Date())?.start ?? Date()
      if let idx = OpenMeteoHourIndex.nearest(in: aqDates, to: aqHourStart) {
        aqi = openMeteoValue(aq.us_aqi, at: idx)
        pm25 = openMeteoValue(aq.pm2_5, at: idx)
        pm10 = openMeteoValue(aq.pm10, at: idx)
        pollenConditions = PollenConditions.from(
          grass: openMeteoValue(aq.grass_pollen, at: idx),
          birch: openMeteoValue(aq.birch_pollen, at: idx),
          alder: openMeteoValue(aq.alder_pollen, at: idx),
          ragweed: openMeteoValue(aq.ragweed_pollen, at: idx)
        )
        pollen = pollenConditions?.category
      }
    }

    let high = dailyForecasts.first?.high ?? currentTemp + 5
    let low = dailyForecasts.first?.low ?? currentTemp - 8
    let precip = hourlyForecasts.first?.precipChance ?? 0
    let uv = hourlyForecasts.first?.uvIndex ?? 0

    // Minutecast: parse the full minutely_15 series, then keep the next ~2 hours.
    // Taking only the first 8 slots left the strip empty after morning (those slots are past).
    var allMinutelyForecasts: [MinutelyForecast] = []
    if let m = response.minutely_15 {
      for i in 0..<m.time.count {
        let date = parseHourlyDate(m.time[i])
        allMinutelyForecasts.append(
          MinutelyForecast(
            time: date,
            precipitation: openMeteoValue(m.precipitation, at: i) ?? 0,
            precipChance: openMeteoValue(m.precipitation_probability, at: i) ?? 0
          ))
      }
    }
    let minutelyCutoff = Date().addingTimeInterval(-60)
    let minutelyForecasts = Array(
      allMinutelyForecasts.lazy.filter { $0.time >= minutelyCutoff }.prefix(8)
    )

    return DayCastWeather(
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
      fetchedAt: fetchedAt,
      timezoneIdentifier: response.timezone,
      airQualityIndex: aqi,
      pm25: pm25,
      pollenLevel: pollen,
      hourly: hourlyForecasts,
      daily: dailyForecasts,
      minutely15: minutelyForecasts,
      windDirection: currentWindDirection,
      dewPoint: currentDewPoint,
      visibilityMeters: currentVisibility,
      pressureHPa: currentPressure,
      cloudCoverPercent: currentCloudCover,
      pm10: pm10,
      pollen: pollenConditions
    )
  }
}
