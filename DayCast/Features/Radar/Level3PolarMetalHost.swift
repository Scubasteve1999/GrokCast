import Foundation
import MapboxMaps
import Metal
import simd
import UIKit

/// Mapbox `CustomLayerHost` that draws Level III N0B as Metal polar quads.
/// Vertices carry interpolatable data-byte levels; the fragment shader LUT-snaps
/// to hard NWS 5 dBZ fills so cells contour instead of Lego gates. Dual GPU
/// meshes still crossfade by opacity only (no dBZ blend). Raster PNG nearest
/// sample stays the fallback when this pipeline cannot start or no sweep is loaded.
final class Level3PolarMetalHost: NSObject, CustomLayerHost, @unchecked Sendable {
  static let layerID = "daycast-level3-polar"

  var onNeedsDisplay: (() -> Void)?

  private let lock = NSLock()
  private var metalDevice: MTLDevice?
  private var pipelineState: MTLRenderPipelineState?
  private var depthStencilState: MTLDepthStencilState?
  private var front = GPUMesh.empty
  private var back = GPUMesh.empty
  private var pendingCPU: Level3PolarGateMesh.Mesh?
  private var pendingCPUIsIncoming = false
  private var opacity: Float = 1
  private var currentKey: String?
  private var generation: UInt64 = 0
  private var fadeStart: CFAbsoluteTime?
  private var fadeDuration: TimeInterval = 0
  private var queuedGPU: GPUMesh?
  private var queuedFade: TimeInterval = 0
  private var fadeTask: Task<Void, Never>?

  /// Shader / pipeline setup failed — representable must keep IEM/CPU tiles.
  private(set) var pipelineFailed = false

  /// True once a non-empty trapezoid mesh is waiting or on the GPU.
  var hasDrawableMesh: Bool {
    lock.lock()
    defer { lock.unlock() }
    if let pendingCPU, !pendingCPU.vertices.isEmpty { return true }
    return front.vertexCount > 0 || back.vertexCount > 0
  }

  func setSweep(
    _ sweep: Level3N0BSweep?,
    opacity: Float,
    isAnimating: Bool,
    onReady: @escaping () -> Void
  ) {
    lock.lock()
    self.opacity = opacity
    lock.unlock()

    guard let sweep else {
      lock.lock()
      let wasActive =
        currentKey != nil || front.vertexCount > 0 || back.vertexCount > 0
        || (pendingCPU?.vertices.isEmpty == false)
      generation += 1
      currentKey = nil
      pendingCPU = nil
      front = .empty
      back = .empty
      queuedGPU = nil
      fadeStart = nil
      fadeDuration = 0
      lock.unlock()
      fadeTask?.cancel()
      fadeTask = nil
      if wasActive { onReady() }
      return
    }

    let key = Level3N0BSweepStore.exactKey(site: sweep.siteID, timestamp: sweep.timestamp)
    lock.lock()
    let already = currentKey == key
    lock.unlock()
    if already { return }

    let fadeSeconds = Level3PolarCrossfade.durationSeconds(isAnimating: isAnimating)
    lock.lock()
    generation += 1
    currentKey = key
    let gen = generation
    let device = metalDevice
    lock.unlock()

    let t0 = CFAbsoluteTimeGetCurrent()
    if let gpu = Level3PolarGPUCache.shared.cachedGPUMesh(key: key) {
      let queued = adopt(gpu: gpu, fadeDuration: fadeSeconds)
      let hitchMs = (CFAbsoluteTimeGetCurrent() - t0) * 1000
      let tris = gpu.vertexCount / 3
      Level3PolarPlayStats.recordAdopt(
        hitchMs: hitchMs,
        fadeMs: fadeSeconds * 1000,
        gpuHit: true,
        cacheHit: true,
        uploadMs: 0,
        tris: tris,
        queued: queued)
      radarLog(
        "[Level3] polar adopt \(key) cache=hit build=0ms upload=0ms tris=\(tris) fade=\(Int((fadeSeconds * 1000).rounded()))ms gpu=hit queued=\(queued) hitch=\(Int(hitchMs.rounded()))ms"
      )
      onReady()
      return
    }

    Task.detached(priority: .userInitiated) {
      let cacheHit = Level3PolarMeshCache.shared.cached(
        site: sweep.siteID, timestamp: sweep.timestamp) != nil
      let mesh = Level3PolarMeshCache.shared.mesh(for: sweep)
      let tUpload = CFAbsoluteTimeGetCurrent()
      let gpu: GPUMesh
      if let device {
        gpu = Level3PolarGPUCache.shared.gpuMesh(key: key, cpu: mesh, device: device)
      } else {
        gpu = GPUMesh(
          key: key, buffer: nil, vertexCount: 0, pendingCPU: mesh, lut: mesh.lut)
      }
      let uploadMs = (CFAbsoluteTimeGetCurrent() - tUpload) * 1000
      await MainActor.run {
        self.lock.lock()
        let stillCurrent = self.generation == gen
        self.lock.unlock()
        guard stillCurrent else { return }
        let queued = self.adopt(gpu: gpu, fadeDuration: fadeSeconds)
        let buildMs = cacheHit ? 0 : mesh.buildMilliseconds
        Level3PolarPlayStats.recordAdopt(
          hitchMs: (CFAbsoluteTimeGetCurrent() - t0) * 1000,
          fadeMs: fadeSeconds * 1000,
          gpuHit: gpu.buffer != nil,
          cacheHit: cacheHit,
          uploadMs: uploadMs,
          tris: mesh.triangleCount,
          queued: queued)
        radarLog(
          "[Level3] polar adopt \(key) cache=\(cacheHit ? "hit" : "miss") build=\(Int(buildMs.rounded()))ms upload=\(Int(uploadMs.rounded()))ms tris=\(mesh.triangleCount) fade=\(Int((fadeSeconds * 1000).rounded()))ms gpu=\(gpu.buffer != nil ? "ready" : "pending") queued=\(queued) hitch=\(Int(((CFAbsoluteTimeGetCurrent() - t0) * 1000).rounded()))ms"
        )
        onReady()
      }
    }
  }

  @discardableResult
  private func adopt(gpu: GPUMesh, fadeDuration: TimeInterval) -> Bool {
    lock.lock()
    currentKey = gpu.key
    let hasFront = front.vertexCount > 0 || (pendingCPU?.vertices.isEmpty == false)
    let fading = fadeStart != nil
    if fading {
      queuedGPU = gpu
      queuedFade = fadeDuration
      lock.unlock()
      return true
    }
    if !hasFront || fadeDuration <= 0 {
      applyImmediateLocked(gpu)
      lock.unlock()
      fadeTask?.cancel()
      fadeTask = nil
      return false
    }
    installIncomingLocked(gpu, duration: fadeDuration)
    lock.unlock()
    startFadePump()
    return false
  }

  private func applyImmediateLocked(_ gpu: GPUMesh) {
    if let cpu = gpu.pendingCPU {
      pendingCPU = cpu
      pendingCPUIsIncoming = false
      front = GPUMesh(
        key: gpu.key, buffer: nil, vertexCount: 0, pendingCPU: nil, lut: gpu.lut)
      back = .empty
    } else {
      pendingCPU = nil
      front = gpu
      back = .empty
    }
    queuedGPU = nil
    fadeStart = nil
    fadeDuration = 0
  }

  private func installIncomingLocked(_ gpu: GPUMesh, duration: TimeInterval) {
    if let cpu = gpu.pendingCPU {
      pendingCPU = cpu
      pendingCPUIsIncoming = true
      back = GPUMesh(
        key: gpu.key, buffer: nil, vertexCount: 0, pendingCPU: nil, lut: gpu.lut)
    } else {
      back = gpu
    }
    fadeStart = CFAbsoluteTimeGetCurrent()
    fadeDuration = duration
    queuedGPU = nil
  }

  private func copyFadeClock() -> (start: CFAbsoluteTime, duration: TimeInterval)? {
    lock.lock()
    defer { lock.unlock() }
    guard let fadeStart, fadeDuration > 0 else { return nil }
    return (fadeStart, fadeDuration)
  }

  private func startFadePump() {
    fadeTask?.cancel()
    fadeTask = Task { [weak self] in
      while let self, !Task.isCancelled {
        guard let clock = self.copyFadeClock() else { break }
        let t = Level3PolarCrossfade.progress(
          elapsed: CFAbsoluteTimeGetCurrent() - clock.start, duration: clock.duration)
        await MainActor.run { self.onNeedsDisplay?() }
        if t >= 1 {
          await MainActor.run { self.finishFade() }
          break
        }
        try? await Task.sleep(nanoseconds: 16_666_667)
      }
    }
  }

  private func finishFade() {
    lock.lock()
    if back.vertexCount > 0 {
      front = back
      pendingCPU = nil
    }
    pendingCPUIsIncoming = false
    back = .empty
    fadeStart = nil
    fadeDuration = 0
    let queued = queuedGPU
    let queuedFade = self.queuedFade
    queuedGPU = nil
    self.queuedFade = 0
    lock.unlock()
    if let queued {
      adopt(gpu: queued, fadeDuration: queuedFade)
      onNeedsDisplay?()
    } else {
      fadeTask = nil
      onNeedsDisplay?()
    }
  }

  func renderingWillStart(
    _ metalDevice: MTLDevice,
    colorPixelFormat: UInt,
    depthStencilPixelFormat: UInt
  ) {
    self.metalDevice = metalDevice
    do {
      let library: MTLLibrary
      if let bundled = try? metalDevice.makeDefaultLibrary(bundle: Bundle(for: Level3PolarMetalHost.self)) {
        library = bundled
      } else if let def = metalDevice.makeDefaultLibrary() {
        library = def
      } else {
        throw PipelineError.noLibrary
      }
      guard let vertex = library.makeFunction(name: "level3PolarVertex"),
        let fragment = library.makeFunction(name: "level3PolarFragment")
      else {
        throw PipelineError.noFunction
      }

      let desc = MTLVertexDescriptor()
      desc.attributes[0].format = .float2
      desc.attributes[0].offset = 0
      desc.attributes[0].bufferIndex = 0
      desc.attributes[1].format = .float
      desc.attributes[1].offset = 8
      desc.attributes[1].bufferIndex = 0
      desc.layouts[0].stride = MemoryLayout<Level3PolarVertex>.stride
      desc.layouts[0].stepFunction = .perVertex
      desc.layouts[0].stepRate = 1

      let pipe = MTLRenderPipelineDescriptor()
      pipe.label = "DayCast Level III polar"
      pipe.vertexFunction = vertex
      pipe.fragmentFunction = fragment
      pipe.vertexDescriptor = desc
      pipe.colorAttachments[0].pixelFormat = MTLPixelFormat(rawValue: colorPixelFormat)!
      pipe.colorAttachments[0].isBlendingEnabled = true
      pipe.colorAttachments[0].rgbBlendOperation = .add
      pipe.colorAttachments[0].alphaBlendOperation = .add
      pipe.colorAttachments[0].sourceRGBBlendFactor = .one
      pipe.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
      pipe.colorAttachments[0].sourceAlphaBlendFactor = .one
      pipe.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
      let depthFormat = MTLPixelFormat(rawValue: depthStencilPixelFormat)!
      pipe.depthAttachmentPixelFormat = depthFormat
      pipe.stencilAttachmentPixelFormat = depthFormat

      pipelineState = try metalDevice.makeRenderPipelineState(descriptor: pipe)

      let depth = MTLDepthStencilDescriptor()
      depth.isDepthWriteEnabled = false
      depth.depthCompareFunction = .always
      depthStencilState = metalDevice.makeDepthStencilState(descriptor: depth)
      pipelineFailed = false
      Level3PolarGPUCache.shared.bindDevice(metalDevice)
      Task.detached(priority: .userInitiated) {
        Level3PolarGPUCache.shared.prefetchCachedCPUMeshes()
      }
    } catch {
      pipelineFailed = true
      radarLog("[Level3] polar Metal pipeline failed: \(error)")
    }
  }

  func render(
    _ parameters: CustomLayerRenderParameters,
    mtlCommandBuffer: MTLCommandBuffer,
    mtlRenderPassDescriptor: MTLRenderPassDescriptor
  ) {
    lock.lock()
    var frontMesh = front
    var backMesh = back
    let pending = pendingCPU
    pendingCPU = nil
    let pendingIncoming = pendingCPUIsIncoming
    let opacity = self.opacity
    let failed = pipelineFailed
    let fadeStart = self.fadeStart
    let fadeDuration = self.fadeDuration
    lock.unlock()

    if let pending, let metalDevice {
      let pendingKey = pendingIncoming ? backMesh.key : frontMesh.key
      let gpu = Level3PolarGPUCache.shared.gpuMesh(
        key: pendingKey.isEmpty ? currentKeyForPending() : pendingKey,
        cpu: pending,
        device: metalDevice)
      if pendingIncoming {
        backMesh = gpu
      } else {
        frontMesh = gpu
      }
      lock.lock()
      if pendingIncoming {
        self.back = gpu
      } else {
        self.front = gpu
      }
      lock.unlock()
    }

    guard !failed, let pipelineState else { return }
    let fading: Bool
    let t: Float
    if let fadeStart, fadeDuration > 0 {
      t = Level3PolarCrossfade.progress(
        elapsed: CFAbsoluteTimeGetCurrent() - fadeStart, duration: fadeDuration)
      fading = t < 1 && backMesh.vertexCount > 0
    } else {
      t = 1
      fading = false
    }
    let ops = Level3PolarCrossfade.drawOpacities(
      progress: t, global: opacity, isFading: fading)
    let drawFront = frontMesh.vertexCount > 0 && ops.front > 0.001
    let drawBack = backMesh.vertexCount > 0 && ops.back > 0.001
    Level3PolarPlayStats.recordDraw(
      dual: drawFront && drawBack,
      frontTris: frontMesh.vertexCount / 3,
      backTris: backMesh.vertexCount / 3)
    guard drawFront || drawBack else { return }
    guard let encoder = mtlCommandBuffer.makeRenderCommandEncoder(descriptor: mtlRenderPassDescriptor)
    else { return }

    let scale = Double(UIScreen.main.scale)
    encoder.label = "DayCast Level III polar"
    encoder.setViewport(
      MTLViewport(
        originX: 0, originY: 0,
        width: parameters.width * scale,
        height: parameters.height * scale,
        znear: 0, zfar: 1))
    encoder.setCullMode(.none)
    encoder.setRenderPipelineState(pipelineState)
    if let depthStencilState {
      encoder.setDepthStencilState(depthStencilState)
    }

    let worldSize = Float(Projection.worldSize(scale: pow(2, parameters.zoom)))
    let matrix = Self.mvpMatrix(parameters: parameters)
    if drawFront, let buffer = frontMesh.buffer {
      Self.draw(
        encoder: encoder, buffer: buffer, count: frontMesh.vertexCount,
        lut: frontMesh.lut,
        matrix: matrix, worldSize: worldSize, opacity: ops.front)
    }
    if drawBack, let buffer = backMesh.buffer {
      Self.draw(
        encoder: encoder, buffer: buffer, count: backMesh.vertexCount,
        lut: backMesh.lut,
        matrix: matrix, worldSize: worldSize, opacity: ops.back)
    }
    encoder.endEncoding()
  }

  func renderingWillEnd() {
    fadeTask?.cancel()
    fadeTask = nil
    lock.lock()
    pipelineState = nil
    depthStencilState = nil
    front = .empty
    back = .empty
    pendingCPU = nil
    queuedGPU = nil
    fadeStart = nil
    metalDevice = nil
    lock.unlock()
    Level3PolarGPUCache.shared.unbind()
  }

  private func currentKeyForPending() -> String {
    lock.lock()
    defer { lock.unlock() }
    return currentKey ?? ""
  }

  private static func draw(
    encoder: MTLRenderCommandEncoder,
    buffer: MTLBuffer,
    count: Int,
    lut: [UInt8],
    matrix: simd_float4x4,
    worldSize: Float,
    opacity: Float
  ) {
    var uniforms = Level3PolarUniforms(
      matrix: matrix,
      worldSize: worldSize,
      opacity: opacity)
    encoder.setVertexBuffer(buffer, offset: 0, index: 0)
    encoder.setVertexBytes(&uniforms, length: MemoryLayout<Level3PolarUniforms>.stride, index: 1)
    encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Level3PolarUniforms>.stride, index: 1)
    var lutBytes = lut
    if lutBytes.count < 256 * 4 {
      lutBytes.append(contentsOf: repeatElement(UInt8(0), count: 256 * 4 - lutBytes.count))
    }
    lutBytes.withUnsafeBytes { raw in
      encoder.setFragmentBytes(raw.baseAddress!, length: 256 * 4, index: 2)
    }
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: count)
  }

  private static func mvpMatrix(parameters: CustomLayerRenderParameters) -> simd_float4x4 {
    let projection = parameters.projectionMatrix.level3SimdFloat4x4
    let transition = parameters.projection.getTransitionMatrix().level3SimdFloat4x4
    return projection * transition
  }

  private enum PipelineError: Error {
    case noLibrary
    case noFunction
  }
}

fileprivate struct GPUMesh {
  var key: String
  var buffer: MTLBuffer?
  var vertexCount: Int
  var pendingCPU: Level3PolarGateMesh.Mesh?
  var lut: [UInt8]

  static let empty = GPUMesh(
    key: "", buffer: nil, vertexCount: 0, pendingCPU: nil, lut: [])
}

/// Whole-loop GPU vertex buffers so Play adopt is a pointer swap, not `makeBuffer`.
final class Level3PolarGPUCache: @unchecked Sendable {
  static let shared = Level3PolarGPUCache()

  private struct Entry {
    var buffer: MTLBuffer?
    var vertexCount: Int
    var lut: [UInt8]
  }

  private let lock = NSLock()
  private var device: MTLDevice?
  private var byKey: [String: Entry] = [:]
  private var hitCount = 0
  private var missCount = 0

  private init() {}

  func bindDevice(_ device: MTLDevice) {
    lock.lock()
    if self.device !== device {
      byKey.removeAll(keepingCapacity: true)
      self.device = device
    }
    lock.unlock()
  }

  func unbind() {
    lock.lock()
    device = nil
    byKey.removeAll(keepingCapacity: true)
    hitCount = 0
    missCount = 0
    lock.unlock()
  }

  fileprivate func cachedGPUMesh(key: String) -> GPUMesh? {
    lock.lock()
    defer { lock.unlock() }
    guard let hit = byKey[key] else { return nil }
    hitCount += 1
    return GPUMesh(
      key: key, buffer: hit.buffer, vertexCount: hit.vertexCount, pendingCPU: nil, lut: hit.lut)
  }

  fileprivate func gpuMesh(key: String, cpu: Level3PolarGateMesh.Mesh, device: MTLDevice) -> GPUMesh {
    lock.lock()
    if let hit = byKey[key] {
      hitCount += 1
      lock.unlock()
      return GPUMesh(
        key: key, buffer: hit.buffer, vertexCount: hit.vertexCount, pendingCPU: nil, lut: hit.lut)
    }
    lock.unlock()
    let made = Self.makeBuffer(mesh: cpu, device: device)
    lock.lock()
    if let raced = byKey[key] {
      lock.unlock()
      return GPUMesh(
        key: key, buffer: raced.buffer, vertexCount: raced.vertexCount, pendingCPU: nil, lut: raced.lut)
    }
    byKey[key] = Entry(buffer: made.buffer, vertexCount: made.count, lut: cpu.lut)
    missCount += 1
    lock.unlock()
    return GPUMesh(
      key: key, buffer: made.buffer, vertexCount: made.count, pendingCPU: nil, lut: cpu.lut)
  }

  func ingest(key: String, mesh: Level3PolarGateMesh.Mesh) {
    lock.lock()
    let device = self.device
    if byKey[key] != nil || device == nil {
      lock.unlock()
      return
    }
    lock.unlock()
    guard let device else { return }
    _ = gpuMesh(key: key, cpu: mesh, device: device)
  }

  func prefetchCachedCPUMeshes() {
    lock.lock()
    let device = self.device
    lock.unlock()
    guard device != nil else { return }
    for (key, mesh) in Level3PolarMeshCache.shared.snapshot() {
      ingest(key: key, mesh: mesh)
    }
    let n = stats().count
    if n > 0 {
      radarLog("[Level3] polar GPU cache ready \(n) buffers")
    }
  }

  func keepOnly(keys: Set<String>) {
    lock.lock()
    byKey = byKey.filter { keys.contains($0.key) }
    lock.unlock()
  }

  func removeAll() {
    lock.lock()
    byKey.removeAll(keepingCapacity: true)
    hitCount = 0
    missCount = 0
    lock.unlock()
  }

  func stats() -> (count: Int, hits: Int, misses: Int) {
    lock.lock()
    defer { lock.unlock() }
    return (byKey.count, hitCount, missCount)
  }

  private static func makeBuffer(mesh: Level3PolarGateMesh.Mesh, device: MTLDevice)
    -> (buffer: MTLBuffer?, count: Int)
  {
    if mesh.vertices.isEmpty { return (nil, 0) }
    let bytes = mesh.vertices.count * MemoryLayout<Level3PolarVertex>.stride
    let buffer = mesh.vertices.withUnsafeBufferPointer { ptr in
      device.makeBuffer(bytes: ptr.baseAddress!, length: bytes, options: .storageModeShared)
    }
    return (buffer, mesh.vertices.count)
  }
}

enum Level3PolarPlayStats {
  private static let lock = NSLock()
  private static var hitches: [Double] = []
  private static var uploads: [Double] = []
  private static var gpuHits = 0
  private static var cacheHits = 0
  private static var queuedAdopts = 0
  private static var dualDraws = 0
  private static var settledDraws = 0
  private static var lastDualLog = CFAbsoluteTimeGetCurrent() - 10

  static func reset() {
    lock.lock()
    hitches.removeAll()
    uploads.removeAll()
    gpuHits = 0
    cacheHits = 0
    queuedAdopts = 0
    dualDraws = 0
    settledDraws = 0
    lock.unlock()
  }

  static func recordAdopt(
    hitchMs: Double,
    fadeMs: Double,
    gpuHit: Bool,
    cacheHit: Bool,
    uploadMs: Double,
    tris: Int,
    queued: Bool
  ) {
    lock.lock()
    hitches.append(hitchMs)
    uploads.append(uploadMs)
    if gpuHit { gpuHits += 1 }
    if cacheHit { cacheHits += 1 }
    if queued { queuedAdopts += 1 }
    let n = hitches.count
    let shouldLog = n == 1 || n == 5 || n % 10 == 0
    let p50 = percentileLocked(hitches, 0.5)
    let p95 = percentileLocked(hitches, 0.95)
    let gpu = gpuHits
    let cache = cacheHits
    let queuedN = queuedAdopts
    let dual = dualDraws
    let settled = settledDraws
    lock.unlock()
    guard shouldLog else { return }
    let overlap = dual + settled > 0 ? Int((Double(dual) / Double(dual + settled) * 100).rounded()) : 0
    radarLog(
      "[Level3] polar hitch n=\(n) p50=\(Int(p50.rounded()))ms p95=\(Int(p95.rounded()))ms gpu=\(gpu)/\(n) cache=\(cache)/\(n) queued=\(queuedN) fade=\(Int(fadeMs.rounded()))ms tris=\(tris) dual=\(overlap)%"
    )
  }

  static func recordDraw(dual: Bool, frontTris: Int, backTris: Int) {
    lock.lock()
    if dual {
      dualDraws += 1
    } else {
      settledDraws += 1
    }
    let now = CFAbsoluteTimeGetCurrent()
    let shouldLog = dual && now - lastDualLog > 1
    if shouldLog { lastDualLog = now }
    let dualN = dualDraws
    let settledN = settledDraws
    lock.unlock()
    if shouldLog {
      radarLog(
        "[Level3] polar dual-draw tris=\(frontTris + backTris) (front=\(frontTris) back=\(backTris)) dualFrames=\(dualN) settled=\(settledN)"
      )
    }
  }

  private static func percentileLocked(_ values: [Double], _ p: Double) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let idx = min(sorted.count - 1, max(0, Int((Double(sorted.count - 1) * p).rounded())))
    return sorted[idx]
  }
}

private struct Level3PolarUniforms {
  var matrix: simd_float4x4
  var worldSize: Float
  var opacity: Float
  var pad0: Float = 0
  var pad1: Float = 0
}

extension Array where Element == NSNumber {
  fileprivate var level3SimdFloat4x4: simd_float4x4 {
    simd_float4x4([
      simd_float4(self[0].floatValue, self[1].floatValue, self[2].floatValue, self[3].floatValue),
      simd_float4(self[4].floatValue, self[5].floatValue, self[6].floatValue, self[7].floatValue),
      simd_float4(self[8].floatValue, self[9].floatValue, self[10].floatValue, self[11].floatValue),
      simd_float4(self[12].floatValue, self[13].floatValue, self[14].floatValue, self[15].floatValue),
    ])
  }
}
