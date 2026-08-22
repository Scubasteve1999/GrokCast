import CoreLocation
import Foundation

/// Fetch Super-Res N0B files from NOAA/Unidata's public Level III bucket.
///
/// Keys: `SITE_N0B_YYYY_MM_DD_HH_MM_SS` in `s3://unidata-nexrad-level3`
/// (anonymous HTTP, no-sign-request). Decode + polar paint live on device.
enum Level3N0BService {
  static let bucketHost = "https://unidata-nexrad-level3.s3.amazonaws.com"
  private static let userAgent = "DayCast/1.0 (https://daycast.app)"
  private static let requestTimeout: TimeInterval = 8
  private static let listTimeout: TimeInterval = 8
  private static let maxConcurrentDownloads = 6

  @MainActor
  static func loadSiteFramesNear(
    coordinate: CLLocationCoordinate2D,
    preferredSite: IEMRadarService.Site? = nil,
    maxFrames: Int = RadarLivePresentation.siteLoopMaxFrames
  ) async -> IEMRadarService.SiteFrameLoad? {
    var candidates = await IEMRadarService.nearestSites(to: coordinate, limit: 4)
    if let preferredSite, !candidates.contains(where: { $0.id == preferredSite.id }) {
      candidates.insert(preferredSite, at: 0)
    }
    var seen = Set<String>()
    candidates = candidates.filter { seen.insert($0.id).inserted }
    guard let preferred = preferredSite ?? candidates.first else { return nil }

    for site in candidates {
      let loaded = await loadFrames(site: site, maxFrames: maxFrames)
      if let load = IEMRadarService.siteFrameLoad(
        frames: loaded.frames, site: site, preferred: preferred)
      {
        Level3N0BSweepStore.shared.replace(loaded.sweeps)
        let sweeps = loaded.sweeps
        let keys = Set(
          sweeps.map {
            Level3N0BSweepStore.exactKey(site: $0.siteID, timestamp: $0.timestamp)
          })
        Level3PolarMeshCache.shared.keepOnly(keys: keys)
        Level3PolarMeshCache.shared.markWarmPending()
        Task.detached(priority: .userInitiated) {
          await Level3PolarMeshCache.shared.warmPlayLoopConcurrent(sweeps)
        }
        radarLog(
          "[Level3] N0B polar \(site.id) \(loaded.frames.count) scans, newest \(Int(load.newestScanAge / 60))m"
        )
        return load
      }
    }
    return nil
  }

  static func loadFrames(
    site: IEMRadarService.Site,
    maxFrames: Int,
    now: Date = Date(),
    lookback: TimeInterval = RadarLivePresentation.loopWindow
  ) async -> (frames: [RadarFrame], sweeps: [Level3N0BSweep]) {
    let keys = await listKeys(
      site: site.id, from: now.addingTimeInterval(-lookback), to: now)
    let newest = Array(keys.suffix(maxFrames))
    guard !newest.isEmpty else { return ([], []) }

    var sweepsByKey: [String: Level3N0BSweep] = [:]
    await withTaskGroup(of: (String, Level3N0BSweep?).self) { group in
      var inFlight = 0
      var iterator = newest.makeIterator()
      func enqueue(_ key: String) {
        inFlight += 1
        group.addTask {
          let sweep = await downloadAndDecode(key: key, site: site)
          return (key, sweep)
        }
      }
      while inFlight < maxConcurrentDownloads, let key = iterator.next() {
        enqueue(key)
      }
      while let (key, sweep) = await group.next() {
        inFlight -= 1
        if let sweep { sweepsByKey[key] = sweep }
        if let next = iterator.next() { enqueue(next) }
      }
    }

    let ordered = newest.compactMap { sweepsByKey[$0] }
    let frames = ordered.map { sweep in
      RadarFrame(
        provider: .iem,
        kind: .livePrecipitation,
        tileEpoch: Int(sweep.timestamp.timeIntervalSince1970),
        timestamp: sweep.timestamp,
        tileURLTemplates: [
          IEMRadarService.ridgeTileTemplate(
            radar: site.id, productCode: "N0B", timestamp: sweep.timestamp)
        ],
        paintsPolarRadials: true)
    }
    return (frames, ordered)
  }

  static func listKeys(site: String, from: Date, to: Date) async -> [String] {
    var keys: [String] = []
    for prefix in hourPrefixes(site: site, from: from, to: to) {
      let listed = await listPrefix(prefix)
      keys.append(contentsOf: listed)
    }
    let fromStamp = objectStamp(from)
    let toStamp = objectStamp(to.addingTimeInterval(60))
    return keys.filter { key in
      guard let stamp = stamp(fromObjectKey: key) else { return false }
      return stamp >= fromStamp && stamp <= toStamp
    }.sorted()
  }

  static func hourPrefixes(site: String, from: Date, to: Date) -> [String] {
    var hours: [String] = []
    var cursor = floorToHour(from)
    let end = floorToHour(to)
    let fmt = hourFormatter
    while cursor <= end {
      hours.append("\(site)_N0B_\(fmt.string(from: cursor))")
      cursor = cursor.addingTimeInterval(3600)
    }
    return hours
  }

  static func stamp(fromObjectKey key: String) -> String? {
    // TWX_N0B_2026_08_22_13_39_44
    let parts = key.split(separator: "_")
    guard parts.count >= 8 else { return nil }
    return parts.suffix(6).joined(separator: "_")
  }

  static func date(fromObjectKey key: String) -> Date? {
    guard let stamp = stamp(fromObjectKey: key) else { return nil }
    return objectFormatter.date(from: stamp)
  }

  private static func downloadAndDecode(key: String, site: IEMRadarService.Site)
    async -> Level3N0BSweep?
  {
    guard let url = URL(string: "\(bucketHost)/\(key)") else { return nil }
    var request = URLRequest(url: url)
    request.timeoutInterval = requestTimeout
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
        !data.isEmpty
      else { return nil }
      guard var sweep = Level3N0BDecoder.decode(data, siteHint: site.id) else {
        radarLog("[Level3] decode failed \(key) (\(data.count) B)")
        return nil
      }
      if sweep.siteID.isEmpty {
        sweep = Level3N0BSweep(
          siteID: site.id,
          timestamp: sweep.timestamp,
          latitude: sweep.latitude == 0 ? site.lat : sweep.latitude,
          longitude: sweep.longitude == 0 ? site.lon : sweep.longitude,
          gateWidthMeters: sweep.gateWidthMeters,
          binCount: sweep.binCount,
          radials: sweep.radials,
          azIndex: sweep.azIndex,
          dbzLUT: sweep.dbzLUT,
          rgbaLUT: sweep.rgbaLUT,
          hasOrganizedPrecip: sweep.hasOrganizedPrecip)
      }
      return sweep
    } catch {
      radarLog("[Level3] fetch failed \(key): \(error.localizedDescription)")
      return nil
    }
  }

  private static func listPrefix(_ prefix: String) async -> [String] {
    var components = URLComponents(string: bucketHost)!
    components.queryItems = [
      URLQueryItem(name: "list-type", value: "2"),
      URLQueryItem(name: "prefix", value: prefix),
      URLQueryItem(name: "max-keys", value: "1000"),
    ]
    guard let url = components.url else { return [] }
    var request = URLRequest(url: url)
    request.timeoutInterval = listTimeout
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
        let xml = String(data: data, encoding: .utf8)
      else { return [] }
      return keys(fromListXML: xml)
    } catch {
      radarLog("[Level3] list failed \(prefix): \(error.localizedDescription)")
      return []
    }
  }

  static func keys(fromListXML xml: String) -> [String] {
    var keys: [String] = []
    let marker = "<Key>"
    var search = xml[...]
    while let start = search.range(of: marker) {
      let after = search[start.upperBound...]
      guard let end = after.range(of: "</Key>") else { break }
      keys.append(String(after[..<end.lowerBound]))
      search = after[end.upperBound...]
    }
    return keys
  }

  private static func floorToHour(_ date: Date) -> Date {
    let t = date.timeIntervalSince1970
    return Date(timeIntervalSince1970: (t / 3600).rounded(.down) * 3600)
  }

  private static func objectStamp(_ date: Date) -> String {
    objectFormatter.string(from: date)
  }

  private static let hourFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.dateFormat = "yyyy_MM_dd_HH"
    return f
  }()

  private static let objectFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.dateFormat = "yyyy_MM_dd_HH_mm_ss"
    return f
  }()
}
