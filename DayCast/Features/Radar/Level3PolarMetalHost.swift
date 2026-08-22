import Foundation
import MapboxMaps
import Metal
import simd
import UIKit

/// Mapbox `CustomLayerHost` that draws Level III N0B gates as Metal trapezoids.
/// Dual GPU meshes crossfade between volumes (same duration as live IEM raster).
/// Raster PNG nearest-sample stays the fallback when this pipeline cannot start
/// or no sweep is loaded.
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

    Task.detached(priority: .userInitiated) {
      let cacheHit = Level3PolarMeshCache.shared.cached(
        site: sweep.siteID, timestamp: sweep.timestamp) != nil
      let mesh = Level3PolarMeshCache.shared.mesh(for: sweep)
      let tUpload = CFAbsoluteTimeGetCurrent()
      let gpu: GPUMesh
      if let device {
        gpu = Self.makeGPUMesh(mesh: mesh, key: key, device: device)
      } else {
        gpu = GPUMesh(key: key, buffer: nil, vertexCount: 0, pendingCPU: mesh)
      }
      let uploadMs = (CFAbsoluteTimeGetCurrent() - tUpload) * 1000
      await MainActor.run {
        self.lock.lock()
        let stillCurrent = self.generation == gen
        self.lock.unlock()
        guard stillCurrent else { return }
        self.adopt(gpu: gpu, fadeDuration: fadeSeconds)
        let buildMs = cacheHit ? 0 : mesh.buildMilliseconds
        radarLog(
          "[Level3] polar adopt \(key) cache=\(cacheHit ? "hit" : "miss") build=\(Int(buildMs.rounded()))ms upload=\(Int(uploadMs.rounded()))ms tris=\(mesh.triangleCount) fade=\(Int((fadeSeconds * 1000).rounded()))ms"
        )
        onReady()
      }
    }
  }

  private func adopt(gpu: GPUMesh, fadeDuration: TimeInterval) {
    lock.lock()
    currentKey = gpu.key
    let hasFront = front.vertexCount > 0 || (pendingCPU?.vertices.isEmpty == false)
    let fading = fadeStart != nil
    if fading {
      queuedGPU = gpu
      queuedFade = fadeDuration
      lock.unlock()
      return
    }
    if !hasFront || fadeDuration <= 0 {
      applyImmediateLocked(gpu)
      lock.unlock()
      fadeTask?.cancel()
      fadeTask = nil
      return
    }
    installIncomingLocked(gpu, duration: fadeDuration)
    lock.unlock()
    startFadePump()
  }

  private func applyImmediateLocked(_ gpu: GPUMesh) {
    if let cpu = gpu.pendingCPU {
      pendingCPU = cpu
      pendingCPUIsIncoming = false
      front = GPUMesh(key: gpu.key, buffer: nil, vertexCount: 0, pendingCPU: nil)
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
      back = GPUMesh(key: gpu.key, buffer: nil, vertexCount: 0, pendingCPU: nil)
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
    fadeTask = Task { @MainActor [weak self] in
      while let self, !Task.isCancelled {
        guard let clock = self.copyFadeClock() else { break }
        let t = Level3PolarCrossfade.progress(
          elapsed: CFAbsoluteTimeGetCurrent() - clock.start, duration: clock.duration)
        self.onNeedsDisplay?()
        if t >= 1 {
          self.finishFade()
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
      desc.attributes[1].format = .uchar4
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
      let gpu = Self.makeGPUMesh(mesh: pending, key: frontMesh.key, device: metalDevice)
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
    let t: Float
    if let fadeStart, fadeDuration > 0 {
      t = Level3PolarCrossfade.progress(
        elapsed: CFAbsoluteTimeGetCurrent() - fadeStart, duration: fadeDuration)
    } else {
      t = 1
    }
    let ops = Level3PolarCrossfade.layerOpacities(progress: t, global: opacity)
    let drawFront = frontMesh.vertexCount > 0 && ops.outgoing > 0.001
    let drawBack = backMesh.vertexCount > 0 && ops.incoming > 0.001
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
        matrix: matrix, worldSize: worldSize, opacity: ops.outgoing)
    }
    if drawBack, let buffer = backMesh.buffer {
      Self.draw(
        encoder: encoder, buffer: buffer, count: backMesh.vertexCount,
        matrix: matrix, worldSize: worldSize, opacity: ops.incoming)
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
  }

  private static func draw(
    encoder: MTLRenderCommandEncoder,
    buffer: MTLBuffer,
    count: Int,
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
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: count)
  }

  private static func makeGPUMesh(
    mesh: Level3PolarGateMesh.Mesh, key: String, device: MTLDevice
  ) -> GPUMesh {
    if mesh.vertices.isEmpty {
      return GPUMesh(key: key, buffer: nil, vertexCount: 0, pendingCPU: nil)
    }
    let bytes = mesh.vertices.count * MemoryLayout<Level3PolarVertex>.stride
    let buffer = mesh.vertices.withUnsafeBufferPointer { ptr in
      device.makeBuffer(bytes: ptr.baseAddress!, length: bytes, options: .storageModeShared)
    }
    return GPUMesh(key: key, buffer: buffer, vertexCount: mesh.vertices.count, pendingCPU: nil)
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

private struct GPUMesh {
  var key: String
  var buffer: MTLBuffer?
  var vertexCount: Int
  var pendingCPU: Level3PolarGateMesh.Mesh?

  static let empty = GPUMesh(key: "", buffer: nil, vertexCount: 0, pendingCPU: nil)
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
