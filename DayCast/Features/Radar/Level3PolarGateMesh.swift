import Foundation

/// One vertex of a polar gate trapezoid in WebMercator [0, 1].
struct Level3PolarVertex {
  var mercX: Float
  var mercY: Float
  var r: UInt8
  var g: UInt8
  var b: UInt8
  var a: UInt8
}

/// CPU mesh: each opaque N0B gate (after paintByte hole-fill) is a trapezoid
/// (az0..az1, r0..r1) projected to mercator. Same-color consecutive gates along
/// a radial merge into one trapezoid. No dBZ blend.
enum Level3PolarGateMesh {
  struct Mesh {
    var vertices: [Level3PolarVertex]
    var triangleCount: Int { vertices.count / 3 }
    var buildMilliseconds: Double
  }

  static func build(sweep: Level3N0BSweep) -> Mesh {
    let t0 = CFAbsoluteTimeGetCurrent()
    let n = sweep.radials.count
    guard n > 0 else {
      return Mesh(vertices: [], buildMilliseconds: 0)
    }

    var vertices: [Level3PolarVertex] = []
    vertices.reserveCapacity(1_200_000)

    let lat0Deg = sweep.latitude
    let lon0Deg = sweep.longitude
    let cosLat0 = cos(lat0Deg * .pi / 180)
    let metersPerDegLat = 111_320.0
    let metersPerDegLon = 111_320.0 * max(0.2, cosLat0)
    let gateW = sweep.gateWidthMeters

    for i in 0..<n {
      let radial = sweep.radials[i]
      let next = sweep.radials[(i + 1) % n]
      let az0 = radial.startAzimuth
      var daz = next.startAzimuth - az0
      if daz <= 0 { daz += 360 }
      let span = radial.deltaAzimuth > 0 ? radial.deltaAzimuth : 0.5
      let az1 = az0 + (daz > span * 2.5 ? span : daz)

      let az0rad = az0 * .pi / 180
      let az1rad = az1 * .pi / 180
      let sinAz0 = sin(az0rad)
      let cosAz0 = cos(az0rad)
      let sinAz1 = sin(az1rad)
      let cosAz1 = cos(az1rad)

      let gates = radial.gates
      var j = 0
      while j < gates.count {
        guard let byte = sweep.paintByte(radialIndex: i, gateIndex: j),
          sweep.isOpaque(byte)
        else {
          j += 1
          continue
        }
        var jEnd = j + 1
        while jEnd < gates.count,
          let nextByte = sweep.paintByte(radialIndex: i, gateIndex: jEnd),
          nextByte == byte
        {
          jEnd += 1
        }
        let color = sweep.rgbaLUT[Int(byte)]
        appendTrapezoid(
          lat0Deg: lat0Deg,
          lon0Deg: lon0Deg,
          metersPerDegLat: metersPerDegLat,
          metersPerDegLon: metersPerDegLon,
          sinAz0: sinAz0,
          cosAz0: cosAz0,
          sinAz1: sinAz1,
          cosAz1: cosAz1,
          r0: Double(j) * gateW,
          r1: Double(jEnd) * gateW,
          color: color,
          into: &vertices)
        j = jEnd
      }
    }

    return Mesh(
      vertices: vertices,
      buildMilliseconds: (CFAbsoluteTimeGetCurrent() - t0) * 1000)
  }

  /// WebMercator x/y in [0, 1], matching Mapbox `latLngToMercatorXY`.
  static func mercatorXY(latitude: Double, longitude: Double) -> (x: Double, y: Double) {
    let x = (longitude + 180) / 360
    let clamped = min(max(latitude, -85.05112878), 85.05112878)
    let latRad = clamped * .pi / 180
    let y = (1 - log(tan(.pi / 4 + latRad / 2)) / .pi) / 2
    return (x, y)
  }

  /// Local tangent-plane dest. Error at 230 km is sub-pixel at overview.
  static func destination(
    lat0Deg: Double, lon0Deg: Double,
    metersPerDegLat: Double, metersPerDegLon: Double,
    sinAz: Double, cosAz: Double, rangeMeters: Double
  ) -> (lat: Double, lon: Double) {
    if rangeMeters <= 0 { return (lat0Deg, lon0Deg) }
    let north = rangeMeters * cosAz
    let east = rangeMeters * sinAz
    return (lat0Deg + north / metersPerDegLat, lon0Deg + east / metersPerDegLon)
  }

  private static func appendTrapezoid(
    lat0Deg: Double, lon0Deg: Double,
    metersPerDegLat: Double, metersPerDegLon: Double,
    sinAz0: Double, cosAz0: Double, sinAz1: Double, cosAz1: Double,
    r0: Double, r1: Double,
    color: (UInt8, UInt8, UInt8, UInt8),
    into vertices: inout [Level3PolarVertex]
  ) {
    let inner0 = destination(
      lat0Deg: lat0Deg, lon0Deg: lon0Deg,
      metersPerDegLat: metersPerDegLat, metersPerDegLon: metersPerDegLon,
      sinAz: sinAz0, cosAz: cosAz0, rangeMeters: r0)
    let inner1 = destination(
      lat0Deg: lat0Deg, lon0Deg: lon0Deg,
      metersPerDegLat: metersPerDegLat, metersPerDegLon: metersPerDegLon,
      sinAz: sinAz1, cosAz: cosAz1, rangeMeters: r0)
    let outer1 = destination(
      lat0Deg: lat0Deg, lon0Deg: lon0Deg,
      metersPerDegLat: metersPerDegLat, metersPerDegLon: metersPerDegLon,
      sinAz: sinAz1, cosAz: cosAz1, rangeMeters: r1)
    let outer0 = destination(
      lat0Deg: lat0Deg, lon0Deg: lon0Deg,
      metersPerDegLat: metersPerDegLat, metersPerDegLon: metersPerDegLon,
      sinAz: sinAz0, cosAz: cosAz0, rangeMeters: r1)
    let v0 = vertex(inner0, color)
    let v1 = vertex(inner1, color)
    let v2 = vertex(outer1, color)
    let v3 = vertex(outer0, color)
    vertices.append(v0)
    vertices.append(v1)
    vertices.append(v2)
    vertices.append(v0)
    vertices.append(v2)
    vertices.append(v3)
  }

  private static func vertex(
    _ ll: (lat: Double, lon: Double),
    _ color: (UInt8, UInt8, UInt8, UInt8)
  ) -> Level3PolarVertex {
    let m = mercatorXY(latitude: ll.lat, longitude: ll.lon)
    return Level3PolarVertex(
      mercX: Float(m.x), mercY: Float(m.y),
      r: color.0, g: color.1, b: color.2, a: color.3)
  }
}

/// Dual-mesh opacity lerp between two hard-NWS trapezoid volumes.
/// Play fade is polar-specific and short so 2x does not dual-draw ~860k tris
/// for the whole frame hold. Stills keep the IEM still duration. No dBZ blend.
enum Level3PolarCrossfade {
  /// Snappy enough that a 720 ms 2x hold is mostly a single mesh.
  static let playDurationSeconds: TimeInterval = 0.20
  /// Matches live IEM still raster fade.
  static let stillDurationSeconds: TimeInterval = 0.32

  static func durationSeconds(isAnimating: Bool) -> TimeInterval {
    isAnimating ? playDurationSeconds : stillDurationSeconds
  }

  static func progress(elapsed: TimeInterval, duration: TimeInterval) -> Float {
    guard duration > 0 else { return 1 }
    return Float(min(1, max(0, elapsed / duration)))
  }

  static func layerOpacities(progress: Float, global: Float)
    -> (outgoing: Float, incoming: Float)
  {
    let t = min(1, max(0, progress))
    return (global * (1 - t), global * t)
  }

  /// Settled volumes live on the front mesh. Fade-end opacities put weight on
  /// the incoming/back slot, so a non-fading draw must not use them.
  static func drawOpacities(progress: Float, global: Float, isFading: Bool)
    -> (front: Float, back: Float)
  {
    if !isFading { return (global, 0) }
    let ops = layerOpacities(progress: progress, global: global)
    return (ops.outgoing, ops.incoming)
  }
}

/// LRU cache of CPU trapezoid meshes keyed by site + volume time.
/// Sized for the whole ~1h Live Site Doppler loop so 2x play is a hit.
final class Level3PolarMeshCache: @unchecked Sendable {
  static let shared = Level3PolarMeshCache()
  /// `siteLoopMaxFrames` plus a few reload-overlap volumes.
  static let maxEntries = RadarLivePresentation.siteLoopMaxFrames + 4

  private let condition = NSCondition()
  private var byKey: [String: Level3PolarGateMesh.Mesh] = [:]
  private var order: [String] = []
  private var building = Set<String>()
  private var hitCount = 0
  private var missCount = 0
  private var warmPending = false
  private var warmWaiters: [CheckedContinuation<Void, Never>] = []

  private init() {}

  func mesh(for sweep: Level3N0BSweep) -> Level3PolarGateMesh.Mesh {
    let key = Level3N0BSweepStore.exactKey(site: sweep.siteID, timestamp: sweep.timestamp)
    condition.lock()
    if let hit = byKey[key] {
      touchLocked(key)
      hitCount += 1
      condition.unlock()
      Level3PolarGPUCache.shared.ingest(key: key, mesh: hit)
      return hit
    }
    if building.contains(key) {
      while building.contains(key) {
        condition.wait()
      }
      if let hit = byKey[key] {
        touchLocked(key)
        hitCount += 1
        condition.unlock()
        Level3PolarGPUCache.shared.ingest(key: key, mesh: hit)
        return hit
      }
    }
    building.insert(key)
    condition.unlock()

    let built = Level3PolarGateMesh.build(sweep: sweep)

    condition.lock()
    byKey[key] = built
    if let idx = order.firstIndex(of: key) {
      order.remove(at: idx)
    }
    order.append(key)
    while order.count > Self.maxEntries {
      let old = order.removeFirst()
      byKey.removeValue(forKey: old)
    }
    building.remove(key)
    missCount += 1
    condition.broadcast()
    condition.unlock()
    Level3PolarGPUCache.shared.ingest(key: key, mesh: built)
    return built
  }

  func cached(site: String, timestamp: Date) -> Level3PolarGateMesh.Mesh? {
    let key = Level3N0BSweepStore.exactKey(site: site, timestamp: timestamp)
    condition.lock()
    defer { condition.unlock() }
    return byKey[key]
  }

  func snapshot() -> [(String, Level3PolarGateMesh.Mesh)] {
    condition.lock()
    defer { condition.unlock() }
    return order.compactMap { key in
      byKey[key].map { (key, $0) }
    }
  }

  var isWarmComplete: Bool {
    condition.lock()
    defer { condition.unlock() }
    return !warmPending
  }

  func markWarmPending() {
    condition.lock()
    warmPending = true
    condition.unlock()
  }

  func waitUntilWarm() async {
    await withCheckedContinuation { continuation in
      condition.lock()
      if !warmPending {
        condition.unlock()
        continuation.resume()
        return
      }
      warmWaiters.append(continuation)
      condition.unlock()
    }
  }

  /// Newest first (Live open still), then oldest→newest so Play's first frames
  /// are warm before the 8-slot LRU hitch can start.
  func warmPlayLoop(_ sweeps: [Level3N0BSweep]) {
    guard let newest = sweeps.last else {
      finishWarm()
      return
    }
    _ = mesh(for: newest)
    for sweep in sweeps.dropLast() {
      _ = mesh(for: sweep)
    }
    Level3PolarGPUCache.shared.prefetchCachedCPUMeshes()
    finishWarm()
  }

  func warmPlayLoopConcurrent(_ sweeps: [Level3N0BSweep]) async {
    guard let newest = sweeps.last else {
      finishWarm()
      return
    }
    _ = mesh(for: newest)
    let rest = Array(sweeps.dropLast())
    await withTaskGroup(of: Void.self) { group in
      var next = 0
      let width = min(4, rest.count)
      func enqueue() {
        guard next < rest.count else { return }
        let sweep = rest[next]
        next += 1
        group.addTask {
          _ = self.mesh(for: sweep)
        }
      }
      for _ in 0..<width { enqueue() }
      for await _ in group {
        enqueue()
      }
    }
    Level3PolarGPUCache.shared.prefetchCachedCPUMeshes()
    finishWarm()
    radarLog("[Level3] polar mesh cache warm \(sweeps.count) frames gpu=\(Level3PolarGPUCache.shared.stats().count)")
  }

  func keepOnly(keys: Set<String>) {
    condition.lock()
    order.removeAll { key in
      if keys.contains(key) { return false }
      byKey.removeValue(forKey: key)
      return true
    }
    condition.unlock()
    Level3PolarGPUCache.shared.keepOnly(keys: keys)
  }

  func removeAll() {
    condition.lock()
    byKey.removeAll(keepingCapacity: true)
    order.removeAll(keepingCapacity: true)
    building.removeAll(keepingCapacity: true)
    hitCount = 0
    missCount = 0
    warmPending = false
    let waiters = warmWaiters
    warmWaiters.removeAll()
    condition.broadcast()
    condition.unlock()
    waiters.forEach { $0.resume() }
    Level3PolarGPUCache.shared.removeAll()
  }

  func stats() -> (count: Int, hits: Int, misses: Int) {
    condition.lock()
    defer { condition.unlock() }
    return (order.count, hitCount, missCount)
  }

  func resetStats() {
    condition.lock()
    hitCount = 0
    missCount = 0
    condition.unlock()
  }

  private func finishWarm() {
    condition.lock()
    warmPending = false
    let waiters = warmWaiters
    warmWaiters.removeAll()
    condition.unlock()
    waiters.forEach { $0.resume() }
  }

  private func touchLocked(_ key: String) {
    if let idx = order.firstIndex(of: key) {
      order.remove(at: idx)
      order.append(key)
    }
  }
}
