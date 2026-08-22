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
  private static let userAgent = "DayCast/1.0 (https://daycast.app)"
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

  /// Result of a site-product load, including whether we had to step to a neighbor
  /// and whether the newest volume is already stale for field use.
  struct SiteFrameLoad: Equatable {
    let frames: [RadarFrame]
    let site: Site
    /// Preferred (nearest) site the user would expect — may differ from `site`.
    let preferredSite: Site
    let isFallback: Bool
    /// Newest frame older than `staleScanThreshold` (site likely degraded).
    let isStale: Bool

    var newestScanAge: TimeInterval {
      guard let newest = frames.last?.timestamp else { return .infinity }
      return Date().timeIntervalSince(newest)
    }
  }

  /// Scans newer than this are treated as current; older still display with a warning.
  static let staleScanThreshold: TimeInterval = 15 * 60
  /// Primary list window. Wider than composite — site outages often last hours.
  private static let primaryLookback: TimeInterval = 3 * 3600
  /// Last-ditch window when the 3h list is empty (true multi-hour outage).
  private static let extendedLookback: TimeInterval = 12 * 3600
  /// How many NEXRAD sites to try before giving up (nearest first).
  private static let siteFallbackLimit = 4

  /// Recent frames for one site + product using real volume-scan times from the
  /// IEM list API (guessed 5-minute timestamps return 503 — verified 2026-07).
  static func loadSiteFrames(
    site: String,
    product: RadarProduct,
    maxFrames: Int = RadarLivePresentation.siteLoopMaxFrames
  ) async -> [RadarFrame] {
    guard let code = product.iemCode else { return [] }
    return await loadRidgeFrames(
      radar: site,
      productCode: code,
      maxFrames: maxFrames,
      lookback: primaryLookback
    )
  }

  /// Prefer a **fresh** volume over a dead home radar.
  ///
  /// Two passes (the bug this fixes: extended lookback on NQA returned 12h-old
  /// frames and short-circuited before OHX could offer minutes-old SRV):
  /// 1. Primary window (3h), nearest first — first hit wins.
  /// 2. Only if every candidate is empty in 3h: extended window (12h), pick the
  ///    site whose newest scan is freshest (not merely nearest).
  @MainActor
  static func loadSiteFramesNear(
    coordinate: CLLocationCoordinate2D,
    product: RadarProduct,
    preferredSite: Site? = nil,
    maxFrames: Int = RadarLivePresentation.siteLoopMaxFrames
  ) async -> SiteFrameLoad? {
    guard let code = product.iemCode else { return nil }

    var candidates = await nearestSites(to: coordinate, limit: siteFallbackLimit)
    if let preferredSite, !candidates.contains(where: { $0.id == preferredSite.id }) {
      candidates.insert(preferredSite, at: 0)
    }
    // Deduplicate while keeping order.
    var seen = Set<String>()
    candidates = candidates.filter { seen.insert($0.id).inserted }
    guard let preferred = preferredSite ?? candidates.first else { return nil }

    // Pass 1 — live-enough volumes only. Never mix in 12h archaeology here.
    for site in candidates {
      let frames = await loadRidgeFrames(
        radar: site.id,
        productCode: code,
        maxFrames: maxFrames,
        lookback: primaryLookback
      )
      if let load = siteFrameLoad(frames: frames, site: site, preferred: preferred) {
        return load
      }
    }

    // Pass 2 — total outage region: take the least-stale extended set we can find.
    var best: SiteFrameLoad?
    for site in candidates {
      let frames = await loadRidgeFrames(
        radar: site.id,
        productCode: code,
        maxFrames: maxFrames,
        lookback: extendedLookback
      )
      guard let load = siteFrameLoad(frames: frames, site: site, preferred: preferred)
      else { continue }
      if best == nil || load.newestScanAge < best!.newestScanAge {
        best = load
      }
    }
    return best
  }

  /// Builds a load result when frames exist; nil when the list was empty.
  static func siteFrameLoad(
    frames: [RadarFrame],
    site: Site,
    preferred: Site
  ) -> SiteFrameLoad? {
    guard !frames.isEmpty else { return nil }
    let newestAge =
      frames.last.map { Date().timeIntervalSince($0.timestamp) } ?? .infinity
    return SiteFrameLoad(
      frames: frames,
      site: site,
      preferredSite: preferred,
      isFallback: site.id != preferred.id,
      isStale: newestAge > staleScanThreshold
    )
  }

  /// Pure selection helper for tests: given candidate loads from pass 1 / pass 2,
  /// return the winner (first non-nil pass-1, else freshest pass-2).
  static func pickSiteFrameLoad(
    primaryHits: [SiteFrameLoad],
    extendedHits: [SiteFrameLoad]
  ) -> SiteFrameLoad? {
    if let first = primaryHits.first { return first }
    return extendedHits.min(by: { $0.newestScanAge < $1.newestScanAge })
  }

  /// Ordered nearest NEXRAD sites within `maxSiteDistanceMeters`.
  @MainActor
  static func nearestSites(
    to coordinate: CLLocationCoordinate2D,
    limit: Int
  ) async -> [Site] {
    let sites: [Site]
    if let cachedSites {
      sites = cachedSites
    } else if let fetched = await fetchSites() {
      cachedSites = fetched
      sites = fetched
    } else {
      return []
    }

    let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    return sites
      .map { site in
        (site, here.distance(from: CLLocation(latitude: site.lat, longitude: site.lon)))
      }
      .filter { $0.1 <= maxSiteDistanceMeters }
      .sorted { $0.1 < $1.1 }
      .prefix(max(limit, 0))
      .map(\.0)
  }

  /// CONUS-wide composite reflectivity (N0Q) — free NWS mosaic, no RainViewer needed.
  static func loadCONUSReflectivityFrames(maxFrames: Int = 12) async -> [RadarFrame] {
    await loadRidgeFrames(
      radar: conusCompositeRadar,
      productCode: conusCompositeProduct,
      maxFrames: maxFrames,
      lookback: 3600
    )
  }

  private static func loadRidgeFrames(
    radar: String,
    productCode: String,
    maxFrames: Int,
    lookback: TimeInterval
  ) async -> [RadarFrame] {
    let end = Date()
    let start = end.addingTimeInterval(-lookback)
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
      radarLog("[IEM] Request failed (non-fatal) for \(url.lastPathComponent): \(error)")
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
