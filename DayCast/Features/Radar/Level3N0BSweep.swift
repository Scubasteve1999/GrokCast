import Foundation

/// One decoded Super-Res base reflectivity sweep (N0B / product 153).
struct Level3N0BSweep {
  struct Radial {
    var startAzimuth: Double
    var deltaAzimuth: Double
    var gates: [UInt8]
  }

  let siteID: String
  let timestamp: Date
  let latitude: Double
  let longitude: Double
  let gateWidthMeters: Double
  let binCount: Int
  let radials: [Radial]
  /// 720 half-degree slots → radial index, or `0xFFFF` if empty.
  let azIndex: [UInt16]
  /// Packed dBZ for bytes 0...255. NaN = missing / range fold.
  let dbzLUT: [Float]
  /// Premultiplied RGBA for each data byte after the 15 dBZ clutter key.
  let rgbaLUT: [(UInt8, UInt8, UInt8, UInt8)]
  let hasOrganizedPrecip: Bool

  var maxRangeMeters: Double {
    Double(binCount) * gateWidthMeters
  }

  func radialIndex(forAzimuth azimuth: Double) -> Int? {
    var az = azimuth.truncatingRemainder(dividingBy: 360)
    if az < 0 { az += 360 }
    let slot = Int(az * 2) % 720
    guard slot >= 0, slot < azIndex.count else { return nil }
    let idx = azIndex[slot]
    return idx == 0xFFFF ? nil : Int(idx)
  }

  func gateByte(rangeMeters: Double, azimuth: Double) -> UInt8? {
    guard rangeMeters >= 0, rangeMeters < maxRangeMeters else { return nil }
    guard let ri = radialIndex(forAzimuth: azimuth) else { return nil }
    let gi = Int(rangeMeters / gateWidthMeters)
    let gates = radials[ri].gates
    guard gi >= 0, gi < gates.count else { return nil }
    return gates[gi]
  }
}

/// Mapbox interceptor + wet-probe lookup. Replaced wholesale per site load.
final class Level3N0BSweepStore: @unchecked Sendable {
  static let shared = Level3N0BSweepStore()

  private let lock = NSLock()
  private var byExact: [String: Level3N0BSweep] = [:]
  private var byMinute: [String: Level3N0BSweep] = [:]

  private init() {}

  var isEmpty: Bool {
    lock.lock()
    defer { lock.unlock() }
    return byExact.isEmpty
  }

  func removeAll() {
    lock.lock()
    byExact.removeAll(keepingCapacity: true)
    byMinute.removeAll(keepingCapacity: true)
    lock.unlock()
  }

  func replace(_ sweeps: [Level3N0BSweep]) {
    var exact: [String: Level3N0BSweep] = [:]
    var minute: [String: Level3N0BSweep] = [:]
    for sweep in sweeps {
      exact[Self.exactKey(site: sweep.siteID, timestamp: sweep.timestamp)] = sweep
      minute[Self.minuteKey(site: sweep.siteID, timestamp: sweep.timestamp)] = sweep
    }
    lock.lock()
    byExact = exact
    byMinute = minute
    lock.unlock()
  }

  func sweep(site: String, timestamp: Date) -> Level3N0BSweep? {
    lock.lock()
    defer { lock.unlock() }
    if let hit = byExact[Self.exactKey(site: site, timestamp: timestamp)] {
      return hit
    }
    return byMinute[Self.minuteKey(site: site, timestamp: timestamp)]
  }

  static func exactKey(site: String, timestamp: Date) -> String {
    "\(site)-\(Int(timestamp.timeIntervalSince1970))"
  }

  static func minuteKey(site: String, timestamp: Date) -> String {
    let minute = Int(timestamp.timeIntervalSince1970) / 60
    return "\(site)-m\(minute)"
  }
}
