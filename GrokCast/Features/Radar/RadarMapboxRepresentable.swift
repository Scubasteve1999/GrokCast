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
      styleURI: .dark
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
    private static let tileThrottleInterval: TimeInterval = 0.6
    private static let tileNetworkRequestsDelay: TimeInterval = 0.1

    private let sourceId = "radar"
    private let layerId = "radar-layer"

    private var cancelables = Set<AnyCancelable>()
    private var hasAppliedInitialCenter = false
    private var lastRecenterDefaultTrigger: UUID?
    private var lastRecenterUserCoordinate: CLLocationCoordinate2D?

    private var appliedRasterState: DesiredRasterState?
    private var pendingDesiredState: DesiredRasterState?
    private var lastTileUpdateDate = Date.distantPast
    private var throttleFlushTask: Task<Void, Never>?

    private struct DesiredRasterState: Equatable {
      var tileURLs: [String]
      var tileKey: String
      var maxZoom: Double
      var opacity: Double
      var saturation: Double
      var contrast: Double
      var showsFuture: Bool
      var isAnimating: Bool
      var visible: Bool
      /// Mapbox rasterFadeDuration in milliseconds. 0 for live (crisp frame cuts
      /// show storm motion clearly); non-zero for FUTURE (cross-fades the smooth
      /// forecast blobs so playback feels fluid rather than choppy).
      var fadeDuration: Double
      /// CSS pixel size of each tile in the Mapbox raster source (256 or 512).
      /// Must match the actual pixel dimensions of the tiles being served:
      /// 256 for standard tiles, 512 for @2x retina tiles (Xweather fradar).
      var tileSize: Double

      static let hidden = DesiredRasterState(
        tileURLs: [],
        tileKey: "",
        maxZoom: 0,
        opacity: 0,
        saturation: 0,
        contrast: 0,
        showsFuture: false,
        isAnimating: false,
        visible: false,
        fadeDuration: 0,
        tileSize: 256
      )

      func updatingOpacity(_ opacity: Double) -> Self {
        var copy = self
        copy.opacity = opacity
        return copy
      }
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

      let desired = resolveDesiredState(from: radarState, opacity: opacity)
      pendingDesiredState = desired.visible ? desired : nil

      guard mapView.mapboxMap.isStyleLoaded else {
        if !desired.visible {
          resetRasterTracking()
        }
        return
      }

      MapViewHostingSanitizer.sanitize(mapView)
      reconcile(mapView: mapView, desired: desired, forceImmediate: false)
    }

    private func resolveDesiredState(from radarState: RadarState, opacity: Double) -> DesiredRasterState {
      guard radarState.activeShowsTiles,
        let frame = radarState.currentFrame,
        !frame.tileURLTemplates.isEmpty
      else {
        return .hidden
      }

      // FUTURE fradar tiles are smooth forecast blobs — a cross-fade makes the
      // animation feel fluid. Live radar stays at 0 so storm motion reads crisply.
      // Xweather fradar also benefits from a small saturation lift; its palette
      // looks slightly flat at the default vibrant settings (saturation = 0).
      // Xweather fradar frames use @2x (512px) retina tiles; tileSize must match
      // so Mapbox fetches them at the correct zoom level rather than upscaling.
      let isFuture = radarState.showsFuture
      let isXweatherForecast =
        frame.provider == .xweather && frame.kind == .forecastPrecipitation
      return DesiredRasterState(
        tileURLs: frame.tileURLTemplates,
        tileKey: frame.tileKey,
        maxZoom: frame.provider.maxZoom,
        opacity: opacity,
        saturation: radarState.colorScheme.rasterSaturation + (isFuture ? 0.2 : 0.0),
        contrast: radarState.colorScheme.rasterContrast + (isFuture ? 0.1 : 0.0),
        showsFuture: isFuture,
        isAnimating: radarState.isAnimating,
        visible: true,
        fadeDuration: isFuture ? 300 : 0,
        tileSize: isXweatherForecast ? 512 : 256
      )
    }

    private func flushPendingDesiredState(on mapView: MapView) {
      guard mapView.mapboxMap.isStyleLoaded, let desired = pendingDesiredState else { return }
      MapViewHostingSanitizer.sanitize(mapView)
      reconcile(mapView: mapView, desired: desired, forceImmediate: true)
    }

    private func reconcile(
      mapView: MapView,
      desired: DesiredRasterState,
      forceImmediate: Bool
    ) {
      MapViewHostingSanitizer.sanitize(mapView)

      guard desired.visible else {
        removeLayer(mapView)
        return
      }

      if appliedRasterState == nil {
        setupLayer(mapView: mapView, desired: desired)
        appliedRasterState = desired
        lastTileUpdateDate = Date()
        #if DEBUG
          print("[Mapbox] Radar layer created | key: \(desired.tileKey)")
        #endif
        return
      }

      guard let applied = appliedRasterState else { return }

      let modeChanged = desired.showsFuture != applied.showsFuture
      if modeChanged {
        throttleFlushTask?.cancel()
        // On mode switch (NOW <-> FUTURE), remove and re-add the source/layer to avoid
        // "Updated style is ignored due to runtime changes" warnings and ensure clean update.
        removeLayer(mapView)
        setupLayer(mapView: mapView, desired: desired)
        appliedRasterState = desired
        lastTileUpdateDate = Date()
        #if DEBUG
          print("[Mapbox] Radar layer recreated for mode change | key: \(desired.tileKey)")
        #endif
        return
      }

      let tilesChanged = desired.tileKey != applied.tileKey
      if tilesChanged {
        let shouldCommitImmediately = forceImmediate || !desired.isAnimating
        if shouldCommitImmediately || tileUpdateIntervalElapsed() {
          commitTiles(mapView: mapView, desired: desired)
        } else {
          scheduleThrottledReconcile(mapView: mapView, desired: desired)
        }
      }

      if desired.opacity != applied.opacity {
        updateOpacity(mapView: mapView, opacity: desired.opacity)
        appliedRasterState = appliedRasterState?.updatingOpacity(desired.opacity)
      }

      if desired.saturation != applied.saturation || desired.contrast != applied.contrast {
        updateColorTreatment(
          mapView: mapView, saturation: desired.saturation, contrast: desired.contrast)
        appliedRasterState?.saturation = desired.saturation
        appliedRasterState?.contrast = desired.contrast
      }
    }

    private func commitTiles(mapView: MapView, desired: DesiredRasterState) {
      throttleFlushTask?.cancel()
      updateTileURL(
        mapView: mapView,
        tileURLs: desired.tileURLs,
        maxZoom: desired.maxZoom
      )
      appliedRasterState = desired
      lastTileUpdateDate = Date()
    }

    private func scheduleThrottledReconcile(mapView: MapView, desired: DesiredRasterState) {
      throttleFlushTask?.cancel()
      let scheduledTileKey = desired.tileKey
      let elapsed = Date().timeIntervalSince(lastTileUpdateDate)
      let delay = max(0, Self.tileThrottleInterval - elapsed)

      throttleFlushTask = Task { @MainActor [weak self, weak mapView] in
        if delay > 0 {
          try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        guard let self, let mapView, !Task.isCancelled else { return }
        guard let pending = self.pendingDesiredState,
          pending.tileKey == scheduledTileKey
        else { return }
        self.reconcile(mapView: mapView, desired: pending, forceImmediate: true)
      }
    }

    private func tileUpdateIntervalElapsed() -> Bool {
      Date().timeIntervalSince(lastTileUpdateDate) >= Self.tileThrottleInterval
    }

    private func applyCamera(
      mapView: MapView,
      center: CLLocationCoordinate2D
    ) {
      let zoom: Double = 6.0
      mapView.mapboxMap.setCamera(to: CameraOptions(center: center, zoom: zoom))
    }

    private func setupLayer(mapView: MapView, desired: DesiredRasterState) {
      MapViewHostingSanitizer.sanitize(mapView)
      do {
        var source = RasterSource(id: sourceId)
        source.tiles = desired.tileURLs
        source.tileSize = desired.tileSize
        source.minzoom = 0
        source.maxzoom = desired.maxZoom
        source.prefetchZoomDelta = 0
        source.minimumTileUpdateInterval = Self.tileThrottleInterval
        source.tileNetworkRequestsDelay = Self.tileNetworkRequestsDelay
        try mapView.mapboxMap.addSource(source)

        var layer = RasterLayer(id: layerId, source: sourceId)
        layer.rasterFadeDuration = .constant(desired.fadeDuration)
        layer.rasterEmissiveStrength = .constant(1)
        layer.rasterOpacity = .constant(desired.opacity)
        layer.rasterSaturation = .constant(desired.saturation)
        layer.rasterContrast = .constant(desired.contrast)
        layer.rasterResampling = .constant(.linear)
        try mapView.mapboxMap.addLayer(layer)
      } catch {
        print("[Mapbox] Layer setup failed: \(error)")
        appliedRasterState = nil
      }
    }

    private func updateTileURL(
      mapView: MapView,
      tileURLs: [String],
      maxZoom: Double
    ) {
      do {
        try mapView.mapboxMap.setSourceProperty(
          for: sourceId,
          property: "tiles",
          value: tileURLs
        )
        try mapView.mapboxMap.setSourceProperty(
          for: sourceId,
          property: "maxzoom",
          value: maxZoom
        )
        try mapView.mapboxMap.setSourceProperty(
          for: sourceId,
          property: "minimum-tile-update-interval",
          value: Self.tileThrottleInterval
        )
        try mapView.mapboxMap.setSourceProperty(
          for: sourceId,
          property: "tile-network-requests-delay",
          value: Self.tileNetworkRequestsDelay
        )
      } catch {
        print("[Mapbox] Failed to update tiles: \(error)")
      }
    }

    private func updateOpacity(mapView: MapView, opacity: Double) {
      guard appliedRasterState != nil, mapView.mapboxMap.layerExists(withId: layerId) else { return }
      try? mapView.mapboxMap.setLayerProperty(
        for: layerId,
        property: "raster-opacity",
        value: opacity
      )
    }

    private func updateColorTreatment(mapView: MapView, saturation: Double, contrast: Double) {
      guard appliedRasterState != nil, mapView.mapboxMap.layerExists(withId: layerId) else { return }
      try? mapView.mapboxMap.setLayerProperty(
        for: layerId,
        property: "raster-saturation",
        value: saturation
      )
      try? mapView.mapboxMap.setLayerProperty(
        for: layerId,
        property: "raster-contrast",
        value: contrast
      )
    }

    private func removeLayer(_ mapView: MapView) {
      guard mapView.mapboxMap.isStyleLoaded else {
        resetRasterTracking()
        return
      }

      if mapView.mapboxMap.layerExists(withId: layerId) {
        try? mapView.mapboxMap.removeLayer(withId: layerId)
      }
      if mapView.mapboxMap.sourceExists(withId: sourceId) {
        try? mapView.mapboxMap.removeSource(withId: sourceId)
      }

      resetRasterTracking()
    }

    private func resetRasterTracking() {
      throttleFlushTask?.cancel()
      throttleFlushTask = nil
      appliedRasterState = nil
      lastTileUpdateDate = .distantPast
    }
  }
}