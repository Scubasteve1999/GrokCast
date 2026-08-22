import CoreLocation
import Foundation

enum LightningServiceError: Error, Equatable {
  case missingKey
  case insufficientScope
  case badResponse
}

/// Xweather Data API `/lightning/closest` — cloud-to-ground pulses.
///
/// Standard access on this account: last ~5 minutes, 100 km radius, no `within`
/// bbox. The store merges polls into a 20-minute window. Do not use Blitzortung.
enum LightningService {
  static let queryRadiusKM = 100
  static let requestLimit = 1000
  static let userAgent = "DayCast/1.0 (https://daycast.app)"

  private static let isoFormatterWithFractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  static func fetchStrikes(
    around center: CLLocationCoordinate2D,
    clientID: String? = DeveloperAPIKey.xweatherClientID,
    clientSecret: String? = DeveloperAPIKey.xweatherClientSecret,
    session: URLSession = .shared
  ) async throws -> [LightningStrike] {
    guard let clientID, !clientID.isEmpty, let clientSecret, !clientSecret.isEmpty else {
      throw LightningServiceError.missingKey
    }
    guard let url = makeURL(center: center, clientID: clientID, clientSecret: clientSecret) else {
      throw LightningServiceError.badResponse
    }

    var request = URLRequest(url: url)
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.timeoutInterval = 15

    let (data, response): (Data, URLResponse)
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      throw LightningServiceError.badResponse
    }

    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
      if http.statusCode == 403 { throw LightningServiceError.insufficientScope }
      throw LightningServiceError.badResponse
    }

    return try parse(data: data)
  }

  static func parse(data: Data, now: Date = Date()) throws -> [LightningStrike] {
    let envelope = try JSONDecoder().decode(Envelope.self, from: data)
    if let code = envelope.error?.code?.lowercased() {
      if code.contains("insufficient") || code.contains("scope") {
        throw LightningServiceError.insufficientScope
      }
    }
    if envelope.success == false {
      throw LightningServiceError.badResponse
    }
    let rows = envelope.response ?? []
    return rows.compactMap { StrikeDTO.strike(from: $0, now: now) }
  }

  static func makeURL(
    center: CLLocationCoordinate2D,
    clientID: String,
    clientSecret: String
  ) -> URL? {
    var components = URLComponents(string: "https://data.api.xweather.com/lightning/closest")
    components?.queryItems = [
      URLQueryItem(name: "p", value: String(format: "%.4f,%.4f", center.latitude, center.longitude)),
      URLQueryItem(name: "radius", value: "\(queryRadiusKM)km"),
      URLQueryItem(name: "limit", value: "\(requestLimit)"),
      URLQueryItem(name: "filter", value: "cg"),
      URLQueryItem(name: "client_id", value: clientID),
      URLQueryItem(name: "client_secret", value: clientSecret),
    ]
    return components?.url
  }

  // MARK: - Decode

  private struct Envelope: Decodable {
    let success: Bool?
    let error: APIError?
    let response: [StrikeDTO]?
  }

  private struct APIError: Decodable {
    let code: String?
    let description: String?
  }

  struct StrikeDTO: Decodable {
    let id: String?
    let loc: Loc?
    let ob: Observation?
    let age: Double?

    struct Loc: Decodable {
      let lat: Double?
      let long: Double?
    }

    struct Observation: Decodable {
      let timestamp: Double?
      let timestampMS: Double?
      let dateTimeISO: String?
      let age: Double?
      let pulse: Pulse?
    }

    struct Pulse: Decodable {
      let type: String?
      let peakamp: Double?
    }

    static func strike(from dto: StrikeDTO, now: Date) -> LightningStrike? {
      guard let lat = dto.loc?.lat, let lon = dto.loc?.long,
        lat.isFinite, lon.isFinite, abs(lat) <= 90, abs(lon) <= 180
      else { return nil }

      let pulseType = (dto.ob?.pulse?.type ?? "cg").lowercased()
      // Request filters cg; still drop non-CG if the feed slips.
      if !pulseType.isEmpty, pulseType != "cg" { return nil }

      let time = resolvedTime(dto, now: now)
      let id = resolvedID(dto, latitude: lat, longitude: lon, time: time)
      return LightningStrike(
        id: id,
        latitude: lat,
        longitude: lon,
        time: time,
        pulseType: pulseType.isEmpty ? "cg" : pulseType,
        peakAmps: dto.ob?.pulse?.peakamp
      )
    }

    private static func resolvedTime(_ dto: StrikeDTO, now: Date) -> Date {
      if let ms = dto.ob?.timestampMS, ms > 1_000_000_000_000 {
        return Date(timeIntervalSince1970: ms / 1000)
      }
      if let seconds = dto.ob?.timestamp, seconds > 1_000_000_000 {
        return Date(timeIntervalSince1970: seconds)
      }
      if let iso = dto.ob?.dateTimeISO {
        if let date = LightningService.isoFormatterWithFractional.date(from: iso)
          ?? LightningService.isoFormatter.date(from: iso)
        {
          return date
        }
      }
      if let age = dto.ob?.age ?? dto.age {
        return now.addingTimeInterval(-age)
      }
      return now
    }

    private static func resolvedID(
      _ dto: StrikeDTO, latitude: Double, longitude: Double, time: Date
    ) -> String {
      if let id = dto.id, !id.isEmpty { return id }
      let lat = String(format: "%.4f", latitude)
      let lon = String(format: "%.4f", longitude)
      let ms = Int((time.timeIntervalSince1970 * 1000).rounded())
      return "\(lat),\(lon),\(ms)"
    }
  }
}
