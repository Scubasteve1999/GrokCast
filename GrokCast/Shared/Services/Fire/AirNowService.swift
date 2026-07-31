import CoreLocation
import Foundation

/// Optional AirNow lookup for fire-detail smoke line (Stage 4). Quiet when key missing.
enum AirNowService {
  struct Observation: Equatable, Sendable {
    let aqi: Int
    let category: String
    let parameter: String?
  }

  static func currentAQI(
    near coordinate: CLLocationCoordinate2D,
    apiKey: String?,
    session: URLSession = .shared
  ) async -> Observation? {
    guard let apiKey, !apiKey.isEmpty else { return nil }

    var components = URLComponents(
      string: "https://www.airnowapi.org/aq/observation/latLong/current/"
    )
    components?.queryItems = [
      URLQueryItem(name: "format", value: "application/json"),
      URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
      URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
      URLQueryItem(name: "distance", value: "25"),
      URLQueryItem(name: "API_KEY", value: apiKey),
    ]
    guard let url = components?.url else { return nil }

    do {
      let (data, response) = try await session.data(from: url)
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode)
      else { return nil }
      guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
        let first = rows.first,
        let aqi = first["AQI"] as? Int
      else { return nil }
      let category =
        (first["Category"] as? [String: Any])?["Name"] as? String
        ?? AirQualityCategory(usAQI: aqi).title
      return Observation(
        aqi: aqi,
        category: category,
        parameter: first["ParameterName"] as? String
      )
    } catch {
      return nil
    }
  }
}
