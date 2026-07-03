import CoreLocation
import MapboxMaps
import SwiftUI
import UIKit

struct RadarMapboxRepresentable: UIViewRepresentable {
  @Bindable var radarState: RadarState
  var opacity: Double
  var defaultMapCenter: CLLocationCoordinate2D
  var recenterDefaultTrigger: UUID?
  var recenterUserCoordinate: CLLocationCoordinate2D?

  func makeUIView(context: Context) -> MapView {
    if let token = DeveloperAPIKey.mapbox, !token.isEmpty {
      MapboxOptions.accessToken = token
    }

    let scale = MapViewHostingSanitizer.screenScale
    let options = MapInitOptions(
      mapOptions: MapOptions(pixelRatio: CGFloat(scale)),
      styleURI: radarState.baseMapStyle.styleURI
    )
    let mapView = MapView(
      frame: MapViewHostingSanitizer.initialFrame,
      mapInitOptions: options
    )
    MapViewHostingSanitizer.prepareNewMapView(mapView)
    MapViewHostingSanitizer.scheduleDeferredSanitize(for: mapView)

    context.coordinator.setupMap(mapView)
    return mapView
  }

  func updateUIView(_ uiView: MapView, context: Context) {
    context.coordinator.update(
      mapView: uiView,
      radarState: radarState,
      opacity: opacity,
      defaultMapCenter: defaultMapCenter,
      recenterDefaultTrigger: recenterDefaultTrigger,
      recenterUserCoordinate: recenterUserCoordinate
    )
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  private enum MapViewHostingSanitizer {
    static let initialFrame = CGRect(x: 0, y: 0, width: 1200, height: 900)
    static let minimumBoundsFallback = CGRect(x: 0, y: 0, width: 400, height: 400)

    static var screenScale: Double {
      max(1.0, Double(UIScreen.main.scale))
    }

    static func prepareNewMapView(_ mapView: MapView) {
      let scale = screenScale
      if mapView.contentScaleFactor.isNaN || mapView.contentScaleFactor <= 0 {
        mapView.contentScaleFactor = scale
      }
      mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight] as UIView.AutoresizingMask
      mapView.frame = initialFrame
      mapView.setNeedsLayout()
      mapView.layoutIfNeeded()
    }

    static func scheduleDeferredSanitize(for mapView: MapView) {
      DispatchQueue.main.async { [weak mapView] in
        guard let mapView else { return }
        sanitize(mapView)
      }
    }

    static func sanitize(_ mapView: MapView) {
      let scale = screenScale

      if mapView.contentScaleFactor.isNaN || mapView.contentScaleFactor <= 0 {
        mapView.contentScaleFactor = scale
      }

      if mapView.bounds.width < 10 || mapView.bounds.height < 10 {
        if mapView.frame.width < 10 || mapView.frame.height < 10 {
          mapView.frame = minimumBoundsFallback
        }
        mapView.setNeedsLayout()
        mapView.layoutIfNeeded()
      }
    }
  }

  @MainActor
  final class Coordinator {
    private enum BufferSlot: String {
      case a
      case b

      var sourceId: String { "radar-\(rawValue)" }
      var layerId: String { "radar-layer-\(rawValue)" }

      var opposite: BufferSlot {
        switch self {
        case .a: .b
        case .b: .a
        }
      }
    }

    private var cancelables = Set<AnyCancelable>()
    private var hasAppliedInitialCenter = false
    private var lastRecenterDefaultTrigger: UUID?
    private var lastRecenterUserCoordinate: CLLocationCoordinate2D?

    private var layersInstalled = false
    private var frontSlot: BufferSlot = .a
    /// Tile key currently visible on `frontSlot`.
    private var displayedFrontKey: String?
    /// Tile key being crossfaded in (back buffer); nil when idle.
    private var inFlightKey: String?
    private var appliedModeIsFuture: Bool?
    private var appliedBaseMapStyle: RadarBaseMapStyle?
    private var appliedOpacity: Double?
    private var appliedSaturation: Double?
    private var appliedContrast: Double?

    private var pendingDesiredState: DesiredRasterState?
    private var crossfadeTask: Task<Void, Never>?
    private var queuedDesiredState: DesiredRasterState?

    private struct DesiredRasterState: Equatable {
      var tileURLs: [String]
      var tileKey: String
      var provider: RadarTileProvider
      var maxZoom: Double
      var opacity: Double
      var saturation: Double
      var contrast: Double
      var showsFuture: Bool
      var isAnimating: Bool
      var visible: Bool
      var fadeDuration: Double
      var tileSize: Double
      var prefetchZoomDelta: Double
      var minimumTileUpdateInterval: Double

      static let hidden = DesiredRasterState(
        tileURLs: [],
        tileKey: "",
        provider: .rainViewer,
        maxZoom: 0,
        opacity: 0,
        saturation: 0,
        contrast: 0,
        showsFuture: false,
        isAnimating: false,
        visible: false,
        fadeDuration: 0,
        tileSize: 256,
        prefetchZoomDelta: 0,
        minimumTileUpdateInterval: 0
      )
    }

    func setupMap(_ mapView: MapView) {
      let camera = CameraOptions(
        center: CLLocationCoordinate2D(latitude: 37.0, longitude: -95.0),
        zoom: 4.5
      )
      mapView.mapboxMap.setCamera(to: camera)

      mapView.mapboxMap.onStyleLoaded.observe { [weak self, weak mapView] _ in
        guard let self, let mapView else { return }
        MapViewHostingSanitizer.sanitize(mapView)
        self.flushPendingDesiredState(on: mapView)
      }.store(in: &cancelables)
    }

    func update(
      mapView: MapView,
      radarState: RadarState,
      opacity: Double,
      defaultMapCenter: CLLocationCoordinate2D,
      recenterDefaultTrigger: UUID?,
      recenterUserCoordinate: CLLocationCoordinate2D?
    ) {
      MapViewHostingSanitizer.sanitize(mapView)

      if !hasAppliedInitialCenter {
        hasAppliedInitialCenter = true
        applyCamera(
          mapView: mapView,
          center: recenterUserCoordinate ?? defaultMapCenter
        )
      }

      if let trigger = recenterDefaultTrigger, trigger != lastRecenterDefaultTrigger {
        lastRecenterDefaultTrigger = trigger
        applyCamera(mapView: mapView, center: defaultMapCenter)
      }

      if let coordinate = recenterUserCoordinate {
        let last = lastRecenterUserCoordinate
        let changed =
          last == nil
          || abs((last?.latitude ?? 0) - coordinate.latitude) > 0.0001
          || abs((last?.longitude ?? 0) - coordinate.longitude) > 0.0001
        if changed {
          lastRecenterUserCoordinate = coordinate
          applyCamera(mapView: mapView, center: coordinate)
        }
      }

      reconcileBaseMapStyle(mapView: mapView, style: radarState.baseMapStyle)

      let desired = resolveDesiredState(from: radarState, opacity: opacity)
      pendingDesiredState = desired.visible ? desired : nil

      guard mapView.mapboxMap.isStyleLoaded else {
        if !desired.visible {
          resetRasterTracking()
        }
        return
      }

      MapViewHostingSanitizer.sanitize(mapView)
      reconcile(mapView: mapView, desired: desired)
    }

    private func resolveDesiredState(from radarState: RadarState, opacity: Double) -> DesiredRasterState {
      guard radarState.showRadarOverlay,
        radarState.activeShowsTiles,
        let frame = radarState.currentFrame,
        !frame.tileURLTemplates.isEmpty
      else {
        return .hidden
      }

      let isFuture = radarState.showsFuture
      let isXweatherForecast =
        frame.provider == .xweather && frame.kind == .forecastPrecipitation
      let fadeDuration: Double
      if radarState.isAnimating {
        fadeDuration = isFuture ? 450 : 400
      } else if isFuture {
        fadeDuration = 250
      } else {
        fadeDuration = 180
      }

      return DesiredRasterState(
        tileURLs: frame.tileURLTemplates,
        tileKey: frame.tileKey,
        provider: frame.provider,
        maxZoom: frame.provider.maxZoom,
        opacity: opacity,
        saturation: radarState.colorScheme.rasterSaturation + (isFuture ? 0.2 : 0.0),
        contrast: radarState.colorScheme.rasterContrast + (isFuture ? 0.1 : 0.0),
        showsFuture: isFuture,
        isAnimating: radarState.isAnimating,
        visible: true,
        fadeDuration: fadeDuration,
        tileSize: isXweatherForecast ? 512 : 256,
        prefetchZoomDelta: Self.prefetchZoomDelta(for: frame.provider, isAnimating: radarState.isAnimating),
        minimumTileUpdateInterval: Self.minimumTileUpdateInterval(for: frame.provider)
      )
    }

    /// IEM tiles are CDN-cached (max-age 300); lower prefetch to avoid melting mesonet servers.
    private static func prefetchZoomDelta(for provider: RadarTileProvider, isAnimating: Bool) -> Double {
      switch provider {
      case .iem:
        return isAnimating ? 1 : 0
      case .rainViewer, .openWeatherMap, .xweather:
        return isAnimating ? 2 : 1
      }
    }

    /// Match provider cache headers where known (IEM `Cache-Control: max-age=300`).
    private static func minimumTileUpdateInterval(for provider: RadarTileProvider) -> Double {
      switch provider {
      case .iem: 300
      default: 0
      }
    }

    private func reconcileBaseMapStyle(mapView: MapView, style: RadarBaseMapStyle) {
      if appliedBaseMapStyle == nil {
        appliedBaseMapStyle = style
        return
      }
      guard appliedBaseMapStyle != style else { return }
      appliedBaseMapStyle = style
      resetRasterTracking()
      mapView.mapboxMap.loadStyle(style.styleURI) { error in
        if let error {
          print("[Mapbox] Style load failed: \(error)")
        }
      }
    }

    private func flushPendingDesiredState(on mapView: MapView) {
      guard mapView.mapboxMap.isStyleLoaded, let desired = pendingDesiredState else { return }
      MapViewHostingSanitizer.sanitize(mapView)
      reconcile(mapView: mapView, desired: desired)
    }

    private func reconcile(mapView: MapView, desired: DesiredRasterState) {
      MapViewHostingSanitizer.sanitize(mapView)

      guard desired.visible else {
        removeLayers(mapView)
        return
      }

      if !layersInstalled {
        installDualLayers(mapView: mapView, desired: desired)
        return
      }

      if appliedModeIsFuture != desired.showsFuture {
        crossfadeTask?.cancel()
        crossfadeTask = nil
        queuedDesiredState = nil
        removeLayers(mapView)
        installDualLayers(mapView: mapView, desired: desired)
        return
      }

      updatePaintIfNeeded(mapView: mapView, desired: desired)

      guard desired.tileKey != displayedFrontKey else { return }

      if crossfadeTask != nil {
        // Keep only the latest frame that isn't already visible or in-flight.
        if desired.tileKey != inFlightKey {
          queuedDesiredState = desired
        }
        return
      }

      crossfadeToFrame(mapView: mapView, desired: desired)
    }

    private func installDualLayers(mapView: MapView, desired: DesiredRasterState) {
      MapViewHostingSanitizer.sanitize(mapView)
      do {
        for slot in [BufferSlot.a, BufferSlot.b] {
          var source = RasterSource(id: slot.sourceId)
          source.tiles = desired.tileURLs
          source.tileSize = desired.tileSize
          source.minzoom = 0
          source.maxzoom = desired.maxZoom
          source.prefetchZoomDelta = desired.prefetchZoomDelta
          source.minimumTileUpdateInterval = desired.minimumTileUpdateInterval
          source.tileNetworkRequestsDelay = 0
          try mapView.mapboxMap.addSource(source)

          var layer = RasterLayer(id: slot.layerId, source: slot.sourceId)
          layer.rasterFadeDuration = .constant(desired.fadeDuration)
          layer.rasterEmissiveStrength = .constant(1)
          layer.rasterOpacity = .constant(slot == frontSlot ? desired.opacity : 0)
          layer.rasterSaturation = .constant(desired.saturation)
          layer.rasterContrast = .constant(desired.contrast)
          layer.rasterResampling = .constant(.linear)
          try mapView.mapboxMap.addLayer(layer)
        }

        layersInstalled = true
        displayedFrontKey = desired.tileKey
        inFlightKey = nil
        appliedModeIsFuture = desired.showsFuture
        appliedOpacity = desired.opacity
        appliedSaturation = desired.saturation
        appliedContrast = desired.contrast
      } catch {
        print("[Mapbox] Dual layer setup failed: \(error)")
        resetRasterTracking()
      }
    }

    private func crossfadeToFrame(mapView: MapView, desired: DesiredRasterState) {
      let backSlot = frontSlot.opposite
      updateSource(
        mapView: mapView,
        slot: backSlot,
        desired: desired
      )
      setLayerFade(mapView: mapView, slot: backSlot, duration: desired.fadeDuration)
      setLayerFade(mapView: mapView, slot: frontSlot, duration: desired.fadeDuration)
      setLayerOpacity(mapView: mapView, slot: backSlot, opacity: desired.opacity)
      setLayerOpacity(mapView: mapView, slot: frontSlot, opacity: 0)

      inFlightKey = desired.tileKey
      appliedOpacity = desired.opacity
      appliedSaturation = desired.saturation
      appliedContrast = desired.contrast

      #if DEBUG
      let zoom = Int(mapView.mapboxMap.cameraState.zoom.rounded())
      RadarTileTrafficMonitor.recordFrameTransition(
        tileKey: desired.tileKey,
        provider: desired.provider,
        zoom: zoom,
        prefetchDelta: Int(desired.prefetchZoomDelta),
        isAnimating: desired.isAnimating
      )
      #endif

      let fadeSeconds = desired.fadeDuration / 1000
      crossfadeTask = Task { @MainActor [weak self, weak mapView] in
        if fadeSeconds > 0 {
          try? await Task.sleep(nanoseconds: UInt64(fadeSeconds * 1_000_000_000))
        }
        guard let self, let mapView, !Task.isCancelled else { return }
        self.frontSlot = backSlot
        self.displayedFrontKey = self.inFlightKey
        self.inFlightKey = nil
        self.crossfadeTask = nil
        self.drainQueuedCrossfade(on: mapView)
      }
    }

    /// Apply the latest queued frame after a crossfade completes; repeats if more queued.
    private func drainQueuedCrossfade(on mapView: MapView) {
      guard let queued = queuedDesiredState else { return }
      queuedDesiredState = nil
      guard queued.tileKey != displayedFrontKey else {
        drainQueuedCrossfade(on: mapView)
        return
      }
      crossfadeToFrame(mapView: mapView, desired: queued)
    }

    private func updatePaintIfNeeded(mapView: MapView, desired: DesiredRasterState) {
      if appliedOpacity != desired.opacity {
        let opacitySlot = crossfadeTask != nil ? frontSlot.opposite : frontSlot
        setLayerOpacity(mapView: mapView, slot: opacitySlot, opacity: desired.opacity)
        appliedOpacity = desired.opacity
      }
      if appliedSaturation != desired.saturation || appliedContrast != desired.contrast {
        for slot in [BufferSlot.a, BufferSlot.b] {
          guard mapView.mapboxMap.layerExists(withId: slot.layerId) else { continue }
          try? mapView.mapboxMap.setLayerProperty(
            for: slot.layerId,
            property: "raster-saturation",
            value: desired.saturation
          )
          try? mapView.mapboxMap.setLayerProperty(
            for: slot.layerId,
            property: "raster-contrast",
            value: desired.contrast
          )
        }
        appliedSaturation = desired.saturation
        appliedContrast = desired.contrast
      }
    }

    private func updateSource(mapView: MapView, slot: BufferSlot, desired: DesiredRasterState) {
      do {
        try mapView.mapboxMap.setSourceProperty(
          for: slot.sourceId,
          property: "tiles",
          value: desired.tileURLs
        )
        try mapView.mapboxMap.setSourceProperty(
          for: slot.sourceId,
          property: "maxzoom",
          value: desired.maxZoom
        )
        // tile-size is immutable after source creation — set only in installDualLayers.
        try mapView.mapboxMap.setSourceProperty(
          for: slot.sourceId,
          property: "prefetch-zoom-delta",
          value: desired.prefetchZoomDelta
        )
        try mapView.mapboxMap.setSourceProperty(
          for: slot.sourceId,
          property: "minimum-tile-update-interval",
          value: desired.minimumTileUpdateInterval
        )
      } catch {
        print("[Mapbox] Failed to update \(slot.sourceId): \(error)")
      }
    }

    private func setLayerOpacity(mapView: MapView, slot: BufferSlot, opacity: Double) {
      guard mapView.mapboxMap.layerExists(withId: slot.layerId) else { return }
      try? mapView.mapboxMap.setLayerProperty(
        for: slot.layerId,
        property: "raster-opacity",
        value: opacity
      )
    }

    private func setLayerFade(mapView: MapView, slot: BufferSlot, duration: Double) {
      guard mapView.mapboxMap.layerExists(withId: slot.layerId) else { return }
      try? mapView.mapboxMap.setLayerProperty(
        for: slot.layerId,
        property: "raster-fade-duration",
        value: duration
      )
    }

    private func applyCamera(
      mapView: MapView,
      center: CLLocationCoordinate2D
    ) {
      let zoom: Double = 6.0
      mapView.mapboxMap.setCamera(to: CameraOptions(center: center, zoom: zoom))
    }

    private func removeLayers(_ mapView: MapView) {
      guard mapView.mapboxMap.isStyleLoaded else {
        resetRasterTracking()
        return
      }

      crossfadeTask?.cancel()
      crossfadeTask = nil
      queuedDesiredState = nil

      for slot in [BufferSlot.a, BufferSlot.b] {
        if mapView.mapboxMap.layerExists(withId: slot.layerId) {
          try? mapView.mapboxMap.removeLayer(withId: slot.layerId)
        }
        if mapView.mapboxMap.sourceExists(withId: slot.sourceId) {
          try? mapView.mapboxMap.removeSource(withId: slot.sourceId)
        }
      }

      resetRasterTracking()
    }

    private func resetRasterTracking() {
      crossfadeTask?.cancel()
      crossfadeTask = nil
      queuedDesiredState = nil
      layersInstalled = false
      frontSlot = .a
      displayedFrontKey = nil
      inFlightKey = nil
      appliedModeIsFuture = nil
      appliedOpacity = nil
      appliedSaturation = nil
      appliedContrast = nil
    }
  }
}
