import Foundation

/// Covering-fan vertex in WebMercator [0, 1]. `level` is unused on the
/// texture path — the fragment shader samples the polar field.
struct Level3PolarVertex {
  var mercX: Float
  var mercY: Float
  var level: Float
  var pad: Float = 0
}

/// CPU polar field: rasterize N0B data-bytes onto a 720 × gates texture,
/// wet-only blur (no dilation into clear), covering fan for the radar disk.
/// GPU bilinear-samples the field then LUT-snaps so isocontours are organic
/// at close zoom (gate-quad triangles cannot). Play fade is opacity only.
enum Level3PolarGateMesh {
  struct Mesh {
    var vertices: [Level3PolarVertex]
    var lut: [UInt8]
    var field: [Float]
    var fieldWidth: Int
    var fieldHeight: Int
    var siteLatitude: Double
    var siteLongitude: Double
    var maxRangeMeters: Double
    var triangleCount: Int { vertices.count / 3 }
    var buildMilliseconds: Double
    var hasField: Bool {
      fieldWidth > 0 && fieldHeight > 0 && field.count == fieldWidth * fieldHeight
    }
  }

  static let coveringWedges = 180
  static let fieldBlurPasses = 4
  static let fieldBlurRadius = 1

  /// Opaque-only spatial soft before meshing. Azimuth 9-tap (7/5/3 fallback)
  /// plus range 7-tap (5/3 fallback). Every kernel sample must already be
  /// opaque so cells blob without growing precip into clear air.
  static func smoothOpaqueNeighbors(_ levels: [[Float]]) -> [[Float]] {
    let az = smoothOpaqueAzimuth(levels, halfWidths: [4, 3, 2, 1])
    return smoothOpaqueRange(az, halfWidths: [3, 2, 1])
  }

  /// Insert a midpoint sample between adjacent range gates. Both gates must
  /// be opaque or the midpoint stays 0 (no dilation). Close-zoom isocontours
  /// then have 125 m segments instead of 250 m stairs.
  static func upsampleOpaqueRange2x(_ levels: [[Float]]) -> [[Float]] {
    levels.map { row in
      guard row.count > 1 else { return row }
      var out = [Float](repeating: 0, count: row.count * 2 - 1)
      for j in 0..<row.count {
        out[j * 2] = row[j]
        if j + 1 < row.count {
          let a = row[j]
          let b = row[j + 1]
          if a > 0 && b > 0 {
            out[j * 2 + 1] = (a + b) / 2
          }
        }
      }
      return out
    }
  }

  static func smoothOpaqueAzimuth(_ levels: [[Float]], halfWidths: [Int]) -> [[Float]] {
    let n = levels.count
    guard n > 2 else { return levels }
    var out = levels
    for i in 0..<n {
      let mid = levels[i]
      var row = mid
      for j in 0..<mid.count {
        let center = mid[j]
        if center <= 0 { continue }
        for half in halfWidths {
          if n <= half * 2 { continue }
          var sum = center
          var ok = true
          var d = 1
          while d <= half {
            let left = levels[(i - d + n) % n]
            let right = levels[(i + d) % n]
            if j >= left.count || j >= right.count || left[j] <= 0 || right[j] <= 0 {
              ok = false
              break
            }
            sum += left[j] + right[j]
            d += 1
          }
          if ok {
            row[j] = sum / Float(half * 2 + 1)
            break
          }
        }
      }
      out[i] = row
    }
    return out
  }

  static func smoothOpaqueRange(_ levels: [[Float]], halfWidths: [Int]) -> [[Float]] {
    var out = levels
    for i in 0..<levels.count {
      let mid = levels[i]
      let count = mid.count
      guard count > 2 else { continue }
      var row = mid
      for j in 0..<count {
        let center = mid[j]
        if center <= 0 { continue }
        for half in halfWidths {
          if j < half || j + half >= count { continue }
          var sum = center
          var ok = true
          var d = 1
          while d <= half {
            let inner = mid[j - d]
            let outer = mid[j + d]
            if inner <= 0 || outer <= 0 {
              ok = false
              break
            }
            sum += inner + outer
            d += 1
          }
          if ok {
            row[j] = sum / Float(half * 2 + 1)
            break
          }
        }
      }
      out[i] = row
    }
    return out
  }

  /// Merge consecutive range samples that already snap to the same contour.
  static func sameContourLevel(_ a: Float, _ b: Float) -> Bool {
    if a == b { return true }
    if a <= 0 || b <= 0 { return false }
    return abs(a - b) < 0.5
  }

  static func packedLUT(_ rgba: [(UInt8, UInt8, UInt8, UInt8)]) -> [UInt8] {
    var out = [UInt8](repeating: 0, count: 256 * 4)
    let n = min(256, rgba.count)
    for i in 0..<n {
      let c = rgba[i]
      out[i * 4] = c.0
      out[i * 4 + 1] = c.1
      out[i * 4 + 2] = c.2
      out[i * 4 + 3] = c.3
    }
    return out
  }

  static func build(sweep: Level3N0BSweep) -> Mesh {
    let t0 = CFAbsoluteTimeGetCurrent()
    let lut = packedLUT(sweep.rgbaLUT)
    let lat0Deg = sweep.latitude
    let lon0Deg = sweep.longitude
    let maxRange = sweep.maxRangeMeters
    func finished(
      vertices: [Level3PolarVertex], field: [Float], width: Int, height: Int
    ) -> Mesh {
      Mesh(
        vertices: vertices,
        lut: lut,
        field: field,
        fieldWidth: width,
        fieldHeight: height,
        siteLatitude: lat0Deg,
        siteLongitude: lon0Deg,
        maxRangeMeters: maxRange,
        buildMilliseconds: (CFAbsoluteTimeGetCurrent() - t0) * 1000)
    }
    guard sweep.radials.count > 1, sweep.binCount > 0 else {
      return finished(vertices: [], field: [], width: 0, height: 0)
    }

    let raster = rasterizeField(sweep: sweep)
    var wet = false
    for v in raster.levels where v > 0 {
      wet = true
      break
    }
    guard wet else {
      return finished(vertices: [], field: raster.levels, width: raster.width, height: raster.height)
    }

    let blurred = blurWetOnly(
      raster.levels, width: raster.width, height: raster.height)
    let cosLat0 = cos(lat0Deg * .pi / 180)
    let vertices = buildCoveringFan(
      lat0Deg: lat0Deg,
      lon0Deg: lon0Deg,
      metersPerDegLat: 111_320.0,
      metersPerDegLon: 111_320.0 * max(0.2, cosLat0),
      maxRangeMeters: maxRange)
    return finished(
      vertices: vertices, field: blurred, width: raster.width, height: raster.height)
  }

  /// 0.5° azimuth slots × native range gates. Hole-fill lives in `contourLevel`.
  static func rasterizeField(sweep: Level3N0BSweep) -> (
    levels: [Float], width: Int, height: Int
  ) {
    let width = max(1, sweep.azIndex.count)
    let height = max(1, sweep.binCount)
    var levels = [Float](repeating: 0, count: width * height)
    for slot in 0..<width {
      let ri = sweep.azIndex[slot]
      if ri == 0xFFFF { continue }
      let radialIndex = Int(ri)
      guard radialIndex >= 0, radialIndex < sweep.radials.count else { continue }
      let count = min(sweep.radials[radialIndex].gates.count, height)
      for j in 0..<count {
        levels[j * width + slot] = sweep.contourLevel(
          radialIndex: radialIndex, gateIndex: j)
      }
    }
    return (levels, width, height)
  }

  /// Multi-pass wet-only box. Clear texels stay 0 so precip cannot dilate.
  static func blurWetOnly(
    _ levels: [Float], width: Int, height: Int,
    passes: Int = fieldBlurPasses, radius: Int = fieldBlurRadius
  ) -> [Float] {
    guard width > 2, height > 2, levels.count == width * height, passes > 0, radius > 0
    else { return levels }
    var src = levels
    var dst = [Float](repeating: 0, count: levels.count)
    for _ in 0..<passes {
      for y in 0..<height {
        let row = y * width
        for x in 0..<width {
          let idx = row + x
          let center = src[idx]
          if center <= 0 {
            dst[idx] = 0
            continue
          }
          var sum: Float = 0
          var n: Float = 0
          var dy = -radius
          while dy <= radius {
            let yy = y + dy
            if yy >= 0 && yy < height {
              let srcRow = yy * width
              var dx = -radius
              while dx <= radius {
                var xx = x + dx
                if xx >= width { xx -= width }
                if xx < 0 { xx += width }
                let v = src[srcRow + xx]
                if v > 0 {
                  sum += v
                  n += 1
                }
                dx += 1
              }
            }
            dy += 1
          }
          dst[idx] = n > 0 ? sum / n : 0
        }
      }
      swap(&src, &dst)
    }
    return src
  }

  /// Bilinear sample of the polar field (azimuth wraps, range clamps to 0).
  static func sampleField(
    _ levels: [Float], width: Int, height: Int,
    rangeMeters: Double, azimuth: Double, maxRangeMeters: Double
  ) -> Float {
    guard width > 0, height > 0, maxRangeMeters > 0,
      levels.count == width * height
    else { return 0 }
    if rangeMeters < 0 || rangeMeters >= maxRangeMeters { return 0 }
    var az = azimuth.truncatingRemainder(dividingBy: 360)
    if az < 0 { az += 360 }
    let u = az / 360 * Double(width) - 0.5
    let v = rangeMeters / maxRangeMeters * Double(height) - 0.5
    let x0 = Int(floor(u))
    let y0 = Int(floor(v))
    let tx = Float(u - Double(x0))
    let ty = Float(v - Double(y0))
    func at(_ x: Int, _ y: Int) -> Float {
      if y < 0 || y >= height { return 0 }
      var xx = x % width
      if xx < 0 { xx += width }
      return levels[y * width + xx]
    }
    let c00 = at(x0, y0)
    let c10 = at(x0 + 1, y0)
    let c01 = at(x0, y0 + 1)
    let c11 = at(x0 + 1, y0 + 1)
    return c00 * (1 - tx) * (1 - ty) + c10 * tx * (1 - ty) + c01 * (1 - tx) * ty
      + c11 * tx * ty
  }

  static func lutIndex(_ level: Float) -> Int {
    guard level.isFinite else { return 0 }
    return Int(min(255, max(0, level.rounded())))
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

  static func buildCoveringFan(
    lat0Deg: Double, lon0Deg: Double,
    metersPerDegLat: Double, metersPerDegLon: Double,
    maxRangeMeters: Double,
    wedges: Int = coveringWedges
  ) -> [Level3PolarVertex] {
    let n = max(8, wedges)
    var vertices: [Level3PolarVertex] = []
    vertices.reserveCapacity(n * 3)
    let origin = mercatorXY(latitude: lat0Deg, longitude: lon0Deg)
    let vCenter = Level3PolarVertex(
      mercX: Float(origin.x), mercY: Float(origin.y), level: 0)
    for i in 0..<n {
      let az0 = Double(i) / Double(n) * 2 * .pi
      let az1 = Double(i + 1) / Double(n) * 2 * .pi
      let p0 = destination(
        lat0Deg: lat0Deg, lon0Deg: lon0Deg,
        metersPerDegLat: metersPerDegLat, metersPerDegLon: metersPerDegLon,
        sinAz: sin(az0), cosAz: cos(az0), rangeMeters: maxRangeMeters)
      let p1 = destination(
        lat0Deg: lat0Deg, lon0Deg: lon0Deg,
        metersPerDegLat: metersPerDegLat, metersPerDegLon: metersPerDegLon,
        sinAz: sin(az1), cosAz: cos(az1), rangeMeters: maxRangeMeters)
      vertices.append(vCenter)
      vertices.append(vertex(p0, 0))
      vertices.append(vertex(p1, 0))
    }
    return vertices
  }

  private static func vertex(
    _ ll: (lat: Double, lon: Double),
    _ level: Float
  ) -> Level3PolarVertex {
    let m = mercatorXY(latitude: ll.lat, longitude: ll.lon)
    return Level3PolarVertex(mercX: Float(m.x), mercY: Float(m.y), level: level)
  }
}

/// Dual-volume opacity lerp between two polar fields.
/// Play fade is polar-specific and short so 2x does not dual-sample the
/// whole hold. Stills keep the IEM still duration. Volumes do not blend
/// dBZ — each field LUT-snaps on its own.
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

/// LRU cache of CPU polar fields keyed by site + volume time.
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
    radarLog("[Level3] polar field cache warm \(sweeps.count) frames gpu=\(Level3PolarGPUCache.shared.stats().count)")
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
