import Foundation

/// Fetches ICON Seamless ensemble precip members from Open-Meteo's **free**
/// Ensemble API. Soft-fails to `nil` — never throws into UI.
///
/// A customer-specific paid Open-Meteo host is residual, not this path.
/// Settings already credits Open-Meteo; do not add a second attribution row.
final class OpenMeteoEnsembleService: Sendable {
  private let baseURL = URL(string: "https://ensemble-api.open-meteo.com/v1/ensemble")!
  private let session: URLSession

  /// ICON Seamless EPS is global (not CONUS-gated). Nationwide + overseas.
  static let model = "icon_seamless"

  init(session: URLSession = .shared) {
    self.session = session
  }

  /// Next ~36 hours of member precip. `nil` on transport / decode / empty.
  func fetchPrecipMembers(
    latitude: Double,
    longitude: Double
  ) async -> EnsemblePrecipSnapshot? {
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
    components.queryItems = [
      URLQueryItem(name: "latitude", value: String(latitude)),
      URLQueryItem(name: "longitude", value: String(longitude)),
      URLQueryItem(name: "hourly", value: "precipitation,weather_code"),
      URLQueryItem(name: "models", value: Self.model),
      URLQueryItem(name: "forecast_days", value: "2"),
      URLQueryItem(name: "timezone", value: "auto"),
      URLQueryItem(name: "precipitation_unit", value: "inch"),
    ]

    guard let url = components.url else { return nil }

    do {
      let (data, response) = try await session.data(from: url)
      guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode)
      else { return nil }

      let decoded = try JSONDecoder().decode(OpenMeteoEnsembleResponse.self, from: data)
      return EnsemblePrecipSnapshot.mapping(decoded)
    } catch {
      return nil
    }
  }
}

// MARK: - Snapshot

struct EnsemblePrecipSnapshot: Equatable, Sendable {
  let locationID: String
  let fetchedAt: Date
  let timeZoneIdentifier: String?
  let times: [Date]
  /// One precip series per member (inches), aligned to `times`.
  let members: [[Double]]
  /// Thunderstorm flag per member per hour. Empty when weather codes missing.
  let stormByMember: [[Bool]]

  static func empty(locationID: String = "") -> EnsemblePrecipSnapshot {
    EnsemblePrecipSnapshot(
      locationID: locationID,
      fetchedAt: .distantPast,
      timeZoneIdentifier: nil,
      times: [],
      members: [],
      stormByMember: []
    )
  }

  var hasMembers: Bool {
    members.count >= EnsembleAgreement.Thresholds.minMembers && !times.isEmpty
  }

  static let maxUsableAge: TimeInterval = 45 * 60

  func isUsable(at now: Date = Date()) -> Bool {
    hasMembers && now.timeIntervalSince(fetchedAt) < Self.maxUsableAge
  }

  static func keepingLastGood(
    _ previous: EnsemblePrecipSnapshot,
    locationID: String,
    at now: Date = Date()
  ) -> EnsemblePrecipSnapshot {
    guard previous.locationID == locationID, previous.isUsable(at: now) else {
      return .empty(locationID: locationID)
    }
    return previous
  }

  func withLocationID(_ locationID: String) -> EnsemblePrecipSnapshot {
    EnsemblePrecipSnapshot(
      locationID: locationID,
      fetchedAt: fetchedAt,
      timeZoneIdentifier: timeZoneIdentifier,
      times: times,
      members: members,
      stormByMember: stormByMember
    )
  }

  static func mapping(
    _ response: OpenMeteoEnsembleResponse,
    locationID: String = "",
    fetchedAt: Date = Date()
  ) -> EnsemblePrecipSnapshot? {
    guard let hourly = response.hourly, !hourly.time.isEmpty, !hourly.precipSeries.isEmpty
    else { return nil }

    let timeZone =
      response.timezone.flatMap { TimeZone(identifier: $0) }
      ?? TimeZone(secondsFromGMT: 0)
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
    let iso = ISO8601DateFormatter()

    let times: [Date] = hourly.time.enumerated().map { index, string in
      formatter.date(from: string)
        ?? iso.date(from: string)
        ?? Date().addingTimeInterval(Double(index) * 3600)
    }

    let members: [[Double]] = hourly.precipSeries.map { series in
      times.indices.map { index in
        openMeteoValue(series, at: index) ?? 0
      }
    }

    let stormByMember: [[Bool]] = hourly.weatherSeries.map { series in
      times.indices.map { index in
        let code = openMeteoValue(series, at: index).map { Int($0.rounded()) } ?? 0
        return EnsembleAgreement.isStormCode(code)
      }
    }

    guard members.count >= EnsembleAgreement.Thresholds.minMembers else { return nil }

    return EnsemblePrecipSnapshot(
      locationID: locationID,
      fetchedAt: fetchedAt,
      timeZoneIdentifier: response.timezone,
      times: times,
      members: members,
      stormByMember: stormByMember
    )
  }
}

// MARK: - Decode

struct OpenMeteoEnsembleResponse: Decodable {
  let timezone: String?
  let hourly: Hourly?

  struct Hourly: Decodable {
    let time: [String]
    let precipSeries: [[Double?]]
    let weatherSeries: [[Double?]]

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: DynamicCodingKey.self)
      time = try container.decode([String].self, forKey: DynamicCodingKey("time"))

      var precipBySuffix: [String: [Double?]] = [:]
      var weatherBySuffix: [String: [Double?]] = [:]
      for key in container.allKeys {
        let name = key.stringValue
        if name == "time" { continue }
        if name == "precipitation" || name.hasPrefix("precipitation_member") {
          precipBySuffix[Self.memberSuffix(from: name, prefix: "precipitation")] =
            try container.decode([Double?].self, forKey: key)
        } else if name == "weather_code" || name.hasPrefix("weather_code_member") {
          weatherBySuffix[Self.memberSuffix(from: name, prefix: "weather_code")] =
            try Self.decodeNumbers(container, key: key)
        }
      }
      let suffixes = precipBySuffix.keys.sorted()
      precipSeries = suffixes.compactMap { precipBySuffix[$0] }
      weatherSeries = suffixes.map { weatherBySuffix[$0] ?? [] }
    }

    /// `precipitation` → `""`; `precipitation_member07` → `member07`.
    private static func memberSuffix(from name: String, prefix: String) -> String {
      if name == prefix { return "" }
      let stem = prefix + "_"
      guard name.hasPrefix(stem) else { return name }
      return String(name.dropFirst(stem.count))
    }

    /// Weather codes arrive as ints; tolerate doubles.
    private static func decodeNumbers(
      _ container: KeyedDecodingContainer<DynamicCodingKey>,
      key: DynamicCodingKey
    ) throws -> [Double?] {
      if let doubles = try? container.decode([Double?].self, forKey: key) {
        return doubles
      }
      let ints = try container.decode([Int?].self, forKey: key)
      return ints.map { $0.map(Double.init) }
    }
  }
}

private struct DynamicCodingKey: CodingKey {
  var stringValue: String
  var intValue: Int?

  init(_ string: String) {
    stringValue = string
    intValue = nil
  }

  init?(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}
