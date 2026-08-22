import Foundation

/// Fetches Mac-worker / CDN `timestamps.json` and builds Live National frames.
/// The phone never downloads GRIB2.
enum MRMSRadarService {
  /// Simulator default. Device/TestFlight has no Mac localhost — leave nil
  /// until a CDN base is wired. Fail closed to MapsGL rain.
  static var baseURL: URL? = {
    #if DEBUG
      URL(string: "http://127.0.0.1:8765")
    #else
      nil
    #endif
  }()

  /// Test hook: skip the network.
  static var framesForTesting: [RadarFrame]?
  static var timestampsURLOverride: URL?
  static var session: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 4
    config.timeoutIntervalForResource = 6
    config.waitsForConnectivity = false
    return URLSession(configuration: config)
  }()

  private static let isoFractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private static let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  struct Manifest: Decodable {
    let frames: [Frame]
  }

  struct Frame: Decodable {
    let t: String
    let template: String
    let id: String?
  }

  static func loadLiveFrames() async -> [RadarFrame] {
    if let framesForTesting { return framesForTesting }
    guard let url = timestampsURL else { return [] }
    do {
      var request = URLRequest(url: url)
      request.timeoutInterval = 4
      request.setValue("DayCast/1.0 (https://daycast.app)", forHTTPHeaderField: "User-Agent")
      let (data, response) = try await session.data(for: request)
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode)
      else {
        return []
      }
      return frames(from: data)
    } catch {
      radarLog("[MRMS] timestamps failed — \(error.localizedDescription)")
      return []
    }
  }

  static var timestampsURL: URL? {
    if let timestampsURLOverride { return timestampsURLOverride }
    guard let baseURL else { return nil }
    return baseURL.appendingPathComponent("timestamps.json")
  }

  /// Manifest is newest-first; RadarState wants oldest→newest (`last` = now).
  static func frames(from data: Data, now: Date = Date()) -> [RadarFrame] {
    guard let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else {
      return []
    }
    let parsed: [RadarFrame] = manifest.frames.compactMap { item in
      guard let timestamp = parseTime(item.t), !item.template.isEmpty else { return nil }
      return RadarFrame(
        provider: .mrms,
        kind: .livePrecipitation,
        tileEpoch: Int(timestamp.timeIntervalSince1970),
        timestamp: timestamp,
        tileURLTemplates: [item.template]
      )
    }
    let live = RadarLivePresentation.liveFrames(parsed, isSiteProduct: false, now: now)
    return live.sorted { $0.timestamp < $1.timestamp }
  }

  private static func parseTime(_ raw: String) -> Date? {
    isoFractional.date(from: raw) ?? iso.date(from: raw)
  }
}
