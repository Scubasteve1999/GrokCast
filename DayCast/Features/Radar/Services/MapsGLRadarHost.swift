import Combine
import CoreGraphics
import Foundation
import MapboxMaps
import MapsGLMapbox
import MapsGLMaps

/// Owns the MapsGL controller on the existing Mapbox `MapView`.
/// Encoded radar is painted client-side; PNG raster stays the fallback
/// until this host reports `isReady`.
@MainActor
final class MapsGLRadarHost {
  private var controller: MapboxMapController?
  private var cancellables = Set<AnyCancellable>()
  private var attachedMapView: MapView?
  private var layerReady = false
  private var lastVisible: Bool?
  private var lastFrameDate: Date?
  private var lastFuture: Bool?
  private var pendingOpacity: Double = 0.85

  /// Called on the main actor after layer add succeeds or fails so the
  /// representable can hide or restore PNG tiles.
  var onLayerStateChange: (() -> Void)?

  var isReady: Bool { layerReady }

  static var keysPresent: Bool {
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
    self.controller = controller

    controller.onLoad.observe { [weak self] _ in
      self?.installRadarLayer()
    }.store(in: &cancellables)
  }

  func detach() {
    if layerReady, let controller {
      controller.removeWeatherLayer(for: .radar)
    }
    cancellables.removeAll()
    controller = nil
    attachedMapView = nil
    layerReady = false
    lastVisible = nil
    lastFrameDate = nil
    lastFuture = nil
  }

  func sync(radarState: RadarState, opacity: Double) {
    pendingOpacity = opacity
    let want = MapsGLRadarPalette.shouldUseMapsGL(
      overlayOn: radarState.showRadarOverlay,
      isSiteProduct: radarState.selectedProduct.isSiteProduct,
      keysPresent: Self.keysPresent
    )
    guard let controller else { return }

    if lastFuture != radarState.showsFuture {
      lastFuture = radarState.showsFuture
      applyTimelineRange(future: radarState.showsFuture, on: controller)
    }

    if lastVisible != want {
      lastVisible = want
      if layerReady {
        controller.setWeatherLayerVisibility(for: .radar, visible: want)
      }
    }

    guard want else { return }

    if let date = radarState.currentFrameDate, lastFrameDate != date {
      lastFrameDate = date
      controller.timeline.goTo(date: date)
    }
  }

  private func installRadarLayer() {
    guard let controller else { return }
    do {
      var config = WeatherService.Radar(service: controller.service)
      config.layer.paint.sample.colorScale = .colorScale(Self.colorScale)
      config.layer.paint.opacity = Opacity(value: Float(pendingOpacity))
      config.layer.quality = .high
      try controller.addWeatherLayer(config: config)
      layerReady = true
      radarLog("[MapsGL] radar layer added")
    } catch {
      radarLog("[MapsGL] Failed to add radar layer: \(error)")
      layerReady = false
    }
    onLayerStateChange?()
  }

  private func applyTimelineRange(future: Bool, on controller: MapboxMapController) {
    if future {
      controller.timeline.startDate = Date()
      controller.timeline.endDate = Date().addingTimeInterval(12 * 3600)
    } else {
      controller.timeline.startDate = Date().addingTimeInterval(-3 * 3600)
      controller.timeline.endDate = Date()
    }
  }

  private static var colorScale: ColorScaleOptions {
    var options = ColorScaleOptions(
      stops: MapsGLRadarPalette.reflectivityStops.map { stop in
        ColorStop(stop.dbz, Self.color(hex: stop.hex, alpha: stop.alpha))
      }
    )
    options.interpolate = MapsGLRadarPalette.interpolatesStops
    return options
  }

  private static func color(hex: String, alpha: Double) -> CGColor {
    let base = CGColor.fromString(hex)
    return base.copy(alpha: CGFloat(alpha)) ?? CGColor.fromString("#00000000")
  }
}
