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
  private static let userAgent = "SpotterCast/1.0 (https://grokcast.app)"
  private static let requestTimeout: TimeInterval = 8

  /// Beyond this the site's low-level beam is too high to be useful (and we're likely non-US).
  private static let maxSiteDistanceMeters: CLLocationDistance = 400_000

  /// IEM US composite mosaic (CONUS base reflectivity). Used when single-site tiles fail.
  private static let conusCompositeRadar = "USCOMP"
  private static let conusCompositeProduct = "N0Q"

  /// Rough CONUS bounding box for IEM `USCOMP` mosaic (excludes AK/HI/territories).
  static func isWithinCONUS(_ coordinate: CLLocationCoordinate2D) -> Bool {
    let lat = coordinate.latitude
    let lon = coordinate.longitude
    return lat >= 24.0 && lat <= 50.0 && lon >= -125.0 && lon <= -66.0
  }

  /// Main-actor isolated: the sole caller (RadarState) is @MainActor, and this
  /// avoids an unsynchronized static-var data race across concurrent resolutions.
  @MainActor private static var cachedSites: [Site]?

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
  @MainActor
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
    return await loadRidgeFrames(
      radar: site,
      productCode: code,
      maxFrames: maxFrames
    )
  }

  /// CONUS-wide composite reflectivity (N0Q) — free NWS mosaic, no RainViewer needed.
  static func loadCONUSReflectivityFrames(maxFrames: Int = 12) async -> [RadarFrame] {
    await loadRidgeFrames(
      radar: conusCompositeRadar,
      productCode: conusCompositeProduct,
      maxFrames: maxFrames
    )
  }

  private static func loadRidgeFrames(
    radar: String,
    productCode: String,
    maxFrames: Int
  ) async -> [RadarFrame] {
    let end = Date()
    let start = end.addingTimeInterval(-3600)
    var components = URLComponents(string: scanListBase)!
    components.queryItems = [
      URLQueryItem(name: "operation", value: "list"),
      URLQueryItem(name: "radar", value: radar),
      URLQueryItem(name: "product", value: productCode),
      URLQueryItem(name: "start", value: Self.scanFormatter.string(from: start)),
      URLQueryItem(name: "end", value: Self.scanFormatter.string(from: end)),
    ]
    guard let url = components.url,
      let response: ScanListResponse = await fetchJSON(url)
    else {
      return []
    }

    // Sort ascending (oldest→newest) so `suffix` keeps the most recent scans and
    // the last frame is genuinely "now" — don't rely on the API's response order.
    let dates = response.scans.compactMap { Self.scanFormatter.date(from: $0.ts) }
      .sorted()
    return dates.suffix(maxFrames).map { date in
      let layer = "ridge::\(radar)-\(productCode)-\(Self.layerTimestamp(from: date))"
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

  /// e.g. "2026-07-02T14:36Z" — parses scan-list responses and formats the
  /// start/end query timestamps (same ISO-minute format both directions).
  private static let scanFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)!
    f.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
    return f
  }()

  /// e.g. "202607021436" (ridge layer path format)
  private static let layerFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)!
    f.dateFormat = "yyyyMMddHHmm"
    return f
  }()

  private static func layerTimestamp(from date: Date) -> String {
    layerFormatter.string(from: date)
  }
}
