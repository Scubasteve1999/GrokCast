import Foundation

// Xweather (with fradar for forecast) is used for FUTURE radar timeline + tiles
// when RainViewer nowcast is unavailable. Live still prefers RainViewer.

/// Service for Xweather radar tiles (primary provider).
/// Uses https://maps.api.xweather.com for high-quality radar layers.
/// NOW uses the live `radar` layer with past offsets (e.g. `current`, `-5minutes`).
/// FUTURE uses the forecast `fradar` layer with forward offsets (e.g. `current`, `+1h`).
final class XweatherRadarService {

  private static let mapHosts = ["maps1", "maps2", "maps3", "maps4"]
  private static let probeSuccessCacheTTL: TimeInterval = 300
  private static let probeFailureCacheTTL: TimeInterval = 3600
  private static let probeTimeout: TimeInterval = 4
  private static var probeCache: [String: (result: Bool, date: Date)] = [:]
  private static var lastProbeFailure: XweatherProbeFailure?

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
      return "Xweather API keys invalid or lack Maps access."
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

  /// Produces RadarFrame descriptors suitable for the active Mapbox radar timeline + overlay.
  /// Uses the fradar layer for FUTURE precipitation forecast (offsets like "current", "+1h").
  static func loadForecastRadarFrames(
    maxFrames: Int = RadarTimelineConfig.forecastMaxFrames,
    intervalMinutes: Int = RadarTimelineConfig.forecastIntervalMinutes
  ) -> [RadarFrame] {
    let xwFrames = loadForecastFrames(maxFrames: maxFrames, intervalMinutes: intervalMinutes)
    return xwFrames.compactMap { xf -> RadarFrame? in
      guard let templates = tileURLs(layer: .fradar, offset: xf.offset), !templates.isEmpty else {
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
        timestamp = roundedNow.addingTimeInterval(Double(offsetMinutes) * intervalSeconds)
      }

      let layer: XweatherRadarLayer = direction == .past ? .radar : .fradar
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
    case .future: return "+\(hours)h"
    }
  }

  /// Builds a single authenticated Mapbox-compatible tile URL for a given layer + offset.
  static func tileURL(layer: XweatherRadarLayer, offset: String) -> String? {
    tileURLs(layer: layer, offset: offset)?.first
  }

  /// Builds load-balanced tile URL templates across maps1–maps4 hosts.
  static func tileURLs(layer: XweatherRadarLayer, offset: String) -> [String]? {
    guard let auth = DeveloperAPIKey.xweatherMapsAuth else {
      return nil
    }
    return mapHosts.map { host in
      "https://\(host).api.xweather.com/\(auth)/\(layer.rawValue)/{z}/{x}/{y}/\(offset).png"
    }
  }

  /// Lightweight status check — does not gate timeline synthesis or mode switches.
  static func probeAvailability() async -> Bool {
    await probeOffsetCached(layer: .radar, offset: "current")
  }

  /// Single fradar probe for status messaging; tiles are attempted optimistically when keys exist.
  static func probeForecastAvailability() async -> Bool {
    await probeOffsetCached(layer: .fradar, offset: "current")
  }

  private static func probeCacheKey(layer: XweatherRadarLayer, offset: String) -> String {
    "\(layer.rawValue)/\(offset)"
  }

  private static func probeOffsetCached(layer: XweatherRadarLayer, offset: String) async -> Bool {
    let key = probeCacheKey(layer: layer, offset: offset)
    if let cached = cachedProbe(for: key) {
      return cached
    }
    let ok = await probeOffset(layer: layer, offset: offset)
    storeProbe(ok, for: key)
    return ok
  }

  private static func probeOffset(layer: XweatherRadarLayer, offset: String) async -> Bool {
    guard let auth = DeveloperAPIKey.xweatherMapsAuth,
      let url = URL(
        string:
          "https://maps1.api.xweather.com/\(auth)/\(layer.rawValue)/3/2/3/\(offset).png"
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
      let error = json["error"] as? [String: Any],
      let message = error["message"] as? String
    {
      let lower = message.lowercased()
      if lower.contains("daily accesses") || lower.contains("quota") {
        return .quotaExceeded
      }
      if statusCode == 401 || statusCode == 403, lower.contains("access") {
        return .unauthorized
      }
      return .other(message)
    }

    if statusCode == 403 { return .quotaExceeded }
    if statusCode == 401 { return .unauthorized }
    return .other("HTTP \(statusCode)")
  }

  private static func cachedProbe(for key: String) -> Bool? {
    guard let entry = probeCache[key] else { return nil }
    let ttl = entry.result ? probeSuccessCacheTTL : probeFailureCacheTTL
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
    formatter.dateFormat = "HH:mm"
    return formatter
  }()
}