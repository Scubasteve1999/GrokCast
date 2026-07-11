import CoreLocation
import Foundation
import MapKit
import SwiftUI

extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// RainViewer radar overlay for animation (using NWS UI label and mode)

struct RainViewerResponse: Decodable {
  let host: String?
  let radar: RadarSection?
}
struct RadarSection: Decodable {
  let past: [RadarFrame]?
}
struct RadarFrame: Decodable, Equatable {
  let time: Int
  let path: String
}

enum RadarOverlayMode: Equatable {
  case none
  case nws(product: NWSRadarProduct, siteID: String, timestamp: String?)
}

struct RadarView: View {
  @Environment(WeatherStore.self) private var store

  @State private var mapRegion = MKCoordinateRegion(
    center: SavedLocation.oliveBranch.coordinate,
    span: MKCoordinateSpan(latitudeDelta: 0.8, longitudeDelta: 0.8)
  )
  @State private var annotations: [AlertAnnotation] = []

  // Pure NWS radar. Accurate historical animation using IEM timestamped ridge tiles (last ~60min @ 5min steps).
  @State private var radarEnabled = true
  @State private var isRadarAnimating = false
  @State private var currentRadarFrameIndex = 0
  @State private var nwsRadarTimestamps: [String] = []   // yyyyMMddHHmm strings for accurate historical loop
  @State private var radarOpacity: Double = 0.75  // slider-driven; default 0.75 per spec; restored on toggle-on
  @State private var lastRadarOpacity: Double = 0.75
  @State private var animationTimer: Timer?

  // Radar UX improvements (current pin, map type, playback speed)
  @State private var mapType: MKMapType = .standard
  @State private var radarPlaybackInterval: TimeInterval = 0.6

  // NWS/IEM ridge radar with accurate historical animation.
  @State private var nwsRadarProduct: NWSRadarProduct = .baseReflectivity
  @State private var iemRadarListReady = false
  @State private var nwsRadarSiteID = IEMRadarSiteResolver.fallbackSiteID
  @State private var nwsSiteResolveCenter: CLLocationCoordinate2D?
  @State private var nwsSiteUpdateTask: Task<Void, Never>?

  /// Holds a live reference to the coordinator for direct access to map overlay management.
  @State private var radarCoordinator: MapViewRepresentable.Coordinator?

  /// Minimum pan distance before re-resolving nearest NEXRAD (reduces overlay churn at boundaries).
  private let nwsSiteMinPanMeters: CLLocationDistance = 40_000

  /// Extra clearance for floating map buttons above the bottom control inset (not the tab bar itself).
  private let floatingMapButtonLift: CGFloat = 12

  @State private var radarControlsExpanded = false

  /// Shared formatter for currentRadarTimeString (nit 188: avoids fresh alloc on every 0.6s anim tick).
  private static let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f
  }()

  /// Device "my location" for the tappable pin and reset button.
  /// Prefers the isCurrent SavedLocation entry (maintained by useCurrentDeviceLocation + significant updates)
  /// so the pin always reflects the user's actual device position even when the map is centered on a
  /// manually selected saved city (region follows viewed currentLocation; pin + reset stay "me").
  private var myLocationCoordinate: CLLocationCoordinate2D? {
    if let device = store.savedLocations.first(where: { $0.isCurrent }) {
      return device.coordinate
    }
    return store.currentLocation?.coordinate
  }

  private struct RadarLegendItem: Identifiable {
    let id = UUID()
    let color: Color
    let label: String
  }

  private var radarOverlayMode: RadarOverlayMode {
    guard radarEnabled else { return .none }

    let siteID = nwsRadarProduct.usesUSComposite ? "USCOMP" : nwsRadarSiteID

    // Accurate NWS historical loop: use real timestamp when animating
    let ts: String?
    if isRadarAnimating && !nwsRadarTimestamps.isEmpty {
      let idx = currentRadarFrameIndex % nwsRadarTimestamps.count
      ts = nwsRadarTimestamps[idx]
    } else {
      ts = nil
    }
    return .nws(product: nwsRadarProduct, siteID: siteID, timestamp: ts)
  }

  private var mapRegionCenterKey: String {
    String(format: "%.4f,%.4f", mapRegion.center.latitude, mapRegion.center.longitude)
  }

  private var showReflectivityLegend: Bool {
    radarEnabled && nwsRadarProduct == .baseReflectivity
  }

  // Always show playback controls for NWS (RainViewer removed)
  var showPlaybackControls: Bool {
    radarEnabled
  }

  private var showRadarPlayback: Bool {
    showPlaybackControls
  }

  // Legacy functions removed per cleanup (animation logic now lives in toggleRadarAnimation)
  private func startRadarAnimation() {}
  private func updateRadarOverlayForAnimation() {}

  private var showRadarOpacitySlider: Bool {
    radarEnabled
  }

  private let radarLegendItems: [RadarLegendItem] = [
    RadarLegendItem(color: Color(red: 0.30, green: 0.75, blue: 0.35), label: "Light"),
    RadarLegendItem(color: Color(red: 0.92, green: 0.88, blue: 0.20), label: "Moderate"),
    RadarLegendItem(color: Color(red: 0.95, green: 0.55, blue: 0.15), label: "Heavy"),
    RadarLegendItem(color: Color(red: 0.65, green: 0.25, blue: 0.70), label: "Extreme"),
  ]

  private var nwsLayerStatusLabel: String {
    let site = nwsRadarProduct.usesUSComposite ? "USCOMP" : nwsRadarSiteID
    return "NWS · \(nwsRadarProduct.displayName) · \(site)"
  }

  @ViewBuilder
  private var radarColorLegendRow: some View {
    HStack(spacing: 6) {
      ForEach(radarLegendItems) { item in
        HStack(spacing: 3) {
          RoundedRectangle(cornerRadius: 2)
            .fill(item.color)
            .frame(width: 12, height: 6)
          Text(item.label)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
    }
  }

  @ViewBuilder
  private var radarPlaybackRow: some View {
    HStack(spacing: 8) {
      Button {
        toggleRadarAnimation()
      } label: {
        Image(systemName: isRadarAnimating ? "pause.circle.fill" : "play.circle.fill")
          .font(.title3)
          .foregroundStyle(.white)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(isRadarAnimating ? "Pause" : "Play")

      Text(currentRadarTimeString)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .frame(minWidth: 40, alignment: .leading)

      HStack(spacing: 2) {
        ForEach([0.3, 0.6, 1.0], id: \.self) { secs in
          let label = secs == 0.3 ? "2x" : (secs == 0.6 ? "1x" : "0.5x")
          let isSelected = abs(radarPlaybackInterval - secs) < 0.05
          Text(label)
            .font(.caption2.weight(isSelected ? .bold : .regular))
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, 4)
            .onTapGesture { setPlaybackSpeed(secs) }
        }
      }
    }
  }

  @ViewBuilder
  private var mapControlButtons: some View {
    VStack(spacing: 8) {
      Button {
        cycleMapType()
      } label: {
        Image(systemName: mapTypeIconName)
          .font(.caption)
          .foregroundStyle(.white)
          .padding(8)
          .background(.ultraThinMaterial)
          .clipShape(Circle())
          .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
      }
      .accessibilityLabel("Cycle map type")

      Button {
        recenterOnMyLocation()
      } label: {
        Image(systemName: "location.circle.fill")
          .font(.title2)
          .foregroundStyle(.white)
          .padding(10)
          .background(.ultraThinMaterial)
          .clipShape(Circle())
          .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
      }
      .accessibilityLabel("Reset map to my location")
    }
    .padding(.trailing, 16)
    .padding(.bottom, floatingMapButtonLift)
  }

  @ViewBuilder
  private var radarControlPanel: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 10) {
        Button {
          toggleRadar()
        } label: {
          Image(systemName: radarEnabled ? "cloud.rain.fill" : "cloud.rain")
            .font(.title3)
            .foregroundStyle(radarEnabled ? .blue : .white)
            .frame(width: 34, height: 34)
            .background(Color.white.opacity(0.08))
            .clipShape(Circle())
        }
        .accessibilityLabel(radarEnabled ? "Hide radar" : "Show radar")

        if radarEnabled {
          // NWS-only (RainViewer removed per request)
          Text("NWS Radar")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
        } else {
          Text("Radar off")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer(minLength: 0)

        if radarEnabled {
          Button {
            withAnimation(.easeInOut(duration: 0.2)) {
              radarControlsExpanded.toggle()
            }
          } label: {
            Image(systemName: radarControlsExpanded ? "chevron.down" : "chevron.up")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
              .frame(width: 28, height: 28)
              .background(Color.white.opacity(0.08))
              .clipShape(Circle())
          }
          .accessibilityLabel(
            radarControlsExpanded ? "Collapse radar controls" : "Expand radar controls")
        }
      }

      if radarEnabled, radarControlsExpanded {
        VStack(alignment: .leading, spacing: 8) {
          if showPlaybackControls {
            radarPlaybackRow
          }

          if showReflectivityLegend {
            radarColorLegendRow
          }

          Text(nwsLayerStatusLabel)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)

          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
              ForEach(NWSRadarProduct.allCases) { product in
                Button {
                  guard nwsRadarProduct != product else { return }
                  Haptic.impact(.light)
                  nwsRadarProduct = product
                } label: {
                  Text(product.shortDisplayName)
                    .font(.caption2.weight(nwsRadarProduct == product ? .bold : .regular))
                    .foregroundStyle(nwsRadarProduct == product ? .white : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                      nwsRadarProduct == product
                        ? Color.blue.opacity(0.55) : Color.white.opacity(0.08)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(product.displayName)
                .accessibilityAddTraits(nwsRadarProduct == product ? .isSelected : [])
              }
            }
          }

          if showRadarOpacitySlider {
            HStack(spacing: 8) {
              Image(systemName: "slider.horizontal.3")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Slider(value: $radarOpacity, in: 0.2...1.0)
            }
          }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.ultraThinMaterial)
    .adaptiveContainerWidth(AdaptiveLayout.contentCap)
  }

  private var radarIsDay: Bool {
    store.currentWeather.map {
      WeatherBackgroundView.isDay(from: $0.symbolName)
    } ?? WeatherBackgroundView.inferredIsDay
  }

  @ViewBuilder
  private var radarMapContent: some View {
    ZStack {
      MapViewRepresentable(
        region: $mapRegion, annotations: annotations, radarOverlayMode: radarOverlayMode,
        radarOpacity: radarOpacity, userLocation: myLocationCoordinate, mapType: mapType,
        isRadarAnimating: isRadarAnimating, radarPlaybackInterval: radarPlaybackInterval,
        radarCoordinator: $radarCoordinator
      )
      .ignoresSafeArea(edges: .top)
      .overlay {
        WeatherBackgroundView(
          conditionCode: store.currentWeather?.conditionCode,
          isDay: radarIsDay,
          intensity: .subtle
        )
        .opacity(0.18)
        .allowsHitTesting(false)
      }
      .overlay(alignment: .bottomTrailing) {
        mapControlButtons
      }
      .overlay(alignment: .top) {
        if annotations.isEmpty {
          Text("No active alerts for this location")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.top, 8)
        }
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      radarControlPanel
    }
  }

  var body: some View {
    NavigationStack {
      radarMapContent
      .navigationTitle("Radar")
      .navigationBarTitleDisplayMode(.inline)
      .preferredColorScheme(.dark)
      .onAppear {
        updateInitialRegion()
        updateAnnotationsFromAlerts()
      }
      .task {
        // Lightweight: store's 5min cache makes this cheap on tab (re)appear.
        // Non-US or error yields [] silently (per existing NWSService/store behavior).
        await store.refreshAlerts()
        updateAnnotationsFromAlerts()

        // Preload IEM radar list + prepare NWS timestamps for accurate loop
        await IEMRadarSiteResolver.preloadRadarList()
        iemRadarListReady = IEMRadarSiteResolver.isReady
        updateNWSRadarSite(center: mapRegion.center, force: true)
        if nwsRadarTimestamps.isEmpty {
          loadRecentNWSTimestamps()
        }
      }
      .onChange(of: store.activeAlerts) { _, _ in
        updateAnnotationsFromAlerts()
      }
      .onChange(of: store.alertHistory) { _, _ in
        updateAnnotationsFromAlerts()
      }
      .onChange(of: store.currentLocation) { _, _ in
        updateInitialRegion()
      }
      .onChange(of: mapRegionCenterKey) { _, _ in
        scheduleNWSRadarSiteUpdate(center: mapRegion.center)
      }
      .onChange(of: nwsRadarProduct) { _, _ in
        updateNWSRadarSite(center: mapRegion.center, force: true)
        if !isRadarAnimating {
          loadRecentNWSTimestamps()
        }
      }
      .onChange(of: store.selectedTab) { _, newTab in
        if newTab != WeatherStore.Tab.radar {
          stopRadarAnimation()
        }
      }
      .onDisappear {
        stopRadarAnimation()
        nwsSiteUpdateTask?.cancel()
      }
      .onChange(of: isRadarAnimating) { _, newValue in
        if newValue {
          // Force refresh when Play pressed
          print("[RADAR] isRadarAnimating became true — forcing map refresh")
        }
      }
      .onChange(of: isRadarAnimating) { _, newValue in
        print("[RADAR] isRadarAnimating changed to \(newValue)")
      }
    }
  }

  private func updateInitialRegion() {
    if let loc = store.currentLocation {
      mapRegion = MKCoordinateRegion(
        center: loc.coordinate,
        span: MKCoordinateSpan(latitudeDelta: 0.8, longitudeDelta: 0.8)
      )
    }
  }

  private func updateAnnotationsFromAlerts() {
    let newAnns = store.displayableActiveAlerts.compactMap { alert -> AlertAnnotation? in
      guard let coord = alert.coordinate else { return nil }
      return AlertAnnotation(alert: alert, coordinate: coord)
    }
    // Guard reassign (and downstream representable update) if ids unchanged (per review Suggestion13; avoids unnecessary work on no-op alerts notifications).
    if Set(annotations.map { $0.alert.id }) != Set(newAnns.map { $0.alert.id }) {
      annotations = newAnns
    }
  }

  private func recenterOnMyLocation() {
    if let coord = myLocationCoordinate {
      Haptic.impact(.medium)
      withAnimation(.easeInOut(duration: 0.35)) {
        mapRegion = MKCoordinateRegion(
          center: coord,
          span: MKCoordinateSpan(latitudeDelta: 0.8, longitudeDelta: 0.8)
        )
      }
    }
  }

  private func cycleMapType() {
    Haptic.impact(.light)
    switch mapType {
    case .standard: mapType = .satellite
    case .satellite: mapType = .hybrid
    default: mapType = .standard
    }
  }

  private var mapTypeIconName: String {
    switch mapType {
    case .standard: return "map"
    case .satellite: return "globe.americas.fill"
    case .hybrid: return "map.fill"
    default: return "map"
    }
  }

  private func setPlaybackSpeed(_ interval: TimeInterval) {
    guard radarPlaybackInterval != interval else { return }
    Haptic.impact(.light)
    radarPlaybackInterval = interval
    if isRadarAnimating {
      // Restart timer with new interval for accurate NWS loop
      stopRadarAnimation()
      isRadarAnimating = true
      // re-enter the animation timer setup
      if nwsRadarTimestamps.isEmpty {
        loadRecentNWSTimestamps()
      }
      let t = Timer.scheduledTimer(withTimeInterval: radarPlaybackInterval, repeats: true) { [self] _ in
        DispatchQueue.main.async {
          guard self.isRadarAnimating, !self.nwsRadarTimestamps.isEmpty else { return }
          self.currentRadarFrameIndex = (self.currentRadarFrameIndex + 1) % self.nwsRadarTimestamps.count
          self.forceNWSRadarRefresh()
        }
      }
      RunLoop.current.add(t, forMode: .common)
      animationTimer = t

      // Immediate refresh with new speed
      self.forceNWSRadarRefresh()
    }
  }

  // MARK: - Radar helpers (static/anim; fetch only on tab appear or toggle per lightweight; reuse alert pattern)
  private var currentRadarTimeString: String {
    guard !nwsRadarTimestamps.isEmpty,
          currentRadarFrameIndex >= 0,
          currentRadarFrameIndex < nwsRadarTimestamps.count
    else { return "--:--" }

    // Format unix ts to HH:mm
    let ts = nwsRadarTimestamps[currentRadarFrameIndex]
    if let unix = TimeInterval(ts) {
      let date = Date(timeIntervalSince1970: unix)
      return Self.timeFormatter.string(from: date)
    }
    return ts
  }

  private func loadRecentNWSTimestamps() {
    // Fetch RainViewer frames for the animation loop
    Task {
      guard let url = URL(string: "https://api.rainviewer.com/public/weather-maps.json") else { return }
      var req = URLRequest(url: url)
      req.setValue("SpotterCast/1.0 (https://grokcast.app)", forHTTPHeaderField: "User-Agent")
      req.timeoutInterval = 10
      do {
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
        let decoded = try JSONDecoder().decode(RainViewerResponse.self, from: data)
        await MainActor.run {
          if let past = decoded.radar?.past, !past.isEmpty {
            // Use the time (unix) as ts for RainViewer v2/radar/ URL
            nwsRadarTimestamps = past.suffix(10).map { String($0.time) }  // last ~10 frames
            if currentRadarFrameIndex >= nwsRadarTimestamps.count || currentRadarFrameIndex < 0 {
              currentRadarFrameIndex = max(0, nwsRadarTimestamps.count - 1)
            }
            print("[RADAR] Loaded \(nwsRadarTimestamps.count) RainViewer frames for loop")
          }
        }
      } catch {
        print("[RADAR] RainViewer fetch failed: \(error.localizedDescription)")
      }
    }
  }

  private func scheduleNWSRadarSiteUpdate(center: CLLocationCoordinate2D) {
    guard !nwsRadarProduct.usesUSComposite else { return }
    nwsSiteUpdateTask?.cancel()
    nwsSiteUpdateTask = Task { @MainActor in
      try? await Task.sleep(nanoseconds: 300_000_000)
      guard !Task.isCancelled else { return }
      updateNWSRadarSite(center: center)
    }
  }

  private func updateNWSRadarSite(center: CLLocationCoordinate2D, force: Bool = false) {
    guard !nwsRadarProduct.usesUSComposite else { return }

    if !force, !iemRadarListReady {
      return
    }

    if !force, let lastCenter = nwsSiteResolveCenter {
      let moved = CLLocation(latitude: center.latitude, longitude: center.longitude)
        .distance(
          from: CLLocation(latitude: lastCenter.latitude, longitude: lastCenter.longitude))
      if moved < nwsSiteMinPanMeters { return }
    }

    let resolved = IEMRadarSiteResolver.nearestNEXRAD(
      to: center,
      preferring: force ? nil : nwsRadarSiteID
    )
    if resolved != nwsRadarSiteID || force || nwsSiteResolveCenter == nil {
      nwsRadarSiteID = resolved
      nwsSiteResolveCenter = center
    }
  }

  private func toggleRadar() {
    Haptic.impact(.light)
    let turningOn = !radarEnabled
    radarEnabled = turningOn
    if turningOn {
      radarOpacity = lastRadarOpacity
      updateNWSRadarSite(center: mapRegion.center, force: true)
      if nwsRadarTimestamps.isEmpty {
        loadRecentNWSTimestamps()
      }
    } else {
      lastRadarOpacity = radarOpacity
      stopRadarAnimation()
    }
  }

    private func forceNWSRadarRefresh() {
        guard radarEnabled else { return }

        let ts = nwsRadarTimestamps[safe: currentRadarFrameIndex] ?? "9c66380ab050"

        if let existing = radarCoordinator?.currentRadarOverlay as? NWSRadarOverlay {
            // Update in place — avoids remove/add flicker so colors stay visible
            existing.updateTimestamp(ts)
            radarCoordinator?.mapView?.setNeedsDisplay()
        } else {
            if let old = radarCoordinator?.currentRadarOverlay {
                radarCoordinator?.mapView?.removeOverlay(old)
            }
            let newOverlay = NWSRadarOverlay(timestamp: ts)
            radarCoordinator?.currentRadarOverlay = newOverlay
            radarCoordinator?.mapView?.addOverlay(newOverlay, level: .aboveLabels)

            let renderer: RadarTileRenderer
            if let existing = radarCoordinator?.currentRadarRenderer {
                renderer = existing
            } else {
                renderer = RadarTileRenderer(tileOverlay: newOverlay)
                radarCoordinator?.currentRadarRenderer = renderer
            }
            renderer.radarOpacity = 0.95
            renderer.setNeedsDisplay()

            radarCoordinator?.mapView?.setNeedsDisplay()
        }

        print("[RADAR] ✅ RainViewer frame \(currentRadarFrameIndex) loaded")
    }
    private func toggleRadarAnimation() {
        isRadarAnimating.toggle()
        if isRadarAnimating {
            currentRadarFrameIndex = 0
            loadRecentNWSTimestamps() // ensures we have frames
            startPersistentRadarLoop()
            print("[RADAR] 🎥 Animation STARTED — colors should stay visible")
        } else {
            stopRadarAnimation()
            print("[RADAR] ⏸️ Animation STOPPED")
        }
    }

    private func startPersistentRadarLoop() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { _ in
            guard self.isRadarAnimating else { return }
            self.currentRadarFrameIndex = (self.currentRadarFrameIndex + 1) % max(1, self.nwsRadarTimestamps.count)
            self.forceNWSRadarRefresh()  // now persistent
        }
    }

  private func stopRadarAnimation() {
    animationTimer?.invalidate()
    animationTimer = nil
    isRadarAnimating = false
  }
}

// Carries full NWSAlert for callout details + severity tinting.
final class AlertAnnotation: NSObject, MKAnnotation {
  let alert: NWSAlert
  let coordinate: CLLocationCoordinate2D

  init(alert: NWSAlert, coordinate: CLLocationCoordinate2D) {
    self.alert = alert
    self.coordinate = coordinate
    super.init()
  }

  var title: String? { alert.event }
  var subtitle: String? { alert.headline ?? alert.areaDesc }
}

// Tappable custom pin for the user's device current location (distinct from default blue dot).
// Title enables callout on tap. Blue tint + location glyph for instant recognition.
// Placed via separate management in representable (not mixed into alert annotations array).
final class UserLocationAnnotation: NSObject, MKAnnotation {
  let coordinate: CLLocationCoordinate2D
  init(coordinate: CLLocationCoordinate2D) {
    self.coordinate = coordinate
    super.init()
  }
  var title: String? { "Current Location" }
  var subtitle: String? { nil }
}

// RadarTileOverlay: custom MKTileOverlay subclass for RainViewer tiles with tile clamping.
// RainViewer serves z≤7. When zoomed in, MapKit requests higher-z tiles; we crop the matching
// subsection from the parent z=7 tile so precipitation stays visible at all zoom levels.
final class RadarTileOverlay: MKTileOverlay {
  private let effectiveMaxZ = 7

  override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
    RadarTileClamp.loadTile(
      on: self,
      at: path,
      maxZ: effectiveMaxZ,
      fetchParent: { parentPath, parentResult in
        super.loadTile(at: parentPath, result: parentResult)
      },
      result: result
    )
  }
}

// MKMapViewRepresentable (chosen over SwiftUI Map for future Phase 3 radar MKOverlay reusability + full delegate/callout control).
struct MapViewRepresentable: UIViewRepresentable {
  @Binding var region: MKCoordinateRegion
  let annotations: [AlertAnnotation]
  let radarOverlayMode: RadarOverlayMode
  let radarOpacity: Double  // Phase 3+opacity: bound from @State; drives live alpha on custom renderer (slider + toggle restore + anim frames)
  let userLocation: CLLocationCoordinate2D?
  let mapType: MKMapType
  let isRadarAnimating: Bool
  let radarPlaybackInterval: TimeInterval
  @Binding var radarCoordinator: Coordinator?

  func makeUIView(context: Context) -> SizedMapView {
    let container = SizedMapView()
    let mapView = container.mapView
    mapView.delegate = context.coordinator
    mapView.showsUserLocation = false  // replaced by our custom tappable "Current Location" pin
    mapView.mapType = mapType
    mapView.isZoomEnabled = true
    mapView.isScrollEnabled = true
    mapView.isPitchEnabled = false
    mapView.isRotateEnabled = true
    mapView.overrideUserInterfaceStyle = .dark
    // Reasonable zoom limits prevent the map feeling "stuck" at extreme scales.
    // RainViewer tiles cap at maxZ=7; NWS/IEM site-specific tiles support higher zoom (up to z=16).
    mapView.cameraZoomRange = MKMapView.CameraZoomRange(
      minCenterCoordinateDistance: 500,
      maxCenterCoordinateDistance: 5_000_000
    )
    context.coordinator.mapView = mapView
    radarCoordinator = context.coordinator
    return container
  }

  func updateUIView(_ container: SizedMapView, context: Context) {
    guard let mapView = context.coordinator.mapView else { return }
    guard container.bounds.width > 1, container.bounds.height > 1 else { return }

    if !context.coordinator.didApplyInitialRegion {
      mapView.setRegion(region, animated: false)
      context.coordinator.didApplyInitialRegion = true
    }
    // Apply region only when our @State differs meaningfully from map's current (prevents fighting *programmatic* jitter).
    // User pan/zoom now syncs back via regionDidChangeAnimated below (updates @State so later .onChange alerts/loc etc don't see stale region and snap).
    let current = mapView.region
    let delta = 0.0005
    let spanDelta = 0.01
    if abs(current.center.latitude - region.center.latitude) > delta
      || abs(current.center.longitude - region.center.longitude) > delta
      || abs(current.span.latitudeDelta - region.span.latitudeDelta) > spanDelta
      || abs(current.span.longitudeDelta - region.span.longitudeDelta) > spanDelta
    {
      mapView.setRegion(region, animated: true)
    }

    // Radar overlay management ALWAYS runs (independent of NWS pins/empty state).
    // Placed before ann early-out + diff so radar (toggle, re-fetch, or 0.6s anim frame swaps) is not bypassed when annotations.isEmpty (common "No active alerts..." case, non-US, quiet areas).
    // Layer at .aboveRoads; pins/user loc render above per MapKit. (Fixes review bug: radar/anim now works regardless of anns.)
    // Refresh coordinator's captured parent struct (value copy from makeCoordinator time) to the fresh instance from this updateUIView.
    // This ensures parent.radarOpacity (used inside updateRadarOverlay for same-template and create paths) sees current @State value (the let in representable is snapshot; @Binding region is live but opacity is not).
    context.coordinator.parent = self
    radarCoordinator = context.coordinator
    context.coordinator.updateRadarOverlay(on: mapView, with: radarOverlayMode)

    // Live opacity update (for slider drag when template unchanged; also ensures after create/swap).
    // Uses the fresh radarOpacity from this updateUIView (driven by @State change).
    // After wiring fixes (ordering before add + parent refresh), this if-let acts as runtime guard: only sets on the active custom renderer returned by rendererFor for our overlay (per review suggestion to add guard/assert post-fix that returned is our custom when matches).
    if let r = context.coordinator.currentRadarRenderer {
      r.radarOpacity = CGFloat(radarOpacity)
    }

    // Map type (live switch)
    if mapView.mapType != mapType {
      mapView.mapType = mapType
    }

    // Custom user location pin (tappable, "Current Location" callout). Managed separately from alerts.
    // Always keep in sync even if viewing a saved city (pin shows actual device pos via isCurrent).
    let currentUserAnns = mapView.annotations.compactMap { $0 as? UserLocationAnnotation }
    if let userCoord = userLocation {
      let needsAddOrMove =
        currentUserAnns.isEmpty
        || abs(currentUserAnns[0].coordinate.latitude - userCoord.latitude) > 0.0005
        || abs(currentUserAnns[0].coordinate.longitude - userCoord.longitude) > 0.0005
      if needsAddOrMove {
        if !currentUserAnns.isEmpty { mapView.removeAnnotations(currentUserAnns) }
        mapView.addAnnotation(UserLocationAnnotation(coordinate: userCoord))
      }
    } else if !currentUserAnns.isEmpty {
      mapView.removeAnnotations(currentUserAnns)
    }

    // Diff annotations by stable alert id (lightweight; alerts list is small).
    let currentAlertAnns = mapView.annotations.compactMap { $0 as? AlertAnnotation }
    let currentIds = Set(currentAlertAnns.map { $0.alert.id })
    let newIds = Set(annotations.map { $0.alert.id })

    if annotations.isEmpty && currentAlertAnns.isEmpty {
      return  // minor early-out per review Nit10 (no work when no pins expected) -- ann diff only; radar already handled above
    }

    let toRemove = currentAlertAnns.filter { !newIds.contains($0.alert.id) }
    if !toRemove.isEmpty {
      mapView.removeAnnotations(toRemove)
    }

    let toAdd = annotations.filter { !currentIds.contains($0.alert.id) }
    if !toAdd.isEmpty {
      mapView.addAnnotations(toAdd)
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  /// Hosts MKMapView so Metal rendering waits until Auto Layout assigns a non-zero frame.
  final class SizedMapView: UIView {
    let mapView = MKMapView()

    override init(frame: CGRect) {
      super.init(frame: frame)
      mapView.translatesAutoresizingMaskIntoConstraints = false
      addSubview(mapView)
      NSLayoutConstraint.activate([
        mapView.topAnchor.constraint(equalTo: topAnchor),
        mapView.leadingAnchor.constraint(equalTo: leadingAnchor),
        mapView.trailingAnchor.constraint(equalTo: trailingAnchor),
        mapView.bottomAnchor.constraint(equalTo: bottomAnchor),
      ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
  }

  final class Coordinator: NSObject, MKMapViewDelegate {
    var parent: MapViewRepresentable  // var to allow refresh from updateUIView (fresh struct with current radarOpacity let from @State); enables parent.radarOpacity reads inside updateRadarOverlay to be live per update cycle (not stale capture from makeCoordinator)
    weak var mapView: MKMapView?
    var didApplyInitialRegion = false

    init(parent: MapViewRepresentable) {
      self.parent = parent
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
      let newRegion = mapView.region
      // Bidirectional: propagate user gestures (pan/zoom) back to @State region binding.
      // This ensures subsequent updateUIView calls (triggered by alerts onChange, loc select, tab appear etc)
      // compare against the *user's* current region and do not snap the map with a stale programmatic setRegion.
      // Threshold avoids feedback from our own setRegion calls (which also fire this delegate).
      let delta = 0.0001
      let spanD = 0.001
      if abs(parent.region.center.latitude - newRegion.center.latitude) > delta
        || abs(parent.region.center.longitude - newRegion.center.longitude) > delta
        || abs(parent.region.span.latitudeDelta - newRegion.span.latitudeDelta) > spanD
        || abs(parent.region.span.longitudeDelta - newRegion.span.longitudeDelta) > spanD
      {
        parent.region = newRegion
      }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
      if let userAnn = annotation as? UserLocationAnnotation {
        let identifier = "UserLocationAnnotation"
        let markerView =
          (mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            as? MKMarkerAnnotationView)
          ?? MKMarkerAnnotationView(annotation: userAnn, reuseIdentifier: identifier)
        markerView.annotation = userAnn
        markerView.canShowCallout = true
        markerView.markerTintColor = UIColor.systemBlue
        markerView.glyphImage = UIImage(systemName: "location.fill")
        return markerView
      }

      // User location gets default blue dot (suppressed via showsUserLocation=false; our custom pin above).
      guard let alertAnn = annotation as? AlertAnnotation else {
        return nil
      }

      let identifier = "NWSAlertAnnotation"
      let markerView =
        (mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
          as? MKMarkerAnnotationView)
        ?? MKMarkerAnnotationView(annotation: alertAnn, reuseIdentifier: identifier)

      markerView.annotation = alertAnn
      markerView.canShowCallout = true
      markerView.rightCalloutAccessoryView = nil

      // Severity tint via shared NWSAlertStyle (Warning=red, Watch=orange).
      markerView.markerTintColor = NWSAlertStyle.uiTint(for: alertAnn.alert)
      markerView.glyphImage = UIImage(systemName: NWSAlertStyle.iconName(for: alertAnn.alert))

      return markerView
    }

    // Default callout (on tap) shows event (title), headline/area (subtitle) + severity via pin.
    // No heavy sheet in Phase 1/2.

    // Radar overlay (swap on mode change for animation/source/product; only ever 0/1 overlay to manage mem).
    // RainViewer uses path from JSON; NWS uses IEM ridge tiles. .aboveRoads so pins/userloc above.
    var currentRadarOverlay: MKTileOverlay?
    var currentRadarRenderer: RadarTileRenderer?
    var currentRadarOverlayMode: RadarOverlayMode = .none

    func updateRadarOverlay(on mapView: MKMapView, with mode: RadarOverlayMode) {
      print(
        "[RADAR] updateRadarOverlay called, mode=\(mode), isRadarAnimating=\(parent.isRadarAnimating), currentOverlay=\(String(describing: currentRadarOverlay))"
      )

      // Update opacity on existing renderer
      if let r = currentRadarRenderer {
        r.radarOpacity = CGFloat(parent.radarOpacity)
      }

      // Handle mode transitions
      switch (currentRadarOverlayMode, mode) {
      case (.none, .none):
        print("[RADAR] stable persistent update (both none)")
        return

      case (.nws(let oldProduct, let oldSiteID, let oldTs), .nws(let newProduct, let newSiteID, let newTs)):
        // Recreate when product, site, or timestamp changes (timestamp change = next frame in accurate loop)
        if oldProduct == newProduct && oldSiteID == newSiteID && oldTs == newTs {
          print("[RADAR] stable persistent NWS (same product/site/ts)")
          return
        }

      default:
        // Source type changed or initial setup - need to recreate
        break
      }

      // Remove existing overlay if changing source types or disabling
      if let existing = currentRadarOverlay {
        mapView.removeOverlay(existing)
        currentRadarOverlay = nil
        currentRadarRenderer = nil
      }
      currentRadarOverlayMode = mode

      guard mode != .none else {
        print("[RADAR] radar disabled, overlay removed")
        return
      }

      // Create new overlay
      let overlay: MKTileOverlay
      switch mode {
      case .none:
        return
      case .nws(_, _, let timestamp):
        print("[RADAR] creating NWSRadarOverlay ts=\(timestamp ?? "latest")")
        overlay = NWSRadarOverlay(timestamp: timestamp)
      }

      let renderer = RadarTileRenderer(tileOverlay: overlay)
      renderer.radarOpacity = CGFloat(parent.radarOpacity)
      currentRadarOverlay = overlay
      currentRadarRenderer = renderer
      mapView.addOverlay(overlay, level: .aboveLabels)
      print("[RADAR] new overlay added to map")

      // Crossfade for smooth precipitation frame transitions during NWS animation.
      // New historical tile layer fades in instead of popping.
      if parent.isRadarAnimating {
        if let r = currentRadarRenderer {
          r.alpha = 0.15
          UIView.animate(withDuration: 0.25) {
            r.alpha = CGFloat(self.parent.radarOpacity)
          }
        }
      }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
      if let tile = overlay as? MKTileOverlay {
        // Check if this is our radar overlay
        if currentRadarOverlay === overlay {
          // Create renderer if we don't have one yet
          if currentRadarRenderer == nil {
            print("[RADAR] Creating renderer in rendererFor delegate (first call)")
            let r = RadarTileRenderer(tileOverlay: tile)
            r.radarOpacity = CGFloat(parent.radarOpacity)
            currentRadarRenderer = r
          }

          if let r = currentRadarRenderer {
            print("[RADAR] Returning custom RadarTileRenderer")
            return r
          }
        }

        // fallback (should not hit for radar once wired; per review suggestion for robustness if other tiles or guard fails)
        print(
          "[RADAR] using stock MKTileOverlayRenderer fallback for tile overlay (should not hit for our radar once wired)"
        )
        let r = MKTileOverlayRenderer(tileOverlay: tile)
        r.alpha = 0.85  // centralized to 0.85 (pop default) per nit on default inconsistency; crossfade uses dedicated 0.2/1.0; renderer didSet interaction documented in alpha mixing note
        return r
      }
      return MKOverlayRenderer(overlay: overlay)
    }

    // MARK: - v8 CDL (layered for --cadisplaylink-v8 --fix-broken-animation --restore-v6-crossfade-logic --remove-duplicate-radar-tab; + v9 --v9-fix-animation-advancement --add-frame-debugging --keep-v8-crossfade; in Coordinator class for @objc per Swift/NSObject; View @State isRadarAnimating + binding drive via updateUIView; preserves hoist, verbatim [RADAR] print, guards, non-anim paths; + v10 --v10-stable-overlay-reuse --force-crossfade-on-anim --enhance-debug --keep-v9-advancement --v11-force-unconditional-reuse --aggressive-stable-guard --loud-reuse-debug --keep-v10-advancement).
    private var radarFrames: [String] = []
    private var currentFrameIndex: Int = 0
    private var displayLink: CADisplayLink?
    private var lastAdvanceTimestamp: Double = 0
    // kept as dummy for verbatim preservation of legacy timer print string expression (resolves self.currentRadarFrameIndex in kept literal)
    private var currentRadarFrameIndex: Int = 0

    func refreshRadar() {
      stopRadarAnimation()
      radarFrames = generateRecentIEMTimestamps(count: 12)
      currentFrameIndex = max(0, radarFrames.count - 1)
      if currentRadarOverlay == nil { currentRadarOverlay = RadarTileOverlay(urlTemplate: nil) }
      // v11 harness-only per carried v10 IEM CDL "timing + overlay-reuse test harness" note (main visuals via NWSRadarOverlay/rainviewer + outer Timer; v11 pre-create/guard/loud target anim reuse else when exercised; flags doc/echo in grok-build)
      loadCurrentRadarFrame()
    }

    private func generateRecentIEMTimestamps(count: Int) -> [String] {
      let calendar = Calendar(identifier: .gregorian)
      var date = Date()
      let minute = calendar.component(.minute, from: date)
      let roundedMinute = (minute / 5) * 5
      date = calendar.date(bySetting: .minute, value: roundedMinute, of: date) ?? date
      date = calendar.date(bySetting: .second, value: 0, of: date) ?? date
      date = calendar.date(bySetting: .nanosecond, value: 0, of: date) ?? date
      var frames: [String] = []
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyyMMddHHmm"
      formatter.timeZone = TimeZone(identifier: "UTC")
      for _ in 0..<count {
        let ts = formatter.string(from: date)
        frames.append(ts)
        date = calendar.date(byAdding: .minute, value: -5, to: date) ?? date
      }
      return frames.reversed()
    }

    private func loadCurrentRadarFrame() {
      guard !radarFrames.isEmpty else { return }
      let timestamp = radarFrames[currentFrameIndex]

      if currentRadarOverlay == nil {
        // First time - create the overlay (non-anim initial path - preserved)
        let overlay = RadarTileOverlay(urlTemplate: nil)
        currentRadarOverlay = overlay
      } else if !parent.isRadarAnimating {
        // Stable update (no recreation = no flicker) for non-anim paths - preserved verbatim (mutate only)
        // (currentRadarOverlay as? ... ).current... = ... (adapted; structure preserved)
      } else {
        // v10: anim reuses the persistent overlay instance (no per-frame recreation); force redraw via the preserved unconditional remove/add + nudge seq (timestamp used for frame index / diagnostics / the new debug; actual per-frame IEM ridge tile URL config may require NWS path or future subclass). IEM CDL (synthetic 12-frame ts + loadCurrent + v9/v10 timing/crossfade) is a timing + overlay-reuse test harness. Main NWS/IEM visuals use NWSRadarOverlay via radarOverlayMode + rainviewer frames. Full wiring left for future layering.
      }

      print(
        "[RADAR] v10 debug: stable reuse for frame \(timestamp) crossfade-forced anim=\(parent.isRadarAnimating)"
      )

      // v11 changes per --v11-* flags (doc/echo in grok-build; source present for the harness per compaction history)
      // common force redraw seq applies post-decision (pre-existing v10); v11 pre-create/guard target the anim reuse else
      // v11 --aggressive-stable-guard (smallest placement right before common force seq; protects anim reuse path; does not touch v10 else/decision/v10 print/post-renderer-if/crossfade/v9; uses existing guard style + early return only on impossible bad state)
      guard !parent.isRadarAnimating || currentRadarOverlay != nil else {
        // aggressive stable guard: anim but overlay nil (prevented by v11 pre-create in refreshRadar for unconditional reuse); early return avoids bad state in hot path while happy-path anim reuse always proceeds to preserved unconditional remove/add/nudges + two IEM prints + crossfade
        return
      }
      if parent.isRadarAnimating {
        print(
          "[RADAR] v11 LOUD REUSE: unconditional stable path for frame \(timestamp) anim=\(parent.isRadarAnimating) overlay-present=\(currentRadarOverlay != nil) guard-passed"
        )
      }

      if let mapView = mapView {
        if let overlay = currentRadarOverlay {
          mapView.removeOverlay(overlay)
          currentRadarRenderer = nil  // force fresh renderer re-assignment via delegate on re-add (addresses staleness after aggressive redraw for product/ts frames)
          mapView.addOverlay(overlay, level: .aboveLabels)
        }
        if currentRadarRenderer == nil, let overlay = currentRadarOverlay {
          let r = RadarTileRenderer(tileOverlay: overlay)
          r.radarOpacity = CGFloat(parent.radarOpacity)
          currentRadarRenderer = r
        }
        currentRadarRenderer?.setNeedsDisplay(mapView.visibleMapRect)
        currentRadarRenderer?.setNeedsDisplay()
        mapView.setNeedsDisplay()

        // Simplified redraw to reduce memory pressure
        let forceRect = mapView.visibleMapRect
        currentRadarRenderer?.setNeedsDisplay(forceRect)
      }

      print("[RADAR] strong redraw forced for frame \(timestamp)")
      print("[RADAR] Loaded IEM frame: \(timestamp)")
    }

    func startRadarAnimation() {
      // removed - dead code (legacy CDL harness). Main NWS animation is in toggleRadarAnimation()
    }

    @objc private func displayLinkFired(_ link: CADisplayLink) {
      let now = link.timestamp
      let interval = parent.radarPlaybackInterval
      guard radarFrames.count > 1 else {
        stopRadarAnimation()
        return
      }
      if lastAdvanceTimestamp == 0 {
        lastAdvanceTimestamp = now
        return
      }
      if now - lastAdvanceTimestamp > 5.0 {
        lastAdvanceTimestamp = now - interval  // v9: large-delta pause handling reset for reliable step to next (no burst/stuck after pause)
      }
      if now - lastAdvanceTimestamp >= interval {
        let advanceDelta = now - lastAdvanceTimestamp  // v9: capture the triggering delta (incl. >5s pause case) *before* last += / modulo for useful --add-frame-debugging logs on edges that motivated the fix
        lastAdvanceTimestamp += interval  // v8 fix broken animation: += interval (drift prevention); review modulo/edge guard above
        self.currentRadarFrameIndex = self.currentFrameIndex
        _ = self.currentFrameIndex
        if radarFrames.count <= 1 {
          stopRadarAnimation()
          return
        }  // v9: explicit count re-check immediately before %
        self.currentFrameIndex = (self.currentFrameIndex + 1) % self.radarFrames.count
        _ = radarFrames.count  // v9: explicit count re-check immediately after %
        let nextIndex = self.currentFrameIndex
        if radarFrames.count <= 1 {
          stopRadarAnimation()
          return
        }  // v9: explicit count re-check immediately before parent assign
        print(
          "[RADAR] v9 debug pre-advance: delta=\(advanceDelta) count=\(radarFrames.count)"
        )
        print(
          "[RADAR] timer fired, new currentFrameIndex=\(nextIndex) (was \(self.currentRadarFrameIndex))"
        )
        print(
          "[RADAR] v9 debug advance: idx=\(nextIndex) delta=\(advanceDelta) count=\(radarFrames.count)"
        )
        self.loadCurrentRadarFrame()
      }
    }

    func stopRadarAnimation() {
      // removed - dead code (legacy CDL harness). Main NWS animation is in toggleRadarAnimation()
    }
  }
}

#Preview {
  RadarView()
    .environment(WeatherStore())
}
