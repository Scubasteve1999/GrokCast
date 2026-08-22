import Combine
import CoreGraphics
import Foundation
import MapboxMaps
import MapsGLMapbox
import MapsGLMaps
import UIKit

/// Owns the MapsGL controller on the existing Mapbox `MapView`.
/// Encoded radar is painted client-side; PNG raster stays the fallback
/// until this host reports `isReady`.
@MainActor
final class MapsGLRadarHost {
  private var controller: MapboxMapController?
  private var cancellables = Set<AnyCancellable>()
  private var attachedMapView: MapView?
  private var layerReady = false
  private var stormcellsReady = false
  private var lastVisible: Bool?
  private var lastCellsWant: Bool?
  private var lastFrameDate: Date?
  private var lastFuture: Bool?
  /// Real overlay/site flags for `shouldShow`. Do not pass rainWant as overlayOn.
  private var lastOverlayOn: Bool?
  private var lastIsSiteProduct: Bool?
  private var pendingOpacity: Double = RadarPreferences.defaultRadarOpacity
  /// Today preview is rain-only. Live Radar paints StormcellsTracks paths only.
  var paintsStormcells = true

  /// Called on the main actor after layer add succeeds or fails so the
  /// representable can hide or restore PNG tiles.
  var onLayerStateChange: (() -> Void)?

  var isReady: Bool { layerReady }

  nonisolated static var keysPresent: Bool {
    guard let id = DeveloperAPIKey.xweatherClientID, !id.isEmpty,
      let secret = DeveloperAPIKey.xweatherClientSecret, !secret.isEmpty
    else { return false }
    return true
  }

  func attach(to mapView: MapView) {
    guard Self.keysPresent else { return }
    if attachedMapView === mapView, controller != nil { return }

    detach()
    attachedMapView = mapView
    try? mapView.mapboxMap.setProjection(StyleProjection(name: .mercator))

    guard let id = DeveloperAPIKey.xweatherClientID,
      let secret = DeveloperAPIKey.xweatherClientSecret
    else { return }

    let account = XweatherAccount(id: id, secret: secret)
    let controller = MapboxMapController(map: mapView, account: account)
    // Metal rain is a CustomLayer. Circle/line tracks must sit above it or
    // they composite under the encoded overlay and look like "no tracks".
    controller.placementProvider = MapboxMapController.PlacementProvider { layer, _ in
      var placement = MapboxMapController.Placement()
      if MapsGLLiveRainLayers.stormcellIDs.contains(layer.id) {
        placement.position = .above(MapsGLLiveRainLayers.radarID)
      }
      return placement
    }
    self.controller = controller

    controller.onLoad.observe { [weak self] _ in
      self?.installRadarLayer()
    }.store(in: &cancellables)
  }

  func detach() {
    if let controller {
      if layerReady {
        controller.removeWeatherLayer(for: .radar)
      }
      if stormcellsReady {
        for code in Self.stormcellCodes {
          controller.removeWeatherLayer(for: code)
        }
      }
    }
    cancellables.removeAll()
    controller = nil
    attachedMapView = nil
    layerReady = false
    stormcellsReady = false
    lastVisible = nil
    lastCellsWant = nil
    lastFrameDate = nil
    lastFuture = nil
    lastOverlayOn = nil
    lastIsSiteProduct = nil
  }

  /// Snapshot for Today: Live rain only, newest scan, no site products.
  func syncPreview(opacity: Double, now: Date = Date()) {
    pendingOpacity = opacity
    lastOverlayOn = true
    lastIsSiteProduct = false
    let want = MapsGLRadarPalette.shouldUseMapsGL(
      overlayOn: true, isSiteProduct: false, keysPresent: Self.keysPresent
    )
    guard let controller else {
      lastVisible = want
      lastCellsWant = cellsWanted()
      return
    }

    let futureChanged = lastFuture != false
    if futureChanged {
      lastFuture = false
      applyTimelineRange(future: false, on: controller)
    }
    let cellsWant = cellsWanted()
    let cellsNeedAttach = cellsWant && !stormcellsReady
    if lastVisible != want || lastCellsWant != cellsWant || futureChanged
      || cellsNeedAttach
    {
      lastVisible = want
      applyVisibility(want, on: controller)
    }
    guard want else { return }
    // A few minutes behind wall clock matches Live mosaic's newest scan.
    let frameDate = now.addingTimeInterval(-8 * 60)
    if lastFrameDate != frameDate {
      lastFrameDate = frameDate
      controller.timeline.goTo(date: frameDate)
    }
  }

  func sync(radarState: RadarState, opacity: Double) {
    pendingOpacity = opacity
    lastOverlayOn = radarState.showRadarOverlay
    lastIsSiteProduct = radarState.selectedProduct.isSiteProduct
    var want = MapsGLRadarPalette.shouldUseMapsGL(
      overlayOn: radarState.showRadarOverlay,
      isSiteProduct: radarState.selectedProduct.isSiteProduct,
      keysPresent: Self.keysPresent
    )
    #if DEBUG
      // Spike overlay replaces encoded rain only. Tracks still follow overlayOn.
      if radarState.debugNationalOverlay, !radarState.showsFuture,
        !radarState.selectedProduct.isSiteProduct
      {
        want = false
      }
    #endif
    guard let controller else {
      lastVisible = want
      lastCellsWant = cellsWanted()
      return
    }

    let futureChanged = lastFuture != radarState.showsFuture
    if futureChanged {
      lastFuture = radarState.showsFuture
      applyTimelineRange(future: radarState.showsFuture, on: controller)
    }

    let cellsWant = cellsWanted()
    let cellsNeedAttach = cellsWant && !stormcellsReady
    if lastVisible != want || lastCellsWant != cellsWant || futureChanged
      || cellsNeedAttach
    {
      lastVisible = want
      applyVisibility(want, on: controller)
    }

    guard want else { return }

    if let date = radarState.currentFrameDate, lastFrameDate != date {
      lastFrameDate = date
      controller.timeline.goTo(date: date)
    }
  }

  private func installRadarLayer() {
    guard let controller else { return }
    // Do not add rain (or tracks) until mosaic Live wants them. Adding the
    // radar layer visible and then hiding it is how N0B kept mosaic rain.
    let rainWant = MapsGLLiveRainLayers.shouldAttachRadar(
      overlayOn: lastOverlayOn ?? false,
      isSiteProduct: lastIsSiteProduct ?? true,
      keysPresent: Self.keysPresent
    )
    applyVisibility(rainWant, on: controller)
    onLayerStateChange?()
  }

  private func addRadarLayer(on controller: MapboxMapController) {
    guard !layerReady else { return }
    do {
      var config = WeatherService.Radar(service: controller.service)
      config.layer.paint.sample.colorScale = .colorScale(Self.colorScale)
      // Native bins + stepped colorscale. Bicubic/smoothing was the toy look.
      // MapsGL SampleFillLayerPaint has no core-outline stroke — hard 5 dBZ
      // bands have to do that job.
      config.layer.paint.sample.smoothing = MapsGLRadarPalette.sampleSmoothing
      config.layer.paint.sample.interpolation =
        MapsGLRadarPalette.interpolatesSamples ? .bicubic : .none
      config.layer.paint.sample.quality = .exact
      config.layer.paint.sample.meld = false
      config.layer.paint.sample.drawRange = 5...75
      config.layer.paint.opacity = Opacity(value: Float(pendingOpacity))
      config.layer.quality = .exact
      try controller.addWeatherLayer(config: config)
      layerReady = true
      radarLog("[MapsGL] radar layer added")
      onLayerStateChange?()
    } catch {
      radarLog("[MapsGL] Failed to add radar layer: \(error)")
      layerReady = false
    }
  }

  private func removeRadarLayer(on controller: MapboxMapController) {
    guard layerReady else { return }
    controller.removeWeatherLayer(for: .radar)
    layerReady = false
    lastVisible = false
    radarLog("[MapsGL] radar layer removed")
    onLayerStateChange?()
  }

  /// Typed `StormcellsTracks` only. `WeatherService.Stormcells` also ships
  /// positions + cones + heat. Positions are the white pin/tick swarm.
  /// MapsGL cannot lengthen forecast-track geometry; empty coverage is valid.
  /// Filter is hail/rotating/tornado (`traits.type`). `general` is the
  /// dry-air tick spray across the South.
  private func installStormcellLayers(on controller: MapboxMapController) {
    do {
      var config = WeatherService.StormcellsTracks(service: controller.service)
      config.layer.paint.stroke.color = .constant(
        UIColor(white: MapsGLLiveRainLayers.trackColorWhite, alpha: 1)
      )
      config.layer.paint.stroke.thickness = .constant(MapsGLLiveRainLayers.trackThickness)
      config.layer.paint.stroke.opacity = .constant(MapsGLLiveRainLayers.trackOpacity)
      config.layer.paint.stroke.lineCap = .constant(.butt)
      config.layer.paint.stroke.lineJoin = .constant(.miter)
      config.layer.filter = Self.severeStormcellTrackFilter
      try controller.addWeatherLayer(config: config)
      stormcellsReady = true
      radarLog("[MapsGL] stormcells-tracks added")
      applyNativeStormcellTrackFilter()
      Task { @MainActor [weak self] in
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        self?.applyNativeStormcellTrackFilter()
      }
    } catch {
      radarLog("[MapsGL] Failed to add stormcells-tracks: \(error)")
      stormcellsReady = false
    }
  }

  /// MapsGL `and`/`geometry-type` can no-op the same way `contains` did in 1.6.1.
  /// Set the Mapbox layer filter directly so cone polygons are not stroked.
  private func applyNativeStormcellTrackFilter() {
    guard let map = attachedMapView?.mapboxMap else { return }
    let layerID = MapsGLLiveRainLayers.stormcellIDs[0]
    guard map.layerExists(withId: layerID) else { return }
    try? map.setLayerProperty(
      for: layerID,
      property: "filter",
      value: MapsGLLiveRainLayers.mapboxStormcellTrackFilter
    )
  }

  private func removeStormcellLayers(on controller: MapboxMapController) {
    guard stormcellsReady else { return }
    for code in Self.stormcellCodes {
      controller.removeWeatherLayer(for: code)
    }
    stormcellsReady = false
    lastCellsWant = false
    radarLog("[MapsGL] stormcells-tracks removed")
  }

  /// Real overlay + site flags. Passing `rainWant` as overlayOn with
  /// `isSiteProduct: false` was the leak: tracks stayed on N0B.
  private func cellsWanted() -> Bool {
    guard paintsStormcells else { return false }
    return MapsGLLiveRainLayers.shouldShow(
      overlayOn: lastOverlayOn ?? false,
      isSiteProduct: lastIsSiteProduct ?? true,
      keysPresent: Self.keysPresent,
      isLive: lastFuture != true
    )
  }

  private func applyVisibility(_ rainWant: Bool, on controller: MapboxMapController) {
    lastVisible = rainWant
    if rainWant {
      addRadarLayer(on: controller)
    } else {
      removeRadarLayer(on: controller)
    }
    let cellsWant = cellsWanted()
    lastCellsWant = cellsWant
    if cellsWant {
      if !stormcellsReady {
        installStormcellLayers(on: controller)
      }
    } else {
      removeStormcellLayers(on: controller)
    }
  }

  /// Typed codes — do not compactMap hyphen strings; the SDK case names are
  /// camelCase (`stormcellsTracks`) with hyphenated raw values.
  private static let stormcellCodes: [WeatherService.LayerCode] = [
    .stormcellsTracks
  ]

  /// Xweather `traits.type` hail/rotating/tornado = SVR/TOR class.
  /// `general` cells are the nationwide tick spray on dry air.
  /// Use `any`/`==`, not `in`/`contains`: MapsGL 1.6.1 treats a bare string
  /// array as an expression, so `contains(..., in: ["hail", ...])` can no-op
  /// and paint every cell.
  private static var severeStormcellFilter: MapsGLMaps.Expression {
    let type = MapsGLMaps.Expression.get(MapsGLLiveRainLayers.traitTypeProperty)
    var clauses: [Any] = MapsGLLiveRainLayers.severeTraitTypes.map {
      MapsGLMaps.Expression.equals(type, $0) as Any
    }
    clauses.append(
      MapsGLMaps.Expression.equals(
        MapsGLMaps.Expression.get(MapsGLLiveRainLayers.traitTornadoProperty), 1))
    clauses.append(
      MapsGLMaps.Expression.equals(
        MapsGLMaps.Expression.get(MapsGLLiveRainLayers.tvsProperty), 1))
    return MapsGLMaps.Expression.or(clauses)
  }

  /// Drop forecast-cone polygons from the tracks line layer. Raw Mapbox
  /// arrays — MapsGL `and`/`geometry-type` helpers can no-op like `contains`.
  private static var severeStormcellTrackFilter: MapsGLMaps.Expression {
    MapsGLMaps.Expression(MapsGLLiveRainLayers.mapboxStormcellTrackFilter)
  }

  private func applyTimelineRange(future: Bool, on controller: MapboxMapController) {
    if future {
      controller.timeline.startDate = Date()
      controller.timeline.endDate = Date().addingTimeInterval(12 * 3600)
    } else {
      controller.timeline.startDate = Date().addingTimeInterval(
        -RadarLivePresentation.mapsGLLiveLookback)
      controller.timeline.endDate = Date()
    }
  }

  private static var colorScale: ColorScaleOptions {
    var options = ColorScaleOptions(
      stops: MapsGLRadarPalette.reflectivityStops.map { stop in
        ColorStop(stop.dbz, Self.color(hex: stop.hex, alpha: stop.alpha))
      }
    )
    // Stepped 5 dBZ bins. interpolate default is true (smooth toy wash);
    // interval default is 0 (gradient). Both must be overridden. Apple SDK
    // has no `breaks` — range + interval + interpolate=false is the native binning.
    options.interpolate = MapsGLRadarPalette.interpolatesStops
    options.interval = MapsGLRadarPalette.bandIntervalDbz
    options.range = 0...70
    options.normalized = false
    return options
  }

  private static func color(hex: String, alpha: Double) -> CGColor {
    let base = CGColor.fromString(hex)
    return base.copy(alpha: CGFloat(alpha)) ?? CGColor.fromString("#00000000")
  }
}
