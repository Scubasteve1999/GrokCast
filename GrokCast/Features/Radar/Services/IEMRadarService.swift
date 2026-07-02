import CoreLocation
import Foundation

/// NWS NEXRAD single-site tiles via IEM (Iowa Environmental Mesonet) RIDGE cache.
/// Powers the Velocity / SRV products in Live mode (US only).
/// Strictly additive like the rest of the NWS integration: every call is
/// non-fatal and returns empty/nil on failure so callers keep the composite view.
final class IEMRadarService {

  private static let baseTileHost = "https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0"
  private static let scanListBase = "https://mesonet.agron.iastate.edu/json/radar"
  private static let siteListURL = URL(
    string: "https://mesonet.agron.iastate.edu/json/network.py?network=NEXRAD")!
  private static let userAgent = "GrokCast/1.0 (https://grokcast.app)"
  private static let requestTimeout: TimeInterval = 8

  /// Beyond this the site's low-level beam is too high to be useful (and we're likely non-US).
  private static let maxSiteDistanceMeters: CLLocationDistance = 400_000

  private static var cachedSites: [Site]?

  struct Site: Decodable, Equatable {
    let id: String
    let name: String
    let lon: Double
    let lat: Double
  }

  private struct SiteListResponse: Decodable {
    let stations: [Site]
  }

  private struct ScanListResponse: Decodable {
    struct Scan: Decodable {
      let ts: String
    }
    let scans: [Scan]
  }

  /// Nearest NEXRAD site to the coordinate, or nil when none is close enough (non-US).
  static func nearestSite(to coordinate: CLLocationCoordinate2D) async -> Site? {
    let sites: [Site]
    if let cachedSites {
      sites = cachedSites
    } else if let fetched = await fetchSites() {
      cachedSites = fetched
      sites = fetched
    } else {
      return nil
    }

    let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    func distance(_ site: Site) -> CLLocationDistance {
      here.distance(from: CLLocation(latitude: site.lat, longitude: site.lon))
    }

    guard let best = sites.min(by: { distance($0) < distance($1) }),
      distance(best) <= maxSiteDistanceMeters
    else {
      return nil
    }
    return best
  }

  /// Recent frames for one site + product using real volume-scan times from the
  /// IEM list API (guessed 5-minute timestamps return 503 — verified 2026-07).
  static func loadSiteFrames(
    site: String,
    product: RadarProduct,
    maxFrames: Int = 12
  ) async -> [RadarFrame] {
    guard let code = product.iemCode else { return [] }

    let end = Date()
    let start = end.addingTimeInterval(-3600)
    var components = URLComponents(string: scanListBase)!
    components.queryItems = [
      URLQueryItem(name: "operation", value: "list"),
      URLQueryItem(name: "radar", value: site),
      URLQueryItem(name: "product", value: code),
      URLQueryItem(name: "start", value: Self.queryTimestamp(from: start)),
      URLQueryItem(name: "end", value: Self.queryTimestamp(from: end)),
    ]
    guard let url = components.url,
      let response: ScanListResponse = await fetchJSON(url)
    else {
      return []
    }

    return response.scans.suffix(maxFrames).compactMap { scan -> RadarFrame? in
      guard let date = Self.scanFormatter.date(from: scan.ts) else { return nil }
      let layer = "ridge::\(site)-\(code)-\(Self.layerTimestamp(from: date))"
      return RadarFrame(
        provider: .iem,
        kind: .livePrecipitation,
        tileEpoch: Int(date.timeIntervalSince1970),
        timestamp: date,
        tileURLTemplates: ["\(baseTileHost)/\(layer)/{z}/{x}/{y}.png"]
      )
    }
  }

  private static func fetchSites() async -> [Site]? {
    guard let response: SiteListResponse = await fetchJSON(siteListURL) else { return nil }
    return response.stations.isEmpty ? nil : response.stations
  }

  private static func fetchJSON<T: Decodable>(_ url: URL) async -> T? {
    var request = URLRequest(url: url)
    request.timeoutInterval = requestTimeout
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        return nil
      }
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      print("[IEM] Request failed (non-fatal) for \(url.lastPathComponent): \(error)")
      return nil
    }
  }

  /// e.g. "2026-07-02T14:36Z" (scan list response format)
  private static let scanFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)!
    f.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
    return f
  }()

  /// e.g. "202607021436" (ridge layer path format)
  private static func layerTimestamp(from date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)!
    f.dateFormat = "yyyyMMddHHmm"
    return f.string(from: date)
  }

  private static func queryTimestamp(from date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)!
    f.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
    return f.string(from: date)
  }
}
