import Foundation
import MapboxMaps
import Metal
import simd
import UIKit

/// Mapbox `CustomLayerHost` that draws Level III N0B gates as Metal trapezoids.
/// Raster PNG nearest-sample stays the fallback when this pipeline cannot start
/// or no sweep is loaded.
final class Level3PolarMetalHost: NSObject, CustomLayerHost, @unchecked Sendable {
  static let layerID = "daycast-level3-polar"

  private let lock = NSLock()
  private var metalDevice: MTLDevice?
  private var pipelineState: MTLRenderPipelineState?
  private var depthStencilState: MTLDepthStencilState?
  private var vertexBuffer: MTLBuffer?
  private var vertexCount = 0
  private var pendingMesh: Level3PolarGateMesh.Mesh?
  private var opacity: Float = 1
  private var currentKey: String?
  private var generation: UInt64 = 0
  private var lastLoggedKey: String?

  /// Shader / pipeline setup failed — representable must keep IEM/CPU tiles.
  private(set) var pipelineFailed = false

  /// True once a non-empty trapezoid mesh is waiting or on the GPU.
  var hasDrawableMesh: Bool {
    lock.lock()
    defer { lock.unlock() }
    if let pendingMesh, !pendingMesh.vertices.isEmpty { return true }
    return vertexCount > 0
  }

  func setSweep(
    _ sweep: Level3N0BSweep?,
    opacity: Float,
    onReady: @escaping () -> Void
  ) {
    lock.lock()
    self.opacity = opacity
    lock.unlock()

    guard let sweep else {
      lock.lock()
      let wasActive =
        currentKey != nil || vertexCount > 0
        || (pendingMesh?.vertices.isEmpty == false)
      generation += 1
      currentKey = nil
      pendingMesh = Level3PolarGateMesh.Mesh(vertices: [], buildMilliseconds: 0)
      vertexCount = 0
      vertexBuffer = nil
      lock.unlock()
      if wasActive { onReady() }
      return
    }

    let key = Level3N0BSweepStore.exactKey(site: sweep.siteID, timestamp: sweep.timestamp)
    lock.lock()
    let already = currentKey == key
    lock.unlock()
    if already { return }

    if let cached = Level3PolarMeshCache.shared.cached(
      site: sweep.siteID, timestamp: sweep.timestamp)
    {
      adopt(mesh: cached, key: key)
      onReady()
      return
    }

    lock.lock()
    generation += 1
    currentKey = key
    let gen = generation
    lock.unlock()

    Task.detached(priority: .userInitiated) {
      let mesh = Level3PolarMeshCache.shared.mesh(for: sweep)
      await MainActor.run {
        self.lock.lock()
        let stillCurrent = self.generation == gen
        self.lock.unlock()
        guard stillCurrent else { return }
        self.adopt(mesh: mesh, key: key)
        onReady()
      }
    }
  }

  private func adopt(mesh: Level3PolarGateMesh.Mesh, key: String) {
    lock.lock()
    currentKey = key
    pendingMesh = mesh
    let shouldLog = lastLoggedKey != key
    if shouldLog { lastLoggedKey = key }
    lock.unlock()
    if shouldLog {
      radarLog(
        "[Level3] polar Metal mesh \(key) \(mesh.triangleCount) tris in \(Int(mesh.buildMilliseconds.rounded()))ms"
      )
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
    let pending = pendingMesh
    pendingMesh = nil
    var count = vertexCount
    var buffer = vertexBuffer
    let opacity = self.opacity
    let failed = pipelineFailed
    lock.unlock()

    if let pending, let metalDevice {
      if pending.vertices.isEmpty {
        buffer = nil
        count = 0
      } else {
        let bytes = pending.vertices.count * MemoryLayout<Level3PolarVertex>.stride
        buffer = metalDevice.makeBuffer(bytes: pending.vertices, length: bytes, options: [])
        count = pending.vertices.count
      }
      lock.lock()
      vertexBuffer = buffer
      vertexCount = count
      lock.unlock()
    }

    guard !failed, count > 0, let buffer, let pipelineState else { return }
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
    var uniforms = Level3PolarUniforms(
      matrix: Self.mvpMatrix(parameters: parameters),
      worldSize: worldSize,
      opacity: opacity)
    encoder.setVertexBuffer(buffer, offset: 0, index: 0)
    encoder.setVertexBytes(&uniforms, length: MemoryLayout<Level3PolarUniforms>.stride, index: 1)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: count)
    encoder.endEncoding()
  }

  func renderingWillEnd() {
    lock.lock()
    pipelineState = nil
    depthStencilState = nil
    vertexBuffer = nil
    vertexCount = 0
    metalDevice = nil
    lock.unlock()
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
