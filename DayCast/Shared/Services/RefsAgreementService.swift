import Foundation

/// Fetches the REFS agreement point JSON. Soft-fails to nil — never a thrown error in the feed.
struct RefsAgreementService: Sendable {
  var session: URLSession = .shared
  var baseURL: URL? = RefsAgreementConfiguration.baseURL

  func fetch(
    latitude: Double,
    longitude: Double,
    timeZone: TimeZone
  ) async -> RefsAgreementPayload? {
    guard let baseURL else { return nil }
    var components = URLComponents(
      url: baseURL.appendingPathComponent("v1/agreement"),
      resolvingAgainstBaseURL: false
    )
    let zone = timeZone.identifier
    components?.queryItems = [
      URLQueryItem(name: "lat", value: String(latitude)),
      URLQueryItem(name: "lon", value: String(longitude)),
      URLQueryItem(name: "tz", value: zone),
    ]
    guard let url = components?.url else { return nil }
    do {
      let (data, response) = try await session.data(from: url)
      guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
        return nil
      }
      return RefsAgreement.decode(data)
    } catch {
      return nil
    }
  }
}
