import CoreLocation
import Foundation

/// Resolves the nearest NEXRAD site for IEM ridge velocity/SRV tiles (site-specific layers).
enum IEMRadarSiteResolver {
  private struct RadarEntry: Decodable {
    let id: String
    let lat: Double
    let lon: Double
    let type: String
  }

  private struct RadarListResponse: Decodable {
    let radars: [RadarEntry]?
  }

  private static let listURL = URL(
    string: "https://mesonet.agron.iastate.edu/json/radar.py?operation=available")!
  static let fallbackSiteID = "NQA"  // Memphis NEXRAD; sensible default for Olive Branch usage
  private static var cachedNEXRADs: [RadarEntry]?

  static var isReady: Bool {
    guard let cachedNEXRADs else { return false }
    return !cachedNEXRADs.isEmpty
  }

  /// Fetches and caches the IEM radar list (non-fatal; retains prior cache on failure).
  static func preloadRadarList() async {
    var request = URLRequest(url: listURL)
    request.setValue("GrokCast/1.0 (https://grokcast.app)", forHTTPHeaderField: "User-Agent")
    request.timeoutInterval = 10
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
        return
      }
      let decoded = try JSONDecoder().decode(RadarListResponse.self, from: data)
      let nexrads = decoded.radars?.filter { $0.type == "NEXRAD" } ?? []
      if !nexrads.isEmpty {
        cachedNEXRADs = nexrads
      }
    } catch {
      print("🌩️ [Radar] IEM radar list fetch failed (non-fatal): \(error.localizedDescription)")
    }
  }

  /// Returns the nearest NEXRAD site ID for the given map coordinate.
  /// When `preferring` is set, applies hysteresis so small pans near coverage boundaries
  /// do not flip sites until the challenger is clearly closer.
  static func nearestNEXRAD(
    to coordinate: CLLocationCoordinate2D,
    preferring currentSiteID: String? = nil,
    hysteresisFraction: Double = 0.15,
    hysteresisMeters: CLLocationDistance = 25_000
  ) -> String {
    guard let radars = cachedNEXRADs, !radars.isEmpty else { return fallbackSiteID }
    let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

    var bestID = fallbackSiteID
    var bestDistance = CLLocationDistance.greatestFiniteMagnitude
    var currentDistance: CLLocationDistance?

    for radar in radars {
      let loc = CLLocation(latitude: radar.lat, longitude: radar.lon)
      let distance = target.distance(from: loc)
      if radar.id == currentSiteID {
        currentDistance = distance
      }
      if distance < bestDistance {
        bestDistance = distance
        bestID = radar.id
      }
    }

    guard let currentID = currentSiteID, let currentDist = currentDistance else {
      return bestID
    }

    if bestID == currentID { return currentID }

    let improvement = currentDist - bestDistance
    let relativeImprovement = improvement / max(currentDist, 1)
    if improvement < hysteresisMeters && relativeImprovement < hysteresisFraction {
      return currentID
    }
    return bestID
  }
}
