import CoreLocation
import MapboxMaps
import SwiftUI
import UIKit

/// What the Today radar teaser is allowed to paint. Never a blank rectangle.
/// Hoisted Site Doppler only when a sweep can draw. Otherwise National MapsGL
/// when keys are present. Without MapsGL keys, National PNG tiles (same family
/// Live uses: MRMS / IEM / RainViewer / OWM). `.unavailable` is no Mapbox.
enum RadarPreviewPaint: Equatable {
  case nationalMapsGL
  case nationalTiles
  case siteDoppler
  case unavailable

  static func resolve(
    hoisted: Bool,
    hasDrawableSweep: Bool,
    mapboxPresent: Bool,
    mapsGLKeysPresent: Bool
  ) -> RadarPreviewPaint {
    if hoisted, hasDrawableSweep, mapboxPresent { return .siteDoppler }
    if mapsGLKeysPresent, mapboxPresent { return .nationalMapsGL }
    if mapboxPresent { return .nationalTiles }
    return .unavailable
  }

  /// Inner Today map branch. Missing sweep/keys/coord never resolve to a blank hole.
  /// Prefer National MapsGL when a coordinate and keys exist; Live's National
  /// tile family when MapsGL is missing but Mapbox is present; gray plate otherwise.
  static func display(
    paint: RadarPreviewPaint,
    hasCoordinate: Bool,
    hasSweep: Bool,
    mapsGLReady: Bool,
    mapboxPresent: Bool
  ) -> RadarPreviewPaint {
    switch paint {
    case .siteDoppler:
      if hasCoordinate, hasSweep { return .siteDoppler }
      if hasCoordinate, mapsGLReady, mapboxPresent { return .nationalMapsGL }
      if hasCoordinate, mapboxPresent { return .nationalTiles }
      return .unavailable
    case .nationalMapsGL:
      if hasCoordinate, mapsGLReady, mapboxPresent { return .nationalMapsGL }
      if hasCoordinate, mapboxPresent { return .nationalTiles }
      return .unavailable
    case .nationalTiles:
      if hasCoordinate, mapboxPresent { return .nationalTiles }
      return .unavailable
    case .unavailable:
      return .unavailable
    }
  }

  /// Every Today Outlook map branch reserves this height, including unavailable.
  static var reservedPlateHeight: CGFloat { RadarPreviewSource.outlookPlateHeight }
}

struct RadarPreviewCard: View {
  @Environment(WeatherStore.self) private var store
  var paint: RadarPreviewPaint = .nationalMapsGL
  var sweep: Level3N0BSweep? = nil
  var height: CGFloat = RadarPreviewSource.outlookPlateHeight
  var showsFuture: Bool = false
  var onPolarFailed: (() -> Void)? = nil

  @State private var nationalFrame: RadarFrame?
  @State private var nationalTilesFailed = false

  private var coordinate: CLLocationCoordinate2D? {
    guard let loc = store.currentLocation else { return nil }
    return CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
  }

  var body: some View {
    radarMap
      .frame(height: height)
      .clipped()
  }

  @ViewBuilder
  private var radarMap: some View {
    let shown = RadarPreviewPaint.display(
      paint: paint,
      hasCoordinate: coordinate != nil,
      hasSweep: sweep != nil,
      mapsGLReady: RadarPreviewSource.usesMapsGL(keysPresent: MapsGLRadarHost.keysPresent),
      mapboxPresent: RadarPreviewSource.mapboxTokenPresent
    )
    Group {
      switch shown {
      case .siteDoppler:
        if let coord = coordinate, let sweep {
          framedMap {
            RadarPreviewSiteMap(
              center: coord,
              sweep: sweep,
              onPolarFailed: onPolarFailed
            )
          }
        } else {
          RadarPreviewUnavailablePlate(height: height)
        }
      case .nationalMapsGL:
        if let coord = coordinate {
          framedMap {
            RadarPreviewMapboxMap(center: coord, showsFuture: showsFuture)
          }
        } else {
          RadarPreviewUnavailablePlate(height: height)
        }
      case .nationalTiles:
        nationalTilesPlate
      case .unavailable:
        RadarPreviewUnavailablePlate(height: height)
      }
    }
    .task(id: nationalLoadKey(shown)) {
      await loadNationalTilesIfNeeded(shown)
    }
  }

  @ViewBuilder
  private var nationalTilesPlate: some View {
    if let coord = coordinate {
      if nationalTilesFailed {
        RadarPreviewUnavailablePlate(height: height)
      } else {
        framedMap {
          RadarPreviewNationalTileMap(center: coord, frame: nationalFrame)
        }
      }
    } else {
      RadarPreviewUnavailablePlate(height: height)
    }
  }

  private func nationalLoadKey(_ shown: RadarPreviewPaint) -> String {
    let lat = coordinate?.latitude ?? 0
    let lon = coordinate?.longitude ?? 0
    return "\(shown)-\(showsFuture)-\(lat)-\(lon)"
  }

  private func loadNationalTilesIfNeeded(_ shown: RadarPreviewPaint) async {
    guard shown == .nationalTiles, let coordinate else {
      nationalFrame = nil
      nationalTilesFailed = false
      return
    }
    nationalTilesFailed = false
    nationalFrame = nil
    let loader = RadarLoader()
    let frame: RadarFrame?
    if showsFuture {
      frame = await loader.loadNewestNationalForecastFrame()
    } else {
      frame = await loader.loadNewestNationalLiveFrame(coordinate: coordinate)
    }
    guard !Task.isCancelled else { return }
    nationalFrame = frame
    nationalTilesFailed = frame == nil
  }

  private func framedMap<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
      .allowsHitTesting(false)
      .frame(height: height)
      .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadius))
      .overlay(
        RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadius)
          .stroke(DesignTokens.Palette.cardStroke, lineWidth: 1)
      )
  }
}

/// Gray Outlook plate. Always `outlookPlateHeight` — never a zero-height hole.
struct RadarPreviewUnavailablePlate: View {
  var height: CGFloat = RadarPreviewSource.outlookPlateHeight

  var body: some View {
    RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadius)
      .fill(DesignTokens.Palette.radarTrack)
      .frame(height: height)
      .overlay {
        Text(RadarFeedCopy.radarUnavailable)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }
      .overlay(
        RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadius)
          .stroke(DesignTokens.Palette.cardStroke, lineWidth: 1)
      )
  }
}

/// Today’s snapshot must paint the same MapsGL rain as Live, on Dark.
/// PNG mosaic is a different scale — do not use it when MapsGL is the Live paint.
enum RadarPreviewSource {
  static let previewBaseMap = RadarBaseMapStyle.dark
  /// Retired postage-stamp height. Outlook plate uses `outlookPlateHeight`.
  static let teaserHeight: CGFloat = 72
  /// Today Outlook plate map. Taller than the 72pt stamp; pills overlay so
  /// Your News can still peek the header on iPhone 16.
  static let outlookPlateHeight: CGFloat = 168
  /// Buried National teaser — same CONUS floor Live uses when local is dry.
  static var previewZoom: Double { RadarLiveCameraPolicy.conusZoom }
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

  /// Honor the Live slider (and the one-time 0.95→0.76 migrate). Do not
  /// force the old factory 0.95 on the Outlook teaser.
  static var previewOpacity: Double { RadarPreferences.radarOpacity }

  /// 72pt snapshot is not an interactive map. Radar tab keeps Mapbox chrome.
  /// Logo/attribution `visibility` is Restricted SPI — hide the views after
  /// options so `updateOrnaments` cannot unhide them, and park them off-canvas.
  static func configureTeaser(_ mapView: MapView) {
    mapView.isUserInteractionEnabled = false
    mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    mapView.ornaments.options.compass.visibility = .hidden
    mapView.ornaments.options.scaleBar.visibility = .hidden
    mapView.ornaments.options.logo.margins = CGPoint(x: 8, y: -80)
    mapView.ornaments.options.attributionButton.margins = CGPoint(x: 8, y: -80)
    mapView.ornaments.logoView.isHidden = true
    mapView.ornaments.attributionButton.isHidden = true
  }
}

/// Non-interactive Mapbox Dark + the same MapsGL NWS reflectivity Live uses.
private struct RadarPreviewMapboxMap: UIViewRepresentable {
  let center: CLLocationCoordinate2D
  var showsFuture: Bool = false

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
      frame: CGRect(x: 0, y: 0, width: 400, height: RadarPreviewSource.outlookPlateHeight),
      mapInitOptions: options
    )
    if mapView.contentScaleFactor.isNaN || mapView.contentScaleFactor <= 0 {
      mapView.contentScaleFactor = scale
    }
    RadarPreviewSource.configureTeaser(mapView)
    mapView.mapboxMap.setCamera(
      to: CameraOptions(center: center, zoom: RadarPreviewSource.previewZoom)
    )
    try? mapView.mapboxMap.setProjection(StyleProjection(name: .mercator))
    RadarPreviewSource.previewBaseMap.applyQuietWorkstation(to: mapView)

    let coordinator = context.coordinator
    coordinator.showsFuture = showsFuture
    coordinator.host.onLayerStateChange = { [weak coordinator] in
      guard let coordinator else { return }
      coordinator.host.syncPreview(
        opacity: RadarPreviewSource.previewOpacity,
        future: coordinator.showsFuture
      )
    }
    mapView.mapboxMap.onStyleLoaded.observe { [weak mapView, weak coordinator] _ in
      guard let mapView, let coordinator else { return }
      coordinator.attachRain(to: mapView)
    }.store(in: &coordinator.styleObservers)
    if mapView.mapboxMap.isStyleLoaded {
      coordinator.attachRain(to: mapView)
    }
    return mapView
  }

  func updateUIView(_ mapView: MapView, context: Context) {
    context.coordinator.showsFuture = showsFuture
    let current = mapView.mapboxMap.cameraState.center
    let moved =
      abs(current.latitude - center.latitude) > 0.01
      || abs(current.longitude - center.longitude) > 0.01
    if moved {
      mapView.mapboxMap.setCamera(
        to: CameraOptions(center: center, zoom: RadarPreviewSource.previewZoom)
      )
    }
    context.coordinator.host.syncPreview(
      opacity: RadarPreviewSource.previewOpacity,
      future: showsFuture
    )
  }

  static func dismantleUIView(_ uiView: MapView, coordinator: Coordinator) {
    coordinator.host.detach()
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  @MainActor
  final class Coordinator {
    var styleObservers = Set<AnyCancelable>()
    var showsFuture = false
    let host: MapsGLRadarHost = {
      let host = MapsGLRadarHost()
      host.paintsStormcells = false
      return host
    }()

    func attachRain(to mapView: MapView) {
      RadarPreviewSource.configureTeaser(mapView)
      RadarPreviewSource.previewBaseMap.applyQuietWorkstation(to: mapView)
      host.syncPreview(opacity: RadarPreviewSource.previewOpacity, future: showsFuture)
      host.attach(to: mapView)
    }
  }
}

/// Non-interactive Mapbox Dark + newest Live National PNG tiles (IEM / RainViewer / MRMS / OWM).
/// Used when MapsGL keys are missing — same family Live National paints.
private struct RadarPreviewNationalTileMap: UIViewRepresentable {
  let center: CLLocationCoordinate2D
  var frame: RadarFrame?

  func makeUIView(context: Context) -> MapView {
    if let token = DeveloperAPIKey.mapbox, !token.isEmpty {
      MapboxOptions.accessToken = token
    }
    IEMN0BTileInterceptor.install()
    let scale = max(1.0, Double(UIScreen.main.scale))
    let options = MapInitOptions(
      mapOptions: MapOptions(pixelRatio: CGFloat(scale)),
      styleURI: RadarPreviewSource.previewBaseMap.styleURI
    )
    let mapView = MapView(
      frame: CGRect(x: 0, y: 0, width: 400, height: RadarPreviewSource.outlookPlateHeight),
      mapInitOptions: options
    )
    if mapView.contentScaleFactor.isNaN || mapView.contentScaleFactor <= 0 {
      mapView.contentScaleFactor = scale
    }
    RadarPreviewSource.configureTeaser(mapView)
    mapView.mapboxMap.setCamera(
      to: CameraOptions(center: center, zoom: RadarPreviewSource.previewZoom)
    )
    try? mapView.mapboxMap.setProjection(StyleProjection(name: .mercator))
    RadarPreviewSource.previewBaseMap.applyQuietWorkstation(to: mapView)

    let coordinator = context.coordinator
    coordinator.pendingFrame = frame
    mapView.mapboxMap.onStyleLoaded.observe { [weak mapView] _ in
      guard let mapView else { return }
      RadarPreviewSource.configureTeaser(mapView)
      RadarPreviewSource.previewBaseMap.applyQuietWorkstation(to: mapView)
      coordinator.installRaster(on: mapView)
    }.store(in: &coordinator.styleObservers)
    if mapView.mapboxMap.isStyleLoaded {
      coordinator.installRaster(on: mapView)
    }
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
    context.coordinator.pendingFrame = frame
    if mapView.mapboxMap.isStyleLoaded {
      context.coordinator.installRaster(on: mapView)
    }
  }

  static func dismantleUIView(_ uiView: MapView, coordinator: Coordinator) {
    coordinator.removeRaster(from: uiView)
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  @MainActor
  final class Coordinator {
    static let sourceID = "teaser-national"
    static let layerID = "teaser-national-layer"

    var styleObservers = Set<AnyCancelable>()
    var pendingFrame: RadarFrame?
    var appliedTileKey: String?

    func installRaster(on mapView: MapView) {
      guard let frame = pendingFrame, !frame.tileURLTemplates.isEmpty else { return }
      if appliedTileKey == frame.tileKey,
        mapView.mapboxMap.sourceExists(withId: Self.sourceID)
      {
        return
      }
      removeRaster(from: mapView)
      do {
        var source = RasterSource(id: Self.sourceID)
        source.tiles = frame.tileURLTemplates
        source.tileSize = frame.provider == .xweather ? 512 : 256
        source.minzoom = 0
        source.maxzoom = MapsGLRadarPalette.displayMaxZoom(
          provider: frame.provider, paintsPolarRadials: false)
        source.prefetchZoomDelta = 1
        try mapView.mapboxMap.addSource(source)

        var layer = RasterLayer(id: Self.layerID, source: Self.sourceID)
        layer.rasterFadeDuration = .constant(0)
        layer.rasterEmissiveStrength = .constant(1)
        layer.rasterOpacity = .constant(RadarPreviewSource.previewOpacity)
        layer.rasterSaturation = .constant(0)
        layer.rasterContrast = .constant(0)
        layer.rasterBrightnessMin = .constant(0)
        layer.rasterHueRotate = .constant(0)
        let nearest = MapsGLRadarPalette.usesNearestResampling(
          provider: frame.provider,
          isFuture: frame.kind == .forecastPrecipitation,
          cameraZoom: RadarPreviewSource.previewZoom
        )
        layer.rasterResampling = .constant(nearest ? .nearest : .linear)
        let position = RadarBaseMapStyle.polarUnderlayLayerPosition(on: mapView)
        try mapView.mapboxMap.addLayer(layer, layerPosition: position)
        appliedTileKey = frame.tileKey
      } catch {
        radarLog("[Radar] Today National teaser tiles failed: \(error)")
      }
    }

    func removeRaster(from mapView: MapView) {
      if mapView.mapboxMap.layerExists(withId: Self.layerID) {
        try? mapView.mapboxMap.removeLayer(withId: Self.layerID)
      }
      if mapView.mapboxMap.sourceExists(withId: Self.sourceID) {
        try? mapView.mapboxMap.removeSource(withId: Self.sourceID)
      }
      appliedTileKey = nil
    }
  }
}

/// Non-interactive Mapbox Dark + Level III polar gates (same host as Live Site Doppler).
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
      frame: CGRect(x: 0, y: 0, width: 400, height: RadarPreviewSource.outlookPlateHeight),
      mapInitOptions: options
    )
    if mapView.contentScaleFactor.isNaN || mapView.contentScaleFactor <= 0 {
      mapView.contentScaleFactor = scale
    }
    RadarPreviewSource.configureTeaser(mapView)
    mapView.mapboxMap.setCamera(
      to: CameraOptions(center: center, zoom: RadarPreviewSource.siteZoom)
    )
    try? mapView.mapboxMap.setProjection(StyleProjection(name: .mercator))
    RadarPreviewSource.previewBaseMap.applyQuietWorkstation(to: mapView)
    let coordinator = context.coordinator
    let sweep = self.sweep
    mapView.mapboxMap.onStyleLoaded.observe { [weak mapView] _ in
      guard let mapView else { return }
      RadarPreviewSource.configureTeaser(mapView)
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
        opacity: Float(RadarPreviewSource.previewOpacity),
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
