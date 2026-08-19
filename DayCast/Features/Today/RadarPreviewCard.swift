import CoreLocation
import MapboxMaps
import SwiftUI
import UIKit

struct RadarPreviewCard: View {
  @Environment(WeatherStore.self) private var store

  private var coordinate: CLLocationCoordinate2D? {
    guard let loc = store.currentLocation else { return nil }
    return CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
  }

  var body: some View {
    radarMap
      .frame(height: 160)
      .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadius))
      .overlay(
        RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadius)
          .stroke(DesignTokens.Palette.cardStroke, lineWidth: 1)
      )
  }

  @ViewBuilder
  private var radarMap: some View {
    if let coord = coordinate,
      RadarPreviewSource.usesMapsGL(keysPresent: MapsGLRadarHost.keysPresent)
    {
      RadarPreviewMapboxMap(center: coord)
        .allowsHitTesting(false)
    } else {
      Rectangle()
        .fill(DesignTokens.Palette.bgSecondary)
    }
  }
}

/// Today’s snapshot must paint the same MapsGL rain as Live, on Light.
/// PNG mosaic is a different scale — do not use it when MapsGL is the Live paint.
enum RadarPreviewSource {
  static let previewBaseMap = RadarBaseMapStyle.light
  /// Matches Live's opening camera so nearby cells fit the 160pt card.
  static let previewZoom: Double = 4.5

  static func usesMapsGL(keysPresent: Bool) -> Bool {
    MapsGLRadarPalette.shouldUseMapsGL(
      overlayOn: true, isSiteProduct: false, keysPresent: keysPresent
    )
  }
}

/// Non-interactive Mapbox Light + the same MapsGL TWC-green layer Live uses.
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
    let host = MapsGLRadarHost()
  }
}
