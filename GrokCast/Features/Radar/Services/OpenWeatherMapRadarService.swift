import Foundation

/// OpenWeatherMap Global Precipitation / weather-map tiles (fallback when Maps subscribed).
/// NOW: `maps/2.0/radar` with `tm` (10-minute steps, ~2 days history).
/// FUTURE: `maps/2.0/weather/1h/PR0` with `date` (1-hour steps, up to 4 days ahead).
final class OpenWeatherMapRadarService {

  private static let probeSuccessCacheTTL: TimeInterval = 300
  private static let probeFailureCacheTTL: TimeInterval = 3600
  private static let probeTimeout: TimeInterval = 4
  private static var probeCache: [String: (result: Bool, date: Date)] = [:]
  private static var lastProbeFailure: ProbeFailure?

  enum ProbeFailure: Equatable, CustomStringConvertible {
    case invalidKey
    case subscriptionRequired
    case other(String)

    var description: String {
      switch self {
      case .invalidKey: "invalid API key"
      case .subscriptionRequired: "subscription required"
      case .other(let detail): detail
      }
    }
  }

  static var apiKeyConfigured: Bool {
    !OpenWeatherMapKeys.currentKey.isEmpty
  }

  static var userFacingUnavailableMessage: String? {
    guard let failure = lastProbeFailure else { return nil }
    switch failure {
    case .invalidKey:
      return "OpenWeatherMap map tiles unavailable (key lacks Maps/precip access)."
    case .subscriptionRequired:
      return "OpenWeatherMap map tiles require an active Maps subscription."
    case .other(let detail):
      return "OpenWeatherMap radar unavailable. \(detail)"
    }
  }

  private enum FrameTimelineDirection {
    case past
    case future
  }

  static func loadRecentFrames(
    maxFrames: Int = RadarTimelineConfig.liveMaxFrames
  ) -> [RadarFrame] {
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
  ) -> [RadarFrame] {
    buildFrames(maxFrames: maxFrames, intervalMinutes: intervalMinutes, direction: .future)
  }

  private static func buildFrames(
    maxFrames: Int,
    intervalMinutes: Int,
    direction: FrameTimelineDirection
  ) -> [RadarFrame] {
    let roundedNow = roundToInterval(Date(), minutes: intervalMinutes)
    let intervalSeconds = TimeInterval(intervalMinutes * 60)
    var frames: [RadarFrame] = []

    for step in 0..<maxFrames {
      let timestamp: Date
      switch direction {
      case .past:
        timestamp = roundedNow.addingTimeInterval(-Double(step) * intervalSeconds)
      case .future:
        timestamp = roundedNow.addingTimeInterval(Double(step) * intervalSeconds)
      }

      let tileEpoch = Int(timestamp.timeIntervalSince1970)
      let kind: RadarFrame.Kind =
        direction == .past ? .livePrecipitation : .forecastPrecipitation
      let templates = tileURLTemplates(kind: kind, tileEpoch: tileEpoch)
      frames.append(
        RadarFrame(
          provider: .openWeatherMap,
          kind: kind,
          tileEpoch: tileEpoch,
          timestamp: timestamp,
          tileURLTemplates: templates
        ))
    }

    return frames
  }

  private static func tileURLTemplates(kind: RadarFrame.Kind, tileEpoch: Int) -> [String] {
    guard apiKeyConfigured else { return [] }
    let key = OpenWeatherMapKeys.currentKey
    switch kind {
    case .livePrecipitation:
      return [
        "https://maps.openweathermap.org/maps/2.0/radar/{z}/{x}/{y}?appid=\(key)&tm=\(tileEpoch)"
      ]
    case .forecastPrecipitation:
      return [
        "https://maps.openweathermap.org/maps/2.0/weather/1h/PR0/{z}/{x}/{y}?appid=\(key)&date=\(tileEpoch)"
      ]
    }
  }

  static func probeAvailability() async -> Bool {
    await probeCached(kind: .livePrecipitation, tileEpoch: currentLiveProbeEpoch())
  }

  static func probeForecastAvailability() async -> Bool {
    await probeCached(
      kind: .forecastPrecipitation,
      tileEpoch: currentForecastProbeEpoch()
    )
  }

  private static func currentLiveProbeEpoch() -> Int {
    let rounded = roundToInterval(Date(), minutes: RadarTimelineConfig.liveIntervalMinutes)
    return Int(rounded.timeIntervalSince1970)
  }

  private static func currentForecastProbeEpoch() -> Int {
    let rounded = roundToInterval(Date(), minutes: RadarTimelineConfig.forecastIntervalMinutes)
    return Int(rounded.timeIntervalSince1970)
  }

  private static func probeCacheKey(kind: RadarFrame.Kind, tileEpoch: Int) -> String {
    "\(kind)-\(tileEpoch)"
  }

  private static func probeCached(kind: RadarFrame.Kind, tileEpoch: Int) async -> Bool {
    let key = probeCacheKey(kind: kind, tileEpoch: tileEpoch)
    if let cached = cachedProbe(for: key) {
      return cached
    }
    let ok = await probe(kind: kind, tileEpoch: tileEpoch)
    storeProbe(ok, for: key)
    return ok
  }

  private static func probe(kind: RadarFrame.Kind, tileEpoch: Int) async -> Bool {
    let templates = tileURLTemplates(kind: kind, tileEpoch: tileEpoch)
    let frame = RadarFrame(
      provider: .openWeatherMap,
      kind: kind,
      tileEpoch: tileEpoch,
      timestamp: Date(),
      tileURLTemplates: templates
    )
    guard let urlString = frame.tileURLTemplates.first?
      .replacingOccurrences(of: "{z}", with: "3")
      .replacingOccurrences(of: "{x}", with: "2")
      .replacingOccurrences(of: "{y}", with: "3"),
      let url = URL(string: urlString)
    else {
      return false
    }

    var request = URLRequest(url: url)
    request.timeoutInterval = probeTimeout

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse else { return false }
      let ok = (200..<300).contains(http.statusCode)
      if ok {
        lastProbeFailure = nil
        return true
      }

      lastProbeFailure = failureFromResponse(statusCode: http.statusCode, data: data)
      print(
        "[OpenWeatherMap] Probe failed for \(kind) tm=\(tileEpoch): HTTP \(http.statusCode)"
          + (lastProbeFailure.map { " — \($0)" } ?? "")
      )
      return false
    } catch {
      lastProbeFailure = .other(error.localizedDescription)
      print("[OpenWeatherMap] Probe failed for \(kind) tm=\(tileEpoch): \(error)")
      return false
    }
  }

  private static func failureFromResponse(statusCode: Int, data: Data) -> ProbeFailure {
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      let message = (json["message"] as? String) ?? (json["cod"] as? String).map { "HTTP \($0)" }
      if let message {
        let lower = message.lowercased()
        if lower.contains("invalid api key") || statusCode == 401 {
          return .invalidKey
        }
        if lower.contains("subscription") || lower.contains("not authorized") {
          return .subscriptionRequired
        }
        return .other(message)
      }
    }

    if statusCode == 401 { return .invalidKey }
    if statusCode == 403 { return .subscriptionRequired }
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

  private static func roundToInterval(_ date: Date, minutes: Int) -> Date {
    let calendar = Calendar(identifier: .gregorian)
    var components = calendar.dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: date)
    let minute = components.minute ?? 0
    components.minute = (minute / minutes) * minutes
    components.second = 0
    return calendar.date(from: components) ?? date
  }
}