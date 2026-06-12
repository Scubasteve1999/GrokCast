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
    let pointsURL = URL(string: "\(baseURL)/points/\(location.latitude),\(location.longitude)")!
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
      print("🌩️ [NWS] points decode failed: \(error)")
      if let decodingError = error as? DecodingError {
        print("🌩️ [NWS] points decode details: \(decodingError)")
      }
      if let jsonStr = String(data: pointsData, encoding: .utf8) {
        print("🌩️ [NWS] raw points JSON (first 600 chars): \(jsonStr.prefix(600))")
      }
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
      print("🌩️ [NWS] stations collection decode failed: \(error)")
      if let decodingError = error as? DecodingError {
        print("🌩️ [NWS] stations decode details: \(decodingError)")
      }
      if let jsonStr = String(data: stationsData, encoding: .utf8) {
        print("🌩️ [NWS] raw stations JSON (first 600 chars): \(jsonStr.prefix(600))")
      }
      return nil
    }

    guard let firstStation = stations.features.first else {
      return nil  // no stations (common for non-US or remote areas)
    }
    let firstStationURL = firstStation.id  // e.g. https://api.weather.gov/stations/KOLV

    // 2. Fetch latest observation for that station
    let obsURL = URL(string: "\(firstStationURL)/observations/latest")!
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
      print("🌩️ [NWS] obs decode failed: \(error)")
      if let decodingError = error as? DecodingError {
        print("🌩️ [NWS] obs decode details: \(decodingError)")
      }
      // Optionally print raw for debug, but truncate
      if let jsonStr = String(data: obsData, encoding: .utf8) {
        print("🌩️ [NWS] raw obs JSON (first 500 chars): \(jsonStr.prefix(500))")
      }
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
      print("🌩️ [NWS] observation timestamp parse failed for: \(props.timestamp)")
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
}

// MARK: - Errors (non-fatal at call sites)

enum NWSServiceError: Error, LocalizedError {
  case invalidURL
  case networkError
  case httpError(Int, String)

  var errorDescription: String? {
    switch self {
    case .invalidURL:
      return "Invalid NWS URL constructed"
    case .networkError:
      return "Network error contacting NWS"
    case .httpError(let code, let body):
      return "NWS HTTP \(code): \(body.prefix(200))"
    }
  }
}
