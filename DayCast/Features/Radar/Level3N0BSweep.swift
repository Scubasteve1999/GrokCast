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
  /// Premultiplied RGBA for each data byte after the 25 dBZ paint floor.
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

  /// Nearest polar bin for painting. A 5–14 dBZ (clutter-keyed) gate sitting
  /// between two 15+ neighbors is a 0.5° / 250 m crack — at close/street zoom
  /// that paints as a white radial through precip. If both azimuth neighbors
  /// (or both range neighbors) are opaque, use that hard NWS bin. Does not
  /// blend dBZ and does not grow precip into clear air (one-sided edges stay).
  func paintByte(rangeMeters: Double, azimuth: Double) -> UInt8? {
    guard let byte = gateByte(rangeMeters: rangeMeters, azimuth: azimuth) else {
      return nil
    }
    if isOpaque(byte) { return byte }
    if let left = gateByte(rangeMeters: rangeMeters, azimuth: azimuth - 0.5),
      let right = gateByte(rangeMeters: rangeMeters, azimuth: azimuth + 0.5),
      isOpaque(left), isOpaque(right)
    {
      return left
    }
    let w = gateWidthMeters
    if let inner = gateByte(rangeMeters: rangeMeters - w, azimuth: azimuth),
      let outer = gateByte(rangeMeters: rangeMeters + w, azimuth: azimuth),
      isOpaque(inner), isOpaque(outer)
    {
      return inner
    }
    return byte
  }

  /// Gate-indexed hole-fill for trapezoid paint. Neighbors are the previous /
  /// next radial and inner / outer range bin — not a ±0.5° resample.
  func paintByte(radialIndex: Int, gateIndex: Int) -> UInt8? {
    guard radialIndex >= 0, radialIndex < radials.count else { return nil }
    let gates = radials[radialIndex].gates
    guard gateIndex >= 0, gateIndex < gates.count else { return nil }
    let byte = gates[gateIndex]
    if isOpaque(byte) { return byte }
    let n = radials.count
    if n >= 3 {
      let left = radials[(radialIndex - 1 + n) % n].gates
      let right = radials[(radialIndex + 1) % n].gates
      if gateIndex < left.count, gateIndex < right.count,
        isOpaque(left[gateIndex]), isOpaque(right[gateIndex])
      {
        return left[gateIndex]
      }
    }
    if gateIndex > 0, gateIndex + 1 < gates.count,
      isOpaque(gates[gateIndex - 1]), isOpaque(gates[gateIndex + 1])
    {
      return gates[gateIndex - 1]
    }
    return byte
  }

  func isOpaque(_ byte: UInt8) -> Bool {
    rgbaLUT[Int(byte)].3 != 0
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
