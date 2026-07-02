import Foundation

/// Lightweight service for official US National Weather Service (NWS) data.
/// Primary: active alerts for severe weather (used in Today banners + Storm Spotter prompts).
/// Follows the same URLSession + error patterns as OpenMeteoService but targets api.weather.gov.
/// NWS requires a User-Agent identifying the client.
/// US-only by nature of the API; non-US points return 200 with empty "features".
final class NWSService {

  private let baseURL = "https://api.weather.gov"
  private let userAgent = "GrokCast/1.0 (https://grokcast.app)"

  /// Fetches currently active NWS alerts for a point (lat,lon).
  /// Returns [] on success with no alerts (common for non-US or quiet US areas).
  /// - Parameter timeout: Request timeout in seconds (shorter for background fetches).
  func fetchActiveAlerts(for location: SavedLocation, timeout: TimeInterval = 15) async throws
    -> [NWSAlert]
  {
    try Task.checkCancellation()

    let lat = location.latitude
    let lon = location.longitude

    // Direct /alerts/active?point= is the recommended starting endpoint (per NWS docs + user spec).
    // No need to hit /points first for alerts.
    guard let url = URL(string: "\(baseURL)/alerts/active?point=\(lat),\(lon)") else {
      throw NWSServiceError.invalidURL
    }

    var request = URLRequest(url: url)
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    request.timeoutInterval = timeout

    let (data, response) = try await URLSession.shared.data(for: request)
    try Task.checkCancellation()

    guard let http = response as? HTTPURLResponse else {
      throw NWSServiceError.networkError
    }

    // NWS returns HTTP 200 + { "features": [] } for no alerts or non-US points.
    guard (200...299).contains(http.statusCode) else {
      let body = String(data: data, encoding: .utf8) ?? ""
      throw NWSServiceError.httpError(http.statusCode, body)
    }

    let decoder = JSONDecoder()
    // NWS alert timestamps are ISO-8601 (RFC3339).
    decoder.dateDecodingStrategy = .iso8601

    let alertsResponse = try decoder.decode(NWSAlertsResponse.self, from: data)

    return alertsResponse.features.compactMap { feature in
      let p = feature.properties

      // Prefer the NWS-provided feature id (stable string, often a URN/URL).
      // Fall back to a constructed value if absent (still stable enough for this transient model).
      let alertId = feature.id ?? "nws-\(p.event)-\(p.expires ?? "unknown")"

      let iso = ISO8601DateFormatter()
      iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

      var sentDate: Date?
      if let sentStr = p.sent {
        sentDate = iso.date(from: sentStr)
        if sentDate == nil {
          iso.formatOptions = [.withInternetDateTime]
          sentDate = iso.date(from: sentStr)
        }
      }

      var expiresDate: Date?
      if let expStr = p.expires {
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        expiresDate = iso.date(from: expStr)
        if expiresDate == nil {
          iso.formatOptions = [.withInternetDateTime]
          expiresDate = iso.date(from: expStr)
        }
      }

      let rep = feature.geometry?.representativePoint
      return NWSAlert(
        id: alertId,
        event: p.event,
        severity: p.severity,
        headline: p.headline,
        description: p.description,
        instruction: p.instruction,
        sent: sentDate,
        expires: expiresDate,
        areaDesc: p.areaDesc,
        latitude: rep?.latitude,
        longitude: rep?.longitude
      )
    }
  }

  /// Fetches the latest official observation from the nearest NWS station (ground truth).
  /// Returns nil gracefully for non-US, no stations, or any error (non-fatal, same as alerts).
  /// Uses the exact flow from the NWS hybrid plan: /points -> first observationStation -> /observations/latest.
  func fetchLatestObservation(for location: SavedLocation) async throws -> NWSObservation? {
    // 1. Get points for the lat/lon to discover observation stations
    guard
      let pointsURL = URL(string: "\(baseURL)/points/\(location.latitude),\(location.longitude)")
    else {
      return nil
    }
    var pointsRequest = URLRequest(url: pointsURL)
    pointsRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    pointsRequest.timeoutInterval = 15

    let (pointsData, pointsResponse) = try await URLSession.shared.data(for: pointsRequest)
    guard let pointsHTTP = pointsResponse as? HTTPURLResponse,
      (200...299).contains(pointsHTTP.statusCode)
    else {
      return nil
    }

    let points: NWSPointsResponse
    do {
      points = try JSONDecoder().decode(NWSPointsResponse.self, from: pointsData)
    } catch {
      // NWS points decode failed (logs removed for release)
      return nil
    }

    // observationStations is now a URL to the stations collection (not an array)
    let stationsCollectionURLStr = points.properties.observationStations
    guard let stationsCollectionURL = URL(string: stationsCollectionURLStr) else {
      return nil
    }

    // Fetch the stations collection to get the list of station URLs
    var stationsReq = URLRequest(url: stationsCollectionURL)
    stationsReq.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    stationsReq.timeoutInterval = 15

    let (stationsData, stationsResp) = try await URLSession.shared.data(for: stationsReq)
    guard let stationsHTTP = stationsResp as? HTTPURLResponse,
      (200...299).contains(stationsHTTP.statusCode)
    else {
      return nil
    }

    let stations: NWSStationsResponse
    do {
      stations = try JSONDecoder().decode(NWSStationsResponse.self, from: stationsData)
    } catch {
      // NWS stations collection decode failed (logs removed)
      return nil
    }

    guard let firstStation = stations.features.first else {
      return nil  // no stations (common for non-US or remote areas)
    }
    let firstStationURL = firstStation.id  // e.g. https://api.weather.gov/stations/KOLV

    // 2. Fetch latest observation for that station
    guard let obsURL = URL(string: "\(firstStationURL)/observations/latest") else {
      return nil
    }
    var obsRequest = URLRequest(url: obsURL)
    obsRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    obsRequest.timeoutInterval = 15

    let (obsData, obsHTTPResponse) = try await URLSession.shared.data(for: obsRequest)
    guard let obsHTTP = obsHTTPResponse as? HTTPURLResponse,
      (200...299).contains(obsHTTP.statusCode)
    else {
      return nil
    }

    let decodedObs: NWSObservationResponse
    do {
      decodedObs = try JSONDecoder().decode(NWSObservationResponse.self, from: obsData)
    } catch {
      // NWS obs decode failed (logs removed)
      return nil
    }
    let props = decodedObs.properties

    // Extract station ID from the station URL (e.g. .../stations/KOLV)
    let stationId: String
    if let stationStr = props.station, let last = stationStr.split(separator: "/").last {
      stationId = String(last)
    } else {
      stationId = "unknown"
    }

    // Parse timestamp (robust for NWS formats)
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var observedAt = iso.date(from: props.timestamp)
    if observedAt == nil {
      // Fallback without fractional
      iso.formatOptions = [.withInternetDateTime]
      observedAt = iso.date(from: props.timestamp)
    }
    guard let observedAt = observedAt else {
      // observation timestamp parse failed (log removed)
      return nil
    }

    // Convert units by reading the declared unitCode (robust, no more blind "Celsius" assumption).
    var tempF: Double?
    if let t = props.temperature?.value {
      let unit = (props.temperature?.unitCode ?? "").lowercased()
      if unit.contains("degf") || unit.contains("fahrenheit") {
        tempF = t
      } else {
        // NWS standard for observations/latest is degC
        tempF = (t * 9.0 / 5.0) + 32.0
      }
    }

    var windMph: Double?
    if let w = props.windSpeed?.value {
      let unit = (props.windSpeed?.unitCode ?? "").lowercased()
      if unit.contains("mph") || unit.contains("mi_h") {
        windMph = w
      } else if unit.contains("km_h") || unit.contains("km/h") {
        windMph = w * 0.621371
      } else {
        // fallback m/s
        windMph = w * 2.23694
      }
    }

    var windDir: Int?
    if let d = props.windDirection?.value {
      windDir = Int(d.rounded())
    }

    return NWSObservation(
      stationId: stationId,
      observedAt: observedAt,
      temperatureF: tempF,
      windSpeedMph: windMph,
      windDirectionDegrees: windDir
    )
  }

  // MARK: - Primary forecast via NWS grid system (location-aware, --grid-system --primary-source)
  // Exact flow: /points/{lat,lon} -> gridId/X/Y -> /gridpoints/{office}/{x},{y}/forecast
  // Returns mapped to existing GrokCastWeather (no struct changes, Date ids preserved)
  private func fetchPoints(for location: SavedLocation) async throws -> NWSPointsResponse {
    guard
      let pointsURL = URL(string: "\(baseURL)/points/\(location.latitude),\(location.longitude)")
    else {
      throw NWSServiceError.invalidURL
    }
    var pointsRequest = URLRequest(url: pointsURL)
    pointsRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    pointsRequest.timeoutInterval = 15

    let (pointsData, pointsResponse) = try await URLSession.shared.data(for: pointsRequest)
    guard let pointsHTTP = pointsResponse as? HTTPURLResponse else {
      throw NWSServiceError.networkError
    }
    if !(200...299).contains(pointsHTTP.statusCode) {
      let body = String(data: pointsData, encoding: .utf8) ?? ""
      throw NWSServiceError.httpError(pointsHTTP.statusCode, body)
    }
    return try JSONDecoder().decode(NWSPointsResponse.self, from: pointsData)
  }

  func fetchForecast(for location: SavedLocation) async throws -> GrokCastWeather {
    try Task.checkCancellation()

    // 1. /points (shared helper for dupe reduction) to discover grid (location-aware)
    let points = try await fetchPoints(for: location)

    // Strictly use grid fields to construct (exact spec, no direct forecast shortcut)
    guard let gid = points.properties.gridId,
      let gx = points.properties.gridX,
      let gy = points.properties.gridY
    else {
      throw NWSServiceError.invalidURL
    }
    guard let fURL = URL(string: "\(baseURL)/gridpoints/\(gid)/\(gx),\(gy)/forecast") else {
      throw NWSServiceError.invalidURL
    }

    var fRequest = URLRequest(url: fURL)
    fRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    fRequest.timeoutInterval = 15

    let (fData, fResp) = try await URLSession.shared.data(for: fRequest)
    guard let fHTTP = fResp as? HTTPURLResponse else {
      throw NWSServiceError.networkError
    }

    if !(200...299).contains(fHTTP.statusCode) {
      let body = String(data: fData, encoding: .utf8) ?? ""
      throw NWSServiceError.httpError(fHTTP.statusCode, body)
    }

    let decoder = JSONDecoder()
    let forecastResp: NWSForecastResponse
    do {
      forecastResp = try decoder.decode(NWSForecastResponse.self, from: fData)
    } catch {
      throw error
    }

    return try mapNWSForecastResponse(location: location, response: forecastResp)
  }

  private func mapNWSForecastResponse(location: SavedLocation, response: NWSForecastResponse)
    throws -> GrokCastWeather
  {
    let periods = response.properties.periods
    guard !periods.isEmpty else {
      throw NWSServiceError.noData
    }

    let first = periods[0]
    let currentTemp = Double(first.temperature ?? 0)
    let isDay = first.isDaytime
    let wcode = wmoCode(fromNWSShortForecast: first.shortForecast ?? "")
    let (symbol, text) = mapWeatherCode(wcode, isDay: isDay)

    // wind parse (optional)
    var windSpeed: Double = 0
    if let ws = first.windSpeed {
      let parts = ws.split(separator: " ")
      if let n = Double(parts.first ?? "") { windSpeed = n }
    }

    // hourly: map available periods (NWS /forecast gives ~14; UI accepts variable count, use startTime as stable Date id)
    var hourlyForecasts: [HourlyForecast] = []
    for p in periods.prefix(24) {
      let time = parseNWSDate(p.startTime) ?? Date()
      let tempD = Double(p.temperature ?? 0)
      let pwcode = wmoCode(fromNWSShortForecast: p.shortForecast ?? "")
      let (sym, _) = mapWeatherCode(pwcode, isDay: p.isDaytime)
      // Removed hardcoded 40% fake precip (was causing false "40% RAIN" even when clear).
      // NWS path is now only fallback; real % comes from OpenMeteo primary.
      let pChance = 0
      hourlyForecasts.append(
        HourlyForecast(
          time: time,
          temp: tempD,
          precipChance: pChance,
          weatherCode: pwcode,
          symbolName: sym,
          rain: nil,
          showers: nil,
          snowfall: nil
        )
      )
    }

    // daily: simplified index-based pairing of daytime + optional following night (robust to varying NWS period counts)
    var dailyForecasts: [DailyForecast] = []
    for i in 0..<periods.count where dailyForecasts.count < 10 {
      let p = periods[i]
      if p.isDaytime {
        let high = Double(p.temperature ?? 0)
        var low = high - 10.0
        let dDate = parseNWSDate(p.startTime) ?? Date()
        if i + 1 < periods.count {
          let np = periods[i + 1]
          if !np.isDaytime {
            low = Double(np.temperature ?? Int(low))
          }
        }
        let dwcode = wmoCode(fromNWSShortForecast: p.shortForecast ?? "")
        let (sym, _) = mapWeatherCode(dwcode, isDay: true)
        // Removed hardcoded 40% fake precip (NWS fallback only).
        let pChance = 0
        dailyForecasts.append(
          DailyForecast(
            date: dDate,
            high: high,
            low: low,
            precipChance: pChance,
            weatherCode: dwcode,
            symbolName: sym,
            uvMax: nil,
            rainSum: nil,
            showersSum: nil,
            snowfallSum: nil
          )
        )
      }
    }
    if dailyForecasts.isEmpty {
      let dwcode = wmoCode(fromNWSShortForecast: first.shortForecast ?? "")
      let (sym, _) = mapWeatherCode(dwcode, isDay: true)
      dailyForecasts.append(
        DailyForecast(
          date: Date(), high: currentTemp + 5, low: currentTemp - 5,
          precipChance: 0, weatherCode: dwcode, symbolName: sym,
          uvMax: nil, rainSum: nil, showersSum: nil, snowfallSum: nil
        )
      )
    }

    let high = dailyForecasts.first?.high ?? currentTemp + 5
    let low = dailyForecasts.first?.low ?? currentTemp - 5
    let precip = hourlyForecasts.first?.precipChance ?? 0

    // Note: NWS periods mapped to existing models with approximations (e.g. humidity/UV/wind as best-effort; no amounts; ~14 slots for hourly). Matches map-to-existing without model changes.
    return GrokCastWeather(
      location: location,
      currentTemp: currentTemp,
      feelsLike: currentTemp,
      conditionCode: wcode,
      conditionText: text,
      humidity: 50,
      windSpeed: windSpeed,
      uvIndex: 3.0,
      precipitationChance: precip,
      high: high,
      low: low,
      symbolName: symbol,
      fetchedAt: Date(),
      airQualityIndex: nil,
      pm25: nil,
      pollenLevel: nil,
      hourly: hourlyForecasts,
      daily: dailyForecasts
    )
  }

  private func parseNWSDate(_ string: String) -> Date? {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = iso.date(from: string) { return d }
    iso.formatOptions = [.withInternetDateTime]
    return iso.date(from: string)
  }

  private func shortForecastMentionsPrecip(_ short: String) -> Bool {
    let s = short.lowercased()
    return s.contains("rain") || s.contains("snow") || s.contains("shower") || s.contains("drizzle")
      || s.contains("storm") || s.contains("precip")
  }

  // Centralized error mapping for NWS (mirrors OpenMeteoService for consistency with --error-handling)
  static func userFriendlyMessage(for error: Error) -> String {
    if let nwsErr = error as? NWSServiceError {
      switch nwsErr {
      case .noData:
        return "NWS forecast data unavailable for this location."
      case .invalidURL:
        return "Invalid location for NWS forecast."
      case .networkError:
        return "Network error contacting NWS."
      case .httpError(let code, _):
        if code == 404 { return "NWS data not available (location may be outside supported area)." }
        return "NWS service temporarily unavailable (error \(code)). Tap RETRY."
      }
    }
    return OpenMeteoService.userFriendlyMessage(for: error)
  }
}

// MARK: - Errors (non-fatal at call sites)

enum NWSServiceError: Error, LocalizedError {
  case invalidURL
  case networkError
  case httpError(Int, String)
  case noData

  var errorDescription: String? {
    switch self {
    case .invalidURL:
      return "Invalid NWS URL constructed"
    case .networkError:
      return "Network error contacting NWS"
    case .httpError(let code, let body):
      return "NWS HTTP \(code): \(body.prefix(200))"
    case .noData:
      return "No NWS forecast periods available"
    }
  }
}
