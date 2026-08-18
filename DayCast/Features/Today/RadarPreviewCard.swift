import MapKit
import SwiftUI

struct RadarPreviewCard: View {
  @Environment(WeatherStore.self) private var store
  @State private var radarTileTemplate: String?

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
      .task(id: store.currentLocation?.id) { await loadLatestRadarFrame() }
  }

  private var radarMap: some View {
    Group {
      if let coord = coordinate {
        RadarSnapshotMap(
          center: coord,
          radarTileTemplate: radarTileTemplate
        )
        .allowsHitTesting(false)
      } else {
        Rectangle()
          .fill(DesignTokens.Palette.bgSecondary)
      }
    }
  }

  private func loadLatestRadarFrame() async {
    radarTileTemplate = RadarPreviewSource.latestLiveTileTemplate()
  }
}

/// Today’s snapshot uses the same Xweather live mosaic as Radar. RainViewer’s
/// public JSON is dead, so a RainViewer preview would stay blank in a storm.
enum RadarPreviewSource {
  static func latestLiveTileTemplate() -> String? {
    guard XweatherRadarService.mapsAuthConfigured else { return nil }
    guard let frame = XweatherRadarService.loadRecentFrames(maxFrames: 1).last else {
      return nil
    }
    return XweatherRadarService.tileURLs(
      layer: frame.layer, offset: frame.offset, retina: false
    )?.first
  }
}

private struct RadarSnapshotMap: UIViewRepresentable {
  let center: CLLocationCoordinate2D
  var radarTileTemplate: String?

  func makeUIView(context: Context) -> MKMapView {
    let mapView = MKMapView()
    mapView.isUserInteractionEnabled = false
    mapView.showsUserLocation = false
    mapView.mapType = .hybrid
    mapView.overrideUserInterfaceStyle = .dark
    mapView.pointOfInterestFilter = .excludingAll
    mapView.delegate = context.coordinator

    let region = MKCoordinateRegion(
      center: center,
      span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 3.0)
    )
    mapView.setRegion(region, animated: false)

    if let template = radarTileTemplate {
      addRadarOverlay(to: mapView, template: template)
    }

    return mapView
  }

  func updateUIView(_ mapView: MKMapView, context: Context) {
    let currentCenter = mapView.centerCoordinate
    let needsRecenter =
      abs(currentCenter.latitude - center.latitude) > 0.01
      || abs(currentCenter.longitude - center.longitude) > 0.01
    if needsRecenter {
      let region = MKCoordinateRegion(
        center: center,
        span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 3.0)
      )
      mapView.setRegion(region, animated: false)
    }

    let hasOverlay = mapView.overlays.contains { $0 is MKTileOverlay }
    if let template = radarTileTemplate, !hasOverlay {
      addRadarOverlay(to: mapView, template: template)
    }
  }

  private func addRadarOverlay(to mapView: MKMapView, template: String) {
    let overlay = MKTileOverlay(urlTemplate: template)
    overlay.canReplaceMapContent = false
    mapView.addOverlay(overlay, level: .aboveLabels)
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  class Coordinator: NSObject, MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
      if let tileOverlay = overlay as? MKTileOverlay {
        let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
        renderer.alpha = 0.7
        return renderer
      }
      return MKOverlayRenderer(overlay: overlay)
    }
  }
}
