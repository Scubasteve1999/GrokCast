import Foundation

// Xweather fradar is the preferred FUTURE radar when maps auth + probe succeed.
// Fallbacks: RainViewer nowcast, then OpenWeatherMap PR0. Live ranking is in RadarLoader.

/// Service for Xweather radar tiles (primary provider).
/// Uses https://maps.api.xweather.com for high-quality radar layers.
/// NOW prefers live `radar-global` (radar + satellite fill), falling back to `radar`.
/// FUTURE uses the forecast `fradar` layer with forward offsets (e.g. `current`, `+1hour`).
final class XweatherRadarService {

  private static let mapHosts = ["maps1", "maps2", "maps3", "maps4"]
  private static let probeSuccessCacheTTL: TimeInterval = 300
  /// Quota / generic failures — avoid hammering Maps after a hard deny.
  private static let probeFailureCacheTTL: TimeInterval = 900
  /// Auth/plan activation recovers quickly (was 1h and kept Forecast dead after subscribe).
  private static let probeUnauthorizedFailureCacheTTL: TimeInterval = 45
  private static let probeTimeout: TimeInterval = 4
  private static var probeCache: [String: (result: Bool, date: Date)] = [:]
  private static var lastProbeFailure: XweatherProbeFailure?
  /// Chosen after a successful live probe (`radar-global` preferred).
  private static var preferredLiveLayer: XweatherRadarLayer = .radarGlobal

  enum XweatherProbeFailure: Equatable, CustomStringConvertible {
    case quotaExceeded
    case unauthorized
    case other(String)

    var description: String {
      switch self {
      case .quotaExceeded: "daily quota exceeded"
      case .unauthorized: "unauthorized"
      case .other(let detail): detail
      }
    }
  }

  static var mapsAuthConfigured: Bool {
    DeveloperAPIKey.xweatherMapsAuth != nil
  }

  /// User-facing hint when probes fail but keys are configured (e.g. daily quota).
  static var userFacingUnavailableMessage: String? {
    guard let failure = lastProbeFailure else { return nil }
    switch failure {
    case .quotaExceeded:
      return "Xweather daily map quota exceeded. Tiles refresh when quota resets."
    case .unauthorized:
      return "Xweather Maps keys invalid or lack Maps access. Check DeveloperAPIKey."
    case .other(let detail):
      return "Xweather radar unavailable. \(detail)"
    }
  }

  private enum FrameTimelineDirection {
    case past
    case future
  }

  /// Returns a list of recent frame descriptors for live radar animation.
  /// We synthesize a rolling window using Xweather's offset strings because
  /// there isn't a simple public "list all recent frames" JSON like RainViewer.
  ///
  /// Offsets are in the format expected by Xweather maps (e.g. "current", "-5minutes", "+1h").
  static func loadRecentFrames(
    maxFrames: Int = RadarTimelineConfig.liveMaxFrames
  ) -> [XweatherRadarFrame] {
    let frames = buildFrames(
      maxFrames: maxFrames,
      intervalMinutes: RadarTimelineConfig.liveIntervalMinutes,
      direction: .past
    )
    return frames.reversed()
  }

  static func loadForecastFrames(
    maxFrames: Int = RadarTimelineConfig.forecastMaxFrames,
    intervalMinutes: Int = RadarTimelineConfig.forecastIntervalMinutes
  ) -> [XweatherRadarFrame] {
    buildFrames(maxFrames: maxFrames, intervalMinutes: intervalMinutes, direction: .future)
  }

  /// Live mosaic frames for NOW mode (past offsets + `current`).
  /// Prefers `radar-global` @2x (512×512) — callers must set Mapbox `tileSize = 512`.
  static func loadLiveRadarFrames(
    maxFrames: Int = RadarTimelineConfig.liveMaxFrames
  ) -> [RadarFrame] {
    let xwFrames = loadRecentFrames(maxFrames: maxFrames)
    return xwFrames.compactMap { xf -> RadarFrame? in
      guard let templates = tileURLs(layer: xf.layer, offset: xf.offset, retina: true),
        !templates.isEmpty
      else {
        return nil
      }
      return RadarFrame(
        provider: .xweather,
        kind: .livePrecipitation,
        tileEpoch: Int(xf.timestamp.timeIntervalSince1970),
        timestamp: xf.timestamp,
        tileURLTemplates: templates
      )
    }
  }

  /// Produces RadarFrame descriptors suitable for the active Mapbox radar timeline + overlay.
  /// Uses the `fradar` layer for FUTURE precipitation forecast (offsets like `current`, `+1hour`).
  static func loadForecastRadarFrames(
    maxFrames: Int = RadarTimelineConfig.forecastMaxFrames,
    intervalMinutes: Int = RadarTimelineConfig.forecastIntervalMinutes
  ) -> [RadarFrame] {
    let xwFrames = loadForecastFrames(maxFrames: maxFrames, intervalMinutes: intervalMinutes)
    return xwFrames.compactMap { xf -> RadarFrame? in
      guard let templates = tileURLs(layer: xf.layer, offset: xf.offset, retina: true),
        !templates.isEmpty
      else {
        return nil
      }
      return RadarFrame(
        provider: .xweather,
        kind: .forecastPrecipitation,
        tileEpoch: Int(xf.timestamp.timeIntervalSince1970),
        timestamp: xf.timestamp,
        tileURLTemplates: templates
      )
    }
  }

  private static func buildFrames(
    maxFrames: Int,
    intervalMinutes: Int,
    direction: FrameTimelineDirection
  ) -> [XweatherRadarFrame] {
    let calendar = Calendar(identifier: .gregorian)
    var components = calendar.dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: Date())
    let minute = components.minute ?? 0
    components.minute = (minute / intervalMinutes) * intervalMinutes
    components.second = 0
    guard let roundedNow = calendar.date(from: components) else {
      return []
    }

    let intervalSeconds = TimeInterval(intervalMinutes * 60)
    var frames: [XweatherRadarFrame] = []

    for step in 0..<maxFrames {
      let offsetMinutes = step * intervalMinutes
      let offsetString = offsetString(forMinutes: offsetMinutes, direction: direction)
      let timestamp: Date
      switch direction {
      case .past:
        timestamp = roundedNow.addingTimeInterval(-Double(step) * intervalSeconds)
      case .future:
        timestamp = roundedNow.addingTimeInterval(Double(step) * intervalSeconds)
      }

      let layer: XweatherRadarLayer =
        direction == .future ? .fradar : preferredLiveLayer
      frames.append(
        XweatherRadarFrame(
          layer: layer,
          offset: offsetString,
          timestamp: timestamp
        ))
    }

    return frames
  }

  private static func offsetString(
    forMinutes minutes: Int,
    direction: FrameTimelineDirection
  ) -> String {
    if minutes == 0 { return "current" }
    let hours = minutes / 60
    switch direction {
    case .past: return "-\(minutes)minutes"
    case .future:
      if hours == 1 { return "+1hour" }
      return "+\(hours)hours"
    }
  }

  /// Builds a single authenticated Mapbox-compatible tile URL for a given layer + offset.
  static func tileURL(layer: XweatherRadarLayer, offset: String, retina: Bool = false) -> String? {
    tileURLs(layer: layer, offset: offset, retina: retina)?.first
  }

  /// Builds load-balanced tile URL templates across maps1–maps4 hosts.
  /// Pass `retina: true` for `@2x.png` 512×512 tiles (fradar forecast frames).
  /// Callers using 512px tiles must also set `tileSize = 512` on the Mapbox source.
  static func tileURLs(layer: XweatherRadarLayer, offset: String, retina: Bool = false) -> [String]? {
    guard let auth = DeveloperAPIKey.xweatherMapsAuth else {
      return nil
    }
    let ext = retina ? "@2x.png" : ".png"
    return mapHosts.map { host in
      "https://\(host).api.xweather.com/\(auth)/\(layer.rawValue)/{z}/{x}/{y}/\(offset)\(ext)"
    }
  }

  /// Lightweight status check — does not gate timeline synthesis or mode switches.
  /// Probes `radar-global` first (best mosaic), then plain `radar`.
  static func probeAvailability() async -> Bool {
    if await probeOffsetCached(layer: .radarGlobal, offset: "current", retina: true) {
      preferredLiveLayer = .radarGlobal
      return true
    }
    if await probeOffsetCached(layer: .radar, offset: "current", retina: true) {
      preferredLiveLayer = .radar
      return true
    }
    return false
  }

  /// Validates forecast `fradar` tile access before FUTURE overlays are shown.
  static func probeForecastAvailability() async -> Bool {
    await probeOffsetCached(layer: .fradar, offset: "+1hour", retina: true)
  }

  /// Clears cached probe results (e.g. after fixing Maps credentials / plan).
  static func invalidateProbeCache() {
    probeCache.removeAll()
    lastProbeFailure = nil
  }

  private static func probeCacheKey(layer: XweatherRadarLayer, offset: String, retina: Bool) -> String {
    "\(layer.rawValue)/\(offset)/\(retina ? "2x" : "1x")"
  }

  private static func probeOffsetCached(
    layer: XweatherRadarLayer, offset: String, retina: Bool = false
  ) async -> Bool {
    let key = probeCacheKey(layer: layer, offset: offset, retina: retina)
    if let cached = cachedProbe(for: key) {
      return cached
    }
    let ok = await probeOffset(layer: layer, offset: offset, retina: retina)
    storeProbe(ok, for: key)
    return ok
  }

  private static func probeOffset(
    layer: XweatherRadarLayer, offset: String, retina: Bool = false
  ) async -> Bool {
    guard let auth = DeveloperAPIKey.xweatherMapsAuth else {
      return false
    }
    let ext = retina ? "@2x.png" : ".png"
    guard
      let url = URL(
        string:
          "https://maps1.api.xweather.com/\(auth)/\(layer.rawValue)/6/16/24/\(offset)\(ext)"
      )
    else {
      return false
    }

    var request = URLRequest(url: url)
    request.timeoutInterval = probeTimeout

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse else {
        return false
      }
      let ok = (200..<300).contains(http.statusCode) || http.statusCode == 302
      if ok {
        if let contentType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased(),
          contentType.contains("json")
        {
          lastProbeFailure = failureFromResponse(statusCode: http.statusCode, data: data)
          return false
        }
        lastProbeFailure = nil
        return true
      }

      lastProbeFailure = failureFromResponse(statusCode: http.statusCode, data: data)
      print(
        "[Xweather] Probe failed for \(layer.rawValue)/\(offset): HTTP \(http.statusCode)"
          + (lastProbeFailure.map { " — \($0)" } ?? "")
      )
      return false
    } catch {
      lastProbeFailure = .other(error.localizedDescription)
      print("[Xweather] Probe failed for \(layer.rawValue)/\(offset): \(error)")
      return false
    }
  }

  private static func failureFromResponse(statusCode: Int, data: Data) -> XweatherProbeFailure {
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let error = json["error"] as? [String: Any]
    {
      let code = (error["code"] as? String)?.lowercased() ?? ""
      let message = (error["message"] as? String) ?? ""
      let lower = message.lowercased()
      if lower.contains("daily accesses") || lower.contains("quota") {
        return .quotaExceeded
      }
      // Maps often returns 403 + "Invalid client credentials" for wrong/revoked keys
      // or apps without Raster Maps entitlement — not a daily quota miss.
      if code.contains("authorization") || lower.contains("invalid client")
        || lower.contains("credentials") || lower.contains("unauthorized")
        || statusCode == 401 || (statusCode == 403 && lower.contains("access"))
      {
        return .unauthorized
      }
      if statusCode == 403 { return .quotaExceeded }
      return .other(message.isEmpty ? "HTTP \(statusCode)" : message)
    }

    if statusCode == 401 { return .unauthorized }
    if statusCode == 403 { return .quotaExceeded }
    return .other("HTTP \(statusCode)")
  }

  /// True when the last probe failed due to bad/missing Maps credentials (not quota).
  static var lastFailureIsUnauthorized: Bool {
    if case .unauthorized = lastProbeFailure { return true }
    return false
  }

  private static func cachedProbe(for key: String) -> Bool? {
    guard let entry = probeCache[key] else { return nil }
    let ttl: TimeInterval
    if entry.result {
      ttl = probeSuccessCacheTTL
    } else if case .unauthorized = lastProbeFailure {
      ttl = probeUnauthorizedFailureCacheTTL
    } else {
      ttl = probeFailureCacheTTL
    }
    guard Date().timeIntervalSince(entry.date) < ttl else { return nil }
    return entry.result
  }

  private static func storeProbe(_ result: Bool, for key: String) {
    probeCache[key] = (result, Date())
  }
}

/// Lightweight descriptor for one Xweather radar frame.
struct XweatherRadarFrame: Equatable {
  let layer: XweatherRadarLayer
  let offset: String
  let timestamp: Date

  func forecastLabel(anchor: Date?) -> String {
    guard let anchor else { return displayTime }
    let minutes = Int(timestamp.timeIntervalSince(anchor) / 60)
    if minutes <= 0 { return "Now" }
    if minutes < 60 { return "+\(minutes)m" }
    let hours = minutes / 60
    let rem = minutes % 60
    if rem == 0 { return "+\(hours)h" }
    return "+\(hours)h \(rem)m"
  }

  private static let displayTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    formatter.timeZone = .current
    return formatter
  }()

  var displayTime: String {
    Self.displayTimeFormatter.string(from: timestamp)
  }

  func timelineLabel(showingFuture: Bool, forecastAnchor: Date?) -> String {
    if showingFuture {
      return forecastLabel(anchor: forecastAnchor)
    }
    return Self.scrubberTimeFormatter.string(from: timestamp)
  }

  private static let scrubberTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    formatter.timeZone = .current
    return formatter
  }()
}