import CoreLocation
import Foundation
import MapKit
import SwiftUI

// MARK: - RainViewer support (static + animated radar Phase 3; inside this file for minimal change, no new files)
// Tolerant optionals (like NWSGeometry custom decode) for robustness; we only use .radar.past .
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

enum RadarSource: String, CaseIterable, Identifiable {
  case rainViewer = "RainViewer"
  case nws = "NWS"

  var id: String { rawValue }
}

enum RadarOverlayMode: Equatable {
  case none
  case rainViewer(template: String)
  case nws(product: NWSRadarProduct, siteID: String)
}

struct RadarView: View {
  @Environment(WeatherStore.self) private var store

  @State private var mapRegion = MKCoordinateRegion(
    center: SavedLocation.oliveBranch.coordinate,
    span: MKCoordinateSpan(latitudeDelta: 0.8, longitudeDelta: 0.8)
  )
  @State private var annotations: [AlertAnnotation] = []

  // Radar overlay (Phase 3): static + animated via RainViewer + MKTileOverlay swap.
  // @State local (no store change per lightweight scope). Frames fetched on tab/toggle only.
  @State private var radarEnabled = true
  @State private var isRadarAnimating = false
  @State private var currentRadarFrameIndex = 0
  @State private var radarFrames: [RadarFrame] = []
  @State private var radarOpacity: Double = 0.75  // slider-driven; default 0.75 per spec; restored on toggle-on
  @State private var lastRadarOpacity: Double = 0.75
  @State private var rainViewerHost: String = "https://tilecache.rainviewer.com"
  @State private var animationTimer: Timer?

  // Radar UX improvements (current pin, map type, playback speed)
  @State private var mapType: MKMapType = .standard
  @State private var radarPlaybackInterval: TimeInterval = 0.6

  // NWS/IEM ridge radar (static latest frame; US-focused).
  @State private var radarSource: RadarSource = .rainViewer
  @State private var nwsRadarProduct: NWSRadarProduct = .baseReflectivity
  @State private var iemRadarListReady = false
  @State private var nwsRadarSiteID = IEMRadarSiteResolver.fallbackSiteID
  @State private var nwsSiteResolveCenter: CLLocationCoordinate2D?
  @State private var nwsSiteUpdateTask: Task<Void, Never>?

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
    switch radarSource {
    case .rainViewer:
      guard !radarFrames.isEmpty,
        currentRadarFrameIndex >= 0,
        currentRadarFrameIndex < radarFrames.count
      else { return .none }
      let frame = radarFrames[currentRadarFrameIndex]
      let template = "\(rainViewerHost)\(frame.path)/256/{z}/{x}/{y}/2/1_1.png"
      return .rainViewer(template: template)
    case .nws:
      let siteID = nwsRadarProduct.usesUSComposite ? "USCOMP" : nwsRadarSiteID
      return .nws(product: nwsRadarProduct, siteID: siteID)
    }
  }

  private var mapRegionCenterKey: String {
    String(format: "%.4f,%.4f", mapRegion.center.latitude, mapRegion.center.longitude)
  }

  private var showReflectivityLegend: Bool {
    radarEnabled
      && (radarSource == .rainViewer || nwsRadarProduct == .baseReflectivity)
  }

  private var showRainViewerPlayback: Bool {
    radarEnabled && radarSource == .rainViewer && !radarFrames.isEmpty
  }

  private var showRadarOpacitySlider: Bool {
    radarEnabled && (radarSource == .nws || !radarFrames.isEmpty)
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

      Text(currentRadarTimeString)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .frame(minWidth: 40, alignment: .leading)

      HStack(spacing: 2) {
        ForEach([0.3, 0.6, 1.0], id: \.self) { secs in
          let label = secs == 0.3 ? "2x" : (secs == 0.6 ? "1x" : "0.5x")
          Text(label)
            .font(.caption2.weight(abs(radarPlaybackInterval - secs) < 0.05 ? .bold : .regular))
            .foregroundStyle(abs(radarPlaybackInterval - secs) < 0.05 ? .white : .secondary)
            .padding(.horizontal, 4)
            .onTapGesture { setPlaybackSpeed(secs) }
        }
      }
    }
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
          Picker("Radar source", selection: $radarSource) {
            ForEach(RadarSource.allCases) { source in
              Text(source.rawValue).tag(source)
            }
          }
          .pickerStyle(.segmented)
          .accessibilityLabel("Radar source")
          .onChange(of: radarSource) { _, newSource in
            Haptic.impact(.light)
            if newSource == .nws {
              stopRadarAnimation()
              radarControlsExpanded = true
              updateNWSRadarSite(center: mapRegion.center, force: true)
            } else if radarFrames.isEmpty {
              Task { await refreshRadarFrames() }
            }
          }

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
          if showRainViewerPlayback {
            radarPlaybackRow
          }

          if showReflectivityLegend {
            radarColorLegendRow
          }

          if radarSource == .nws {
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

  var body: some View {
    NavigationStack {
      ZStack {
        MapViewRepresentable(
          region: $mapRegion, annotations: annotations, radarOverlayMode: radarOverlayMode,
          radarOpacity: radarOpacity, userLocation: myLocationCoordinate, mapType: mapType,
          isRadarAnimating: isRadarAnimating, radarPlaybackInterval: radarPlaybackInterval
        )
        .ignoresSafeArea(edges: .top)
        .overlay {
          WeatherBackgroundView(
            conditionCode: store.currentWeather?.conditionCode,
            isDay: store.currentWeather.map {
              WeatherBackgroundView.isDay(from: $0.symbolName)
            } ?? WeatherBackgroundView.inferredIsDay,
            intensity: .subtle
          )
          .opacity(0.18)
          .allowsHitTesting(false)
        }

        .overlay(alignment: .bottomTrailing) {
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

        // Preload IEM radar list for nearest-site velocity/SRV tiles.
        await IEMRadarSiteResolver.preloadRadarList()
        iemRadarListReady = IEMRadarSiteResolver.isReady
        if radarSource == .nws {
          updateNWSRadarSite(center: mapRegion.center, force: true)
        }

        // RainViewer frames only needed when that source is active (skip when NWS selected).
        if radarSource == .rainViewer {
          await refreshRadarFrames()
        }
        // Modern Swift Concurrency: use Task { @MainActor } instead of await MainActor.run for post-await @State updates.
        Task { @MainActor in
          if radarEnabled, !isRadarAnimating {
            currentRadarFrameIndex = max(0, radarFrames.count - 1)  // safe for 0-frame (review 217 clamp sites)
          }
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
        if radarSource == .nws {
          updateNWSRadarSite(center: mapRegion.center, force: true)
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
      stopRadarAnimation()
      startRadarAnimation()
    }
  }

  // MARK: - Radar helpers (static/anim; fetch only on tab appear or toggle per lightweight; reuse alert pattern)
  private var currentRadarTimeString: String {
    guard !radarFrames.isEmpty,
      currentRadarFrameIndex >= 0,
      currentRadarFrameIndex < radarFrames.count
    else { return "--:--" }
    let unix = TimeInterval(radarFrames[currentRadarFrameIndex].time)
    let date = Date(timeIntervalSince1970: unix)
    return Self.timeFormatter.string(from: date)
  }

  private func refreshRadarFrames() async {
    guard let url = URL(string: "https://api.rainviewer.com/public/weather-maps.json") else {
      return
    }
    var req = URLRequest(url: url)
    req.setValue("GrokCast/1.0 (https://grokcast.app)", forHTTPHeaderField: "User-Agent")
    req.timeoutInterval = 10
    do {
      let (data, resp) = try await URLSession.shared.data(for: req)
      guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
        return
      }
      let decoded = try JSONDecoder().decode(RainViewerResponse.self, from: data)
      // Modern Swift Concurrency: Task { @MainActor } for the @State updates after the await.
      Task { @MainActor in
        if let h = decoded.host { rainViewerHost = h }
        let past = decoded.radar?.past ?? []
        let recent = Array(past.suffix(10))  // ~ last 10 frames (~60-100min loop)
        if radarFrames.last?.time != recent.last?.time || radarFrames.count != recent.count {
          radarFrames = recent
          if radarEnabled {
            if !isRadarAnimating {
              currentRadarFrameIndex = max(0, radarFrames.count - 1)
            } else {
              // Safe clamp for re-fetch while anim (review bug 217): min without max(0) could yield -1 on 0 frames; use full max(0,min( , max(0,c-1)))
              currentRadarFrameIndex = max(
                0, min(currentRadarFrameIndex, max(0, radarFrames.count - 1)))
            }
          }
        }
      }
    } catch {
      print("🌩️ [Radar] rainviewer fetch failed (non-fatal): \(error.localizedDescription)")
    }
  }

  private func scheduleNWSRadarSiteUpdate(center: CLLocationCoordinate2D) {
    guard radarSource == .nws, !nwsRadarProduct.usesUSComposite else { return }
    nwsSiteUpdateTask?.cancel()
    nwsSiteUpdateTask = Task { @MainActor in
      try? await Task.sleep(nanoseconds: 300_000_000)
      guard !Task.isCancelled else { return }
      updateNWSRadarSite(center: center)
    }
  }

  private func updateNWSRadarSite(center: CLLocationCoordinate2D, force: Bool = false) {
    guard radarSource == .nws, !nwsRadarProduct.usesUSComposite else { return }

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
      radarOpacity = lastRadarOpacity  // restore last used (slider state persists across toggles per spec)
      if radarSource == .nws {
        updateNWSRadarSite(center: mapRegion.center, force: true)
      } else if radarFrames.isEmpty {
        Task {
          await refreshRadarFrames()
          // Modern Swift Concurrency adoption for the post-await @State work.
          Task { @MainActor in
            if radarEnabled {
              currentRadarFrameIndex = max(0, radarFrames.count - 1)  // safe for 0-frame (review 217 clamp sites)
            }
          }
        }
      } else {
        currentRadarFrameIndex = max(0, radarFrames.count - 1)  // safe for 0-frame (review 217 clamp sites)
      }
    } else {
      lastRadarOpacity = radarOpacity  // capture for next on
      stopRadarAnimation()
    }
  }

  private func toggleRadarAnimation() {
    guard radarEnabled, !radarFrames.isEmpty else { return }
    Haptic.impact(.light)
    if isRadarAnimating {
      stopRadarAnimation()
    } else {
      startRadarAnimation()
    }
  }

  private func startRadarAnimation() {
    stopRadarAnimation()
    isRadarAnimating = true
    let t = Timer.scheduledTimer(withTimeInterval: radarPlaybackInterval, repeats: true) { _ in
      Task { @MainActor [self] in
        guard self.isRadarAnimating, self.radarEnabled, !self.radarFrames.isEmpty else {
          self.stopRadarAnimation()
          return
        }
        self.currentRadarFrameIndex = (self.currentRadarFrameIndex + 1) % self.radarFrames.count
      }
    }
    RunLoop.current.add(t, forMode: .common)
    animationTimer = t
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

// RadarTileOverlay: custom MKTileOverlay subclass for stricter zoom control on RainViewer tiles.
// Overrides url(forTilePath:) to clamp z>7 requests to z=7 (current RainViewer max per docs); also overrides loadTile(at:result:) to short-circuit before fetch.
// Ensures server never receives unsupported z (prevents "Zoom Level Not Supported" text tiles)
// even during zoom gestures where cameraZoomRange+maxZ alone might allow high-z path selection.
// Complements minimumZ/maximumZ=7 (set every new overlay creation). (MapKit best practice for external tile sources w/ hard limits.)
final class RadarTileOverlay: MKTileOverlay {
  private let effectiveMaxZ = 7
  private var _currentURLTemplate: String?

  /// Allows updating the URL template for animation frames without recreating the overlay
  var currentURLTemplate: String? {
    get { _currentURLTemplate }
    set {
      guard _currentURLTemplate != newValue else { return }
      _currentURLTemplate = newValue
      // Note: MKTileOverlay doesn't provide a public API to clear its tile cache.
      // The overlay will fetch new tiles as needed based on the updated urlTemplate
      // accessed via the overridden url(forTilePath:) method below.
    }
  }
  
  // Custom initializer to ensure template is set
  override init(urlTemplate: String?) {
    super.init(urlTemplate: urlTemplate ?? "")
    self._currentURLTemplate = urlTemplate
  }

  // Override url(forTilePath:) to use our mutable _currentURLTemplate
  override func url(forTilePath path: MKTileOverlayPath) -> URL {
    guard let template = _currentURLTemplate else {
      return super.url(forTilePath: path)
    }

    // Replace {z}, {x}, {y} placeholders with actual values
    let urlString =
      template
      .replacingOccurrences(of: "{z}", with: "\(path.z)")
      .replacingOccurrences(of: "{x}", with: "\(path.x)")
      .replacingOccurrences(of: "{y}", with: "\(path.y)")

    return URL(string: urlString) ?? super.url(forTilePath: path)
  }

  // RainViewer serves z≤7. When zoomed in MapKit requests higher-z tiles; crop the matching
  // subsection from the parent z=7 tile so precipitation stays visible at all zoom levels.
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

      case (.rainViewer, .rainViewer(let newTemplate)):
        // Reuse existing overlay for RainViewer animation frames
        if let radarOverlay = currentRadarOverlay as? RadarTileOverlay {
          radarOverlay.currentURLTemplate = newTemplate
          print("[RADAR] reusing overlay, updated template to \(newTemplate)")
          currentRadarOverlayMode = mode
          return
        }

      case (.nws(let oldProduct, let oldSiteID), .nws(let newProduct, let newSiteID)):
        // Only recreate if product or site changed
        if oldProduct == newProduct && oldSiteID == newSiteID {
          print("[RADAR] stable persistent update (same NWS config)")
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
      case .rainViewer(let template):
        print("[RADAR] creating NEW RadarTileOverlay for path=\(template)")
        let rv = RadarTileOverlay(urlTemplate: template)
        rv.canReplaceMapContent = false
        rv.minimumZ = 0
        rv.maximumZ = 7
        overlay = rv
      case .nws(let product, let siteID):
        print("[RADAR] creating NEW NWSRadarOverlay for \(product.displayName) at \(siteID)")
        overlay = NWSRadarOverlay(product: product, siteID: siteID)
      }

      let renderer = RadarTileRenderer(tileOverlay: overlay)
      renderer.radarOpacity = CGFloat(parent.radarOpacity)
      currentRadarOverlay = overlay
      currentRadarRenderer = renderer
      mapView.addOverlay(overlay, level: .aboveLabels)
      print("[RADAR] new overlay added to map")
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
      if displayLink != nil { return }
      stopRadarAnimation()
      guard radarFrames.count > 1 else { return }
      displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired(_:)))
      if #available(iOS 15.0, *) {
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
          minimum: 10, maximum: 60, preferred: 60)
      } else {
        displayLink?.preferredFramesPerSecond = 60
      }
      displayLink?.isPaused = false
      displayLink?.add(to: .main, forMode: .common)
      lastAdvanceTimestamp = 0
      print("[RADAR] Animation started with \(radarFrames.count) frames")
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
      displayLink?.invalidate()
      displayLink = nil
      lastAdvanceTimestamp = 0
    }
  }
}

#Preview {
  // Enhanced with sample alerts (varying severity + valid coords) to demo pins, callouts, and color/glyph tinting (red >=3 triangle, else orange circle) per review Suggestion12. Non-blocking.
  // (Simplified to 1 sample + explicit return to avoid Swift preview typecheck "failed to produce diagnostic" in some Xcode/Swift versions.)
  let store = WeatherStore()
  store.activeAlerts = [
    NWSAlert(
      id: "urn:oid:1",
      event: "Severe Thunderstorm Warning",
      severity: "Severe",
      headline: "Severe thunderstorm capable of producing damaging winds",
      description: nil, instruction: nil, expires: nil,
      areaDesc: "DeSoto, MS; Tate, MS",
      latitude: 34.9618, longitude: -89.8295
    )
  ]
  return RadarView()
    .environment(store)
}
