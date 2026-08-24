import CoreLocation
import MapboxMaps
import SwiftUI
import UIKit

/// What the Today radar teaser is allowed to paint. Never a blank rectangle.
enum RadarPreviewPaint: Equatable {
  case nationalMapsGL
  case siteDoppler
  case unavailable

  static func resolve(
    hoisted: Bool,
    hasDrawableSweep: Bool,
    mapboxPresent: Bool,
    mapsGLKeysPresent: Bool
  ) -> RadarPreviewPaint {
    if hoisted {
      if hasDrawableSweep, mapboxPresent { return .siteDoppler }
      return .unavailable
    }
    if mapsGLKeysPresent, mapboxPresent { return .nationalMapsGL }
    return .unavailable
  }
}

struct RadarPreviewCard: View {
  @Environment(WeatherStore.self) private var store
  var paint: RadarPreviewPaint = .nationalMapsGL
  var sweep: Level3N0BSweep? = nil
  var onPolarFailed: (() -> Void)? = nil

  private var coordinate: CLLocationCoordinate2D? {
    guard let loc = store.currentLocation else { return nil }
    return CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
  }

  var body: some View {
    radarMap
  }

  @ViewBuilder
  private var radarMap: some View {
    switch paint {
    case .siteDoppler:
      if let coord = coordinate, let sweep {
        framedMap {
          RadarPreviewSiteMap(
            center: coord,
            sweep: sweep,
            onPolarFailed: onPolarFailed
          )
        }
      }
    case .nationalMapsGL:
      if let coord = coordinate,
        RadarPreviewSource.usesMapsGL(keysPresent: MapsGLRadarHost.keysPresent)
      {
        framedMap {
          RadarPreviewMapboxMap(center: coord)
        }
      }
    case .unavailable:
      EmptyView()
    }
  }

  private func framedMap<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
      .allowsHitTesting(false)
      .frame(height: 160)
      .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadius))
      .overlay(
        RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadius)
          .stroke(DesignTokens.Palette.cardStroke, lineWidth: 1)
      )
  }
}

/// Today’s snapshot must paint the same MapsGL rain as Live, on Light.
/// PNG mosaic is a different scale — do not use it when MapsGL is the Live paint.
enum RadarPreviewSource {
  static let previewBaseMap = RadarBaseMapStyle.light
  /// Buried National teaser — CONUS-ish so nearby cells fit the 160pt card.
  static let previewZoom: Double = 4.5
  /// Hoisted Site Doppler — same ~120 mi frame Live uses for wet local.
  static var siteZoom: Double { RadarLiveCameraPolicy.localZoom }

  static var mapboxTokenPresent: Bool {
    guard let token = DeveloperAPIKey.mapbox, !token.isEmpty else { return false }
    return true
  }

  static func usesMapsGL(keysPresent: Bool) -> Bool {
    MapsGLRadarPalette.shouldUseMapsGL(
      overlayOn: true, isSiteProduct: false, keysPresent: keysPresent
    )
  }
}

/// Non-interactive Mapbox Light + the same MapsGL NWS reflectivity Live uses.
private struct RadarPreviewMapboxMap: UIViewRepresentable {
  let center: CLLocationCoordinate2D

  func makeUIView(context: Context) -> MapView {
    if let token = DeveloperAPIKey.mapbox, !token.isEmpty {
      MapboxOptions.accessToken = token
    }
    let scale = max(1.0, Double(UIScreen.main.scale))
    let options = MapInitOptions(
      mapOptions: MapOptions(pixelRatio: CGFloat(scale)),
      styleURI: RadarPreviewSource.previewBaseMap.styleURI
    )
    let mapView = MapView(
      frame: CGRect(x: 0, y: 0, width: 400, height: 160),
      mapInitOptions: options
    )
    if mapView.contentScaleFactor.isNaN || mapView.contentScaleFactor <= 0 {
      mapView.contentScaleFactor = scale
    }
    mapView.isUserInteractionEnabled = false
    mapView.ornaments.options.compass.visibility = .hidden
    mapView.ornaments.options.scaleBar.visibility = .hidden
    mapView.mapboxMap.setCamera(
      to: CameraOptions(center: center, zoom: RadarPreviewSource.previewZoom)
    )
    try? mapView.mapboxMap.setProjection(StyleProjection(name: .mercator))
    RadarPreviewSource.previewBaseMap.applyQuietWorkstation(to: mapView)
    mapView.mapboxMap.onStyleLoaded.observe { [weak mapView] _ in
      guard let mapView else { return }
      RadarPreviewSource.previewBaseMap.applyQuietWorkstation(to: mapView)
    }.store(in: &context.coordinator.styleObservers)

    let host = context.coordinator.host
    host.onLayerStateChange = { [weak host] in
      host?.syncPreview(opacity: RadarPreferences.defaultRadarOpacity)
    }
    host.syncPreview(opacity: RadarPreferences.defaultRadarOpacity)
    host.attach(to: mapView)
    host.syncPreview(opacity: RadarPreferences.defaultRadarOpacity)
    return mapView
  }

  func updateUIView(_ mapView: MapView, context: Context) {
    let current = mapView.mapboxMap.cameraState.center
    let moved =
      abs(current.latitude - center.latitude) > 0.01
      || abs(current.longitude - center.longitude) > 0.01
    if moved {
      mapView.mapboxMap.setCamera(
        to: CameraOptions(center: center, zoom: RadarPreviewSource.previewZoom)
      )
    }
  }

  static func dismantleUIView(_ uiView: MapView, coordinator: Coordinator) {
    coordinator.host.detach()
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  @MainActor
  final class Coordinator {
    var styleObservers = Set<AnyCancelable>()
    let host: MapsGLRadarHost = {
      let host = MapsGLRadarHost()
      host.paintsStormcells = false
      return host
    }()
  }
}

/// Non-interactive Mapbox Light + Level III polar gates (same host as Live Site Doppler).
private struct RadarPreviewSiteMap: UIViewRepresentable {
  let center: CLLocationCoordinate2D
  let sweep: Level3N0BSweep
  var onPolarFailed: (() -> Void)?

  func makeUIView(context: Context) -> MapView {
    if let token = DeveloperAPIKey.mapbox, !token.isEmpty {
      MapboxOptions.accessToken = token
    }
    let scale = max(1.0, Double(UIScreen.main.scale))
    let options = MapInitOptions(
      mapOptions: MapOptions(pixelRatio: CGFloat(scale)),
      styleURI: RadarPreviewSource.previewBaseMap.styleURI
    )
    let mapView = MapView(
      frame: CGRect(x: 0, y: 0, width: 400, height: 160),
      mapInitOptions: options
    )
    if mapView.contentScaleFactor.isNaN || mapView.contentScaleFactor <= 0 {
      mapView.contentScaleFactor = scale
    }
    mapView.isUserInteractionEnabled = false
    mapView.ornaments.options.compass.visibility = .hidden
    mapView.ornaments.options.scaleBar.visibility = .hidden
    mapView.mapboxMap.setCamera(
      to: CameraOptions(center: center, zoom: RadarPreviewSource.siteZoom)
    )
    try? mapView.mapboxMap.setProjection(StyleProjection(name: .mercator))
    RadarPreviewSource.previewBaseMap.applyQuietWorkstation(to: mapView)
    let coordinator = context.coordinator
    let sweep = self.sweep
    mapView.mapboxMap.onStyleLoaded.observe { [weak mapView] _ in
      guard let mapView else { return }
      RadarPreviewSource.previewBaseMap.applyQuietWorkstation(to: mapView)
      coordinator.applySweep(sweep, on: mapView)
    }.store(in: &coordinator.styleObservers)
    coordinator.onPolarFailed = onPolarFailed
    if mapView.mapboxMap.isStyleLoaded {
      coordinator.applySweep(sweep, on: mapView)
    }
    return mapView
  }

  func updateUIView(_ mapView: MapView, context: Context) {
    context.coordinator.onPolarFailed = onPolarFailed
    let current = mapView.mapboxMap.cameraState.center
    let moved =
      abs(current.latitude - center.latitude) > 0.01
      || abs(current.longitude - center.longitude) > 0.01
    if moved {
      mapView.mapboxMap.setCamera(
        to: CameraOptions(center: center, zoom: RadarPreviewSource.siteZoom)
      )
    }
    if mapView.mapboxMap.isStyleLoaded {
      context.coordinator.applySweep(sweep, on: mapView)
    }
  }

  static func dismantleUIView(_ uiView: MapView, coordinator: Coordinator) {
    coordinator.polarHost.setSweep(nil, opacity: 1, isAnimating: false) {}
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  @MainActor
  final class Coordinator {
    var styleObservers = Set<AnyCancelable>()
    let polarHost = Level3PolarMetalHost()
    var polarLayerInstalled = false
    var polarLayerFailed = false
    var currentSweepKey: String?
    var onPolarFailed: (() -> Void)?

    func applySweep(_ sweep: Level3N0BSweep, on mapView: MapView) {
      ensurePolarLayer(on: mapView)
      guard !polarLayerFailed else { return }
      let key = Level3N0BSweepStore.exactKey(site: sweep.siteID, timestamp: sweep.timestamp)
      polarHost.setSweep(
        sweep,
        opacity: Float(RadarPreferences.defaultRadarOpacity),
        isAnimating: false
      ) {
        mapView.mapboxMap.triggerRepaint()
      }
      currentSweepKey = key
    }

    private func ensurePolarLayer(on mapView: MapView) {
      if polarLayerFailed { return }
      if polarHost.onNeedsDisplay == nil {
        polarHost.onNeedsDisplay = { [weak mapView] in
          mapView?.mapboxMap.triggerRepaint()
        }
      }
      if polarLayerInstalled { return }
      let position = RadarBaseMapStyle.polarUnderlayLayerPosition(on: mapView)
      if mapView.mapboxMap.layerExists(withId: Level3PolarMetalHost.layerID) {
        if let position {
          try? mapView.mapboxMap.moveLayer(
            withId: Level3PolarMetalHost.layerID, to: position)
        }
        polarLayerInstalled = true
        return
      }
      do {
        try mapView.mapboxMap.addCustomLayer(
          withId: Level3PolarMetalHost.layerID,
          layerHost: polarHost,
          layerPosition: position)
        polarLayerInstalled = true
      } catch {
        polarLayerFailed = true
        radarLog("[Level3] Today Site Doppler polar layer failed: \(error)")
        onPolarFailed?()
      }
    }
  }
}
