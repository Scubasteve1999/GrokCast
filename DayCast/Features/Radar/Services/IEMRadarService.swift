import CoreGraphics
import CoreLocation
import Foundation
import ImageIO

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

  /// Zoom ~228 km/tile at 35°N — matches the local camera, not a neighboring
  /// site's storm 250 km out that leaves Olive Branch looking empty.
  static let precipProbeZoom = 8
  static let precipProbeRangeMeters: CLLocationDistance =
    RadarLiveCameraPolicy.localPrecipRadiusMeters
  private static let precipProbeTimeout: TimeInterval = 1.2
  private static let mosaicPrecipProbeTimeout: TimeInterval = 1.2
  private static let mosaicPrecipMinPixels = 24

  /// True when the *newest* N0B scan has organized precip inside the local
  /// camera. Mid-window history (a cell that already left) is not "wet now".
  /// Fetch failure returns false so Live can present National radar.
  static func liveWindowHasOrganizedPrecip(frames: [RadarFrame], site: Site) async -> Bool {
    let live = RadarLivePresentation.liveFrames(frames, isSiteProduct: true)
    guard let newest = live.last else { return false }
    return await frameHasOrganizedPrecip(newest, site: site)
  }

  /// Distance from `coordinate` to the nearest mosaic tile with rain in the
  /// newest national frame. Nil = none found / fetch failed → CONUS camera.
  static func nearestMosaicPrecipMeters(
    frame: RadarFrame, from coordinate: CLLocationCoordinate2D
  ) async -> CLLocationDistance? {
    guard let template = frame.tileURLTemplates.first else { return nil }
    for zoom in [5, 4, 3] {
      if let meters = await nearestWetMosaicTileMeters(
        template: template, coordinate: coordinate, zoom: zoom)
      {
        return meters
      }
    }
    return nil
  }

  static func webMercatorTile(lat: Double, lon: Double, zoom: Int) -> (x: Int, y: Int) {
    let n = Double(1 << zoom)
    let clampedLon = min(max(lon, -180), 180)
    let clampedLat = min(max(lat, -85.05112878), 85.05112878)
    let x = Int(floor((clampedLon + 180) / 360 * n))
    let latRad = clampedLat * .pi / 180
    let y = Int(floor((1 - log(tan(latRad) + 1 / cos(latRad)) / .pi) / 2 * n))
    let maxIndex = (1 << zoom) - 1
    return (min(max(x, 0), maxIndex), min(max(y, 0), maxIndex))
  }

  static func tilesCoveringSite(_ site: Site, zoom: Int) -> [(x: Int, y: Int)] {
    let origin = webMercatorTile(lat: site.lat, lon: site.lon, zoom: zoom)
    let here = CLLocation(latitude: site.lat, longitude: site.lon)
    var ranked: [(x: Int, y: Int, meters: CLLocationDistance)] = []
    let maxIndex = (1 << zoom) - 1
    for dy in -2...2 {
      for dx in -2...2 {
        let x = origin.x + dx
        let y = origin.y + dy
        guard x >= 0, y >= 0, x <= maxIndex, y <= maxIndex else { continue }
        let center = tileCenter(x: x, y: y, zoom: zoom)
        let distance = here.distance(
          from: CLLocation(latitude: center.lat, longitude: center.lon))
        if distance <= precipProbeRangeMeters {
          ranked.append((x, y, distance))
        }
      }
    }
    if ranked.isEmpty { return [origin] }
    return ranked.sorted { $0.meters < $1.meters }.prefix(9).map { ($0.x, $0.y) }
  }

  private static func mosaicTileHalfDiagonalMeters(zoom: Int, latitude: Double) -> CLLocationDistance {
    let n = Double(1 << zoom)
    let metersPerTile = 40_075_016.686 * max(0.2, cos(latitude * .pi / 180)) / n
    return (metersPerTile / 2) * 1.414
  }

  static func tileCenter(x: Int, y: Int, zoom: Int) -> (lat: Double, lon: Double) {
    let n = Double(1 << zoom)
    let lon = Double(x) / n * 360 - 180 + (180 / n)
    let latRad = atan(sinh(.pi * (1 - 2 * (Double(y) + 0.5) / n)))
    return (latRad * 180 / .pi, lon)
  }

  private static func frameHasOrganizedPrecip(_ frame: RadarFrame, site: Site) async -> Bool {
    guard let template = frame.tileURLTemplates.first else { return false }
    let tiles = tilesCoveringSite(site, zoom: precipProbeZoom)
    return await withTaskGroup(of: Bool.self) { group in
      for tile in tiles {
        group.addTask {
          let urlString = template
            .replacingOccurrences(of: "{z}", with: "\(precipProbeZoom)")
            .replacingOccurrences(of: "{x}", with: "\(tile.x)")
            .replacingOccurrences(of: "{y}", with: "\(tile.y)")
          guard let url = URL(string: urlString), let data = await fetchData(url)
          else { return false }
          return IEMSiteReflectivityPaint.hasOrganizedPrecip(in: data)
        }
      }
      for await hit in group {
        if hit {
          group.cancelAll()
          return true
        }
      }
      return false
    }
  }

  private static func nearestWetMosaicTileMeters(
    template: String, coordinate: CLLocationCoordinate2D, zoom: Int
  ) async -> CLLocationDistance? {
    let origin = webMercatorTile(lat: coordinate.latitude, lon: coordinate.longitude, zoom: zoom)
    let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    let maxIndex = (1 << zoom) - 1
    var ranked: [(x: Int, y: Int, meters: CLLocationDistance)] = []
    for dy in -1...1 {
      for dx in -1...1 {
        let x = origin.x + dx
        let y = origin.y + dy
        guard x >= 0, y >= 0, x <= maxIndex, y <= maxIndex else { continue }
        let center = tileCenter(x: x, y: y, zoom: zoom)
        let centerMeters = here.distance(
          from: CLLocation(latitude: center.lat, longitude: center.lon))
        // Rain can sit on the far edge of a large mosaic tile; using the
        // center alone reports 70 km while the echo is 400 km out.
        let halfDiag = mosaicTileHalfDiagonalMeters(zoom: zoom, latitude: coordinate.latitude)
        let meters = max(centerMeters, halfDiag)
        ranked.append((x, y, meters))
      }
    }
    ranked.sort { $0.meters < $1.meters }
    for tile in ranked {
      let urlString = template
        .replacingOccurrences(of: "{z}", with: "\(zoom)")
        .replacingOccurrences(of: "{x}", with: "\(tile.x)")
        .replacingOccurrences(of: "{y}", with: "\(tile.y)")
      guard let url = URL(string: urlString),
        let data = await fetchData(url, timeout: mosaicPrecipProbeTimeout)
      else { continue }
      if mosaicPNGHasPrecip(data) { return tile.meters }
    }
    return nil
  }

  /// National / mosaic PNG: chroma rain, not the N0B clutter-key.
  static func mosaicPNGHasPrecip(_ png: Data, minPixels: Int = mosaicPrecipMinPixels) -> Bool {
    guard let source = CGImageSourceCreateWithData(png as CFData, nil),
      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return false }
    let width = cgImage.width
    let height = cgImage.height
    guard width > 0, height > 0 else { return false }
    let bytesPerPixel = 4
    var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    return pixels.withUnsafeMutableBytes { raw -> Bool in
      guard
        let context = CGContext(
          data: raw.baseAddress,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: width * bytesPerPixel,
          space: colorSpace,
          bitmapInfo: bitmapInfo),
        let buffer = raw.baseAddress?.assumingMemoryBound(to: UInt8.self)
      else { return false }
      context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
      var count = 0
      let total = width * height
      for i in 0..<total {
        let o = i * bytesPerPixel
        let a = buffer[o + 3]
        if a < 40 { continue }
        let r = buffer[o]
        let g = buffer[o + 1]
        let b = buffer[o + 2]
        let maxc = max(r, g, b)
        let minc = min(r, g, b)
        if maxc < 40 { continue }
        let sat = maxc == 0 ? 0 : Int(maxc - minc) * 100 / Int(maxc)
        if sat < 22 { continue }
        count += 1
        if count >= minPixels { return true }
      }
      return false
    }
  }

  private static func fetchData(_ url: URL) async -> Data? {
    await fetchData(url, timeout: precipProbeTimeout)
  }

  private static func fetchData(_ url: URL, timeout: TimeInterval) async -> Data? {
    var request = URLRequest(url: url)
    request.timeoutInterval = timeout
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
        !data.isEmpty
      else { return nil }
      return data
    } catch {
      return nil
    }
  }
}
