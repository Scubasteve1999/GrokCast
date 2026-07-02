import Foundation

struct RainViewerRadarFrame: Equatable {
  let time: Int
  let path: String
}

struct RainViewerRadarPayload: Equatable {
  var host: String = "https://tilecache.rainviewer.com"
  var pastFrames: [RainViewerRadarFrame] = []
  var futureFrames: [RainViewerRadarFrame] = []
  static let empty = RainViewerRadarPayload()
}

final class RainViewerRadarService {

  private static let metadataURLs = [
    "https://api.rainviewer.com/public/weather-maps.json",
    "https://tilecache.rainviewer.com/api/maps.json",
  ]

  static func loadDatasetFrames() async -> (live: [RadarFrame], forecast: [RadarFrame]) {
    let payload = await loadPayload()
    let live = frames(from: payload.pastFrames, host: payload.host, kind: .livePrecipitation)
    let forecast = frames(
      from: payload.futureFrames,
      host: payload.host,
      kind: .forecastPrecipitation
    )
    return (live, forecast)
  }

  private static func loadPayload() async -> RainViewerRadarPayload {
    for urlString in metadataURLs {
      guard let url = URL(string: urlString) else { continue }
      do {
        let data = try await fetchWithTimeout(seconds: 8.0) {
          let (responseData, _) = try await URLSession.shared.data(from: url)
          return responseData
        }
        let payload = buildPayload(from: data)
        if !payload.pastFrames.isEmpty || !payload.futureFrames.isEmpty {
          return payload
        }
      } catch {
        print("[RADAR] RainViewer fetch failed for \(urlString): \(error)")
      }
    }

    print("[RADAR] RainViewer fetch failed: all endpoints exhausted")
    return .empty
  }

  private static func frames(
    from infos: [RainViewerRadarFrame],
    host: String,
    kind: RadarFrame.Kind
  ) -> [RadarFrame] {
    infos.map { info in
      RadarFrame(
        provider: .rainViewer,
        kind: kind,
        tileEpoch: info.time,
        timestamp: Date(timeIntervalSince1970: TimeInterval(info.time)),
        tileURLTemplates: [tileTemplate(host: host, path: info.path)]
      )
    }
  }

  private static func tileTemplate(host: String, path: String) -> String {
    "\(host)\(path)/256/{z}/{x}/{y}/2/1_1.png"
  }

  private static func buildPayload(from data: Data) -> RainViewerRadarPayload {
    let (host, pastInfos, nowcastInfos) = parseRainViewerResponse(data)
    let now = Int(Date().timeIntervalSince1970)
    var payload = RainViewerRadarPayload(host: host)

    if !pastInfos.isEmpty {
      let fresh = pastInfos.filter { now - $0.time < 7200 }
      if !fresh.isEmpty {
        let recent = Array(fresh.suffix(12))
        payload.pastFrames = recent.map { RainViewerRadarFrame(time: $0.time, path: $0.path) }
      }
    }

    if !nowcastInfos.isEmpty {
      let futures = nowcastInfos.filter { $0.time > now && $0.time - now < 7200 }
      if !futures.isEmpty {
        let limited = Array(futures.prefix(12))
        payload.futureFrames = limited.map { RainViewerRadarFrame(time: $0.time, path: $0.path) }
      }
    } else {
      #if DEBUG
        print(
          "[RADAR] RainViewer nowcast empty — forecast tiles discontinued from public API (Jan 2026)"
        )
      #endif
    }

    return payload
  }

  private static func parseRainViewerResponse(_ data: Data) -> (
    String, [(time: Int, path: String)], [(time: Int, path: String)]
  ) {
    var host = "https://tilecache.rainviewer.com"
    var pastInfos: [(time: Int, path: String)] = []
    var nowcastInfos: [(time: Int, path: String)] = []
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      if let parsedHost = json["host"] as? String, !parsedHost.isEmpty {
        host = parsedHost
      }
      if let radar = json["radar"] as? [String: Any] {
        if let past = radar["past"] as? [[String: Any]] {
          pastInfos = past.compactMap { item in
            if let t = item["time"] as? Int, let p = item["path"] as? String {
              return (t, p)
            }
            return nil
          }
        }
        if let nowcast = radar["nowcast"] as? [[String: Any]] {
          nowcastInfos = nowcast.compactMap { item in
            if let t = item["time"] as? Int, let p = item["path"] as? String {
              return (t, p)
            }
            return nil
          }
        }
      }
    }
    return (host, pastInfos, nowcastInfos)
  }

  private static func fetchWithTimeout<T>(
    seconds: TimeInterval, operation: @escaping () async throws -> T
  ) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
      group.addTask {
        try await operation()
      }
      group.addTask {
        try await Task.sleep(for: .seconds(seconds))
        throw URLError(.timedOut)
      }
      guard let result = try await group.next() else {
        group.cancelAll()
        throw URLError(.unknown)
      }
      group.cancelAll()
      return result
    }
  }
}