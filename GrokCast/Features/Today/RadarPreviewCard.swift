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
    Button {
      Haptic.impact(.medium)
      store.selectedTab = .radar
    } label: {
      VStack(alignment: .leading, spacing: 0) {
        radarMapSection
        radarInfoBar
      }
      .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadius))
      .overlay(
        RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadius)
          .stroke(DesignTokens.Palette.cardStroke, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .task { await loadLatestRadarFrame() }
  }

  private var radarMapSection: some View {
    ZStack(alignment: .topLeading) {
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

      VStack {
        Spacer()
        LinearGradient(
          colors: [.clear, DesignTokens.Palette.bgPrimary.opacity(0.8)],
          startPoint: .top,
          endPoint: .bottom
        )
        .frame(height: 40)
      }

      Text("LIVE RADAR")
        .font(.caption2.weight(.heavy))
        .tracking(1.2)
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(DesignTokens.Spacing.space12)
    }
    .frame(height: 160)
  }

  private var radarInfoBar: some View {
    HStack {
      HStack(spacing: DesignTokens.Spacing.space8) {
        Image(systemName: "dot.radiowaves.left.and.right")
          .font(.subheadline)
          .foregroundStyle(DesignTokens.Palette.accent)

        Text("Radar")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(DesignTokens.Palette.textPrimary)
      }

      Spacer()

      HStack(spacing: DesignTokens.Spacing.space4) {
        Text("Open")
          .font(.caption.weight(.medium))
          .foregroundStyle(DesignTokens.Palette.textTertiary)
        Image(systemName: "chevron.right")
          .font(.caption2)
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }
    }
    .padding(.horizontal, DesignTokens.Spacing.space16)
    .padding(.vertical, DesignTokens.Spacing.space12)
    .background(DesignTokens.Palette.cardBackground)
  }

  private func loadLatestRadarFrame() async {
    let live = await RainViewerRadarService.loadLiveFrames()
    if let latest = live.last, let template = latest.tileURLTemplates.first {
      radarTileTemplate = template
    }
  }
}

private struct RadarSnapshotMap: UIViewRepresentable {
  let center: CLLocationCoordinate2D
  var radarTileTemplate: String?

  func makeUIView(context: Context) -> MKMapView {
    let mapView = MKMapView()
    mapView.isUserInteractionEnabled = false
    mapView.showsUserLocation = false
    mapView.mapType = .mutedStandard
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
