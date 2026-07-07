import CoreLocation
import Foundation

struct RadarStatusFooter: Equatable {
  enum Style: Equatable {
    case secondary
    case warning
    case error
    case loading
  }

  let text: String
  let style: Style
}

@MainActor
@Observable
final class RadarState {
  private(set) var timeline = RadarTimeline() {
    didSet { syncPlaybackIndex() }
  }
  private(set) var liveTileAvailability: RadarTileAvailability = .unavailable(
    message: "Radar unavailable."
  )
  private(set) var forecastTileAvailability: RadarTileAvailability = .unavailable(
    message: "Forecast radar unavailable."
  )
  private(set) var committedIsFuture = false {
    didSet { syncPlaybackIndex() }
  }
  private(set) var transition: RadarModeTransition? {
    didSet { syncPlaybackIndex() }
  }

  var liveUnavailableMessage: String? { liveTileAvailability.userMessage }
  var futureUnavailableMessage: String? { forecastTileAvailability.userMessage }

  var activeLiveProvider: RadarTileProvider? {
    timeline.live.first?.provider
  }

  var activeForecastProvider: RadarTileProvider? {
    timeline.forecast.first?.provider
  }

  var isFutureMode: Bool { committedIsFuture }

  var showsFuture: Bool { transition?.targetIsFuture ?? committedIsFuture }

  var pickerShowsFuture: Bool { showsFuture }

  var isSwitchingMode: Bool { transition != nil }

  var showModeSwitchOverlay: Bool { transition != nil }

  /// Composite reflectivity vs single-site NEXRAD products (Velocity/SRV).
  private(set) var selectedProduct: RadarProduct = .reflectivity
  /// Client-side raster color treatment (applied in the Mapbox layer).
  var colorScheme: RadarColorScheme = .vibrant
  /// Underlying Mapbox base map style (session-only).
  var baseMapStyle: RadarBaseMapStyle = .satelliteStreets
  /// When false, hides the precipitation radar raster layer so only the base map shows.
  var showRadarOverlay: Bool = true
  /// Nearest NEXRAD site (resolved from the load coordinate; nil outside the US).
  private(set) var nearestSite: IEMRadarService.Site?

  /// Composite live timeline saved so product switches can restore it without a reload.
  private var compositeLive: (frames: [RadarFrame], availability: RadarTileAvailability)?

  /// Drops stale async site resolutions when the location changes again mid-flight.
  private var siteResolutionToken = UUID()

  /// When the composite timeline was last (re)built. Frames encode relative
  /// offsets, so on re-entry after a long gap the forecast/labels drift from
  /// the provider's newest run — reload past this age to stay current.
  private var lastLoadedAt: Date?
  private static let staleReloadThreshold: TimeInterval = 15 * 60

  /// Coordinate the timeline was built for. Provider selection is per-coordinate
  /// (IEM CONUS vs international fallbacks), so a location switch must rebuild
  /// even inside the time threshold.
  private var lastLoadedCoordinate: CLLocationCoordinate2D?
  private static let staleReloadDistanceDegrees = 0.25

  private let loader = RadarLoader()
  var playback = RadarPlayback()
  private var manualIsLoading = false

  var isLoading: Bool {
    get { manualIsLoading || loader.isLoading }
    set { manualIsLoading = newValue }
  }

  var currentIndex: Int {
    get { playback.currentIndex }
    set {
      let maxIndex = max(0, activeFrameCount - 1)
      playback.seek(to: min(max(newValue, 0), maxIndex), maxValidIndex: maxIndex)
    }
  }

  var isAnimating: Bool { playback.isAnimating }

  var playbackSpeed: Double {
    get { playback.playbackSpeed }
    set { playback.playbackSpeed = newValue }
  }

  var activeFrames: [RadarFrame] {
    timeline.frames(showingFuture: showsFuture)
  }

  var activeFrameCount: Int { activeFrames.count }

  var activeTimestamps: [Date] { activeFrames.map(\.timestamp) }

  var showContent: Bool {
    if showsFuture {
      return timeline.hasForecast
    }
    return timeline.hasLive
  }

  var activeShowsTiles: Bool {
    showsFuture ? forecastTileAvailability.showsTiles : liveTileAvailability.showsTiles
  }

  var hasFutureFrames: Bool { timeline.hasForecast }

  var autoResumeAfterScrub = true

  var currentFrame: RadarFrame? {
    guard !activeFrames.isEmpty else { return nil }
    let idx = min(max(currentIndex, 0), activeFrames.count - 1)
    return activeFrames[idx]
  }

  var currentFrameDate: Date? { currentFrame?.timestamp }

  var activeFrameLabels: [String] {
    timeline.activeFrameLabels(showingFuture: showsFuture)
  }

  var currentFrameDisplayTime: String {
    guard let frame = currentFrame else { return "–:–" }
    if showsFuture {
      let labels = activeFrameLabels
      guard !labels.isEmpty else { return "?" }
      let idx = min(max(currentIndex, 0), labels.count - 1)
      return labels[idx]
    }
    return frame.timelineLabel(showingFuture: false, forecastAnchor: nil)
  }

  var statusFooterContent: RadarStatusFooter {
    if isSwitchingMode && pickerShowsFuture {
      return RadarStatusFooter(text: "Checking forecast tiles…", style: .loading)
    }
    if pickerShowsFuture, let message = futureUnavailableMessage {
      return RadarStatusFooter(text: message, style: .warning)
    }
    if !hasFutureFrames && pickerShowsFuture {
      return RadarStatusFooter(text: "Forecast radar unavailable", style: .error)
    }
    if showsFuture, let provider = activeForecastProvider {
      return RadarStatusFooter(
        text: provider.forecastFooterLabel,
        style: provider == .openWeatherMap ? .warning : .secondary
      )
    }
    if let provider = activeLiveProvider {
      return RadarStatusFooter(
        text: provider.liveFooterLabel,
        style: (provider == .rainViewer || provider == .iem) ? .secondary : .warning
      )
    }
    if let message = liveUnavailableMessage {
      return RadarStatusFooter(text: message, style: .error)
    }
    return RadarStatusFooter(text: "Radar unavailable", style: .error)
  }

  var resolvedCurrentTileKey: String? {
    guard let frame = currentFrame else { return nil }
    return frame.tileKey
  }

  init() {
    playback.frameCount = { [weak self] in self?.activeFrameCount ?? 0 }
    playback.frameTimestamps = { [weak self] in self?.activeTimestamps ?? [] }
  }

  func start() { playback.start() }

  func stop() { playback.stop() }

  func setPlaybackSpeed(_ speedMultiplier: Double) {
    playback.setPlaybackSpeed(speedMultiplier)
  }

  func requestModeChange(toFuture: Bool) {
    if !toFuture {
      guard showsFuture else { return }
      beginTransition(targetIsFuture: false)
      return
    }

    guard EntitlementChecker.canUseRadarFuture(subscription: SubscriptionManager.shared) else {
      PaywallCoordinator.shared.present(.radarFuture)
      return
    }

    guard timeline.hasForecast, !showsFuture, transition == nil else { return }

    // Site products (Velocity/SRV) have no forecast — return to composite reflectivity.
    if selectedProduct.isSiteProduct {
      restoreCompositeLive()
    }

    beginTransition(targetIsFuture: true)
  }

  func cancelModeSwitch() {
    abortTransition(restoreIndex: true)
  }

  func abortTransition(restoreIndex: Bool = true, unavailableMessage: String? = nil) {
    guard let activeTransition = transition else { return }
    if let unavailableMessage {
      forecastTileAvailability = .timelineOnly(message: unavailableMessage)
    } else {
      forecastTileAvailability = activeTransition.savedForecastAvailability
    }
    if restoreIndex {
      restorePlaybackIndex(
        savedIndex: activeTransition.savedIndex,
        wasFuture: activeTransition.savedWasFuture
      )
    }
    transition = nil
  }

  func completeTransition() {
    guard let activeTransition = transition else { return }
    committedIsFuture = activeTransition.targetIsFuture
    transition = nil
    if committedIsFuture, playback.playbackSpeed > 2.0 {
      playback.playbackSpeed = 2.0
    }
    activateCurrentForCommittedMode()
    // Auto-play FUTURE so switching into it animates the forecast immediately
    // instead of sitting paused on frame 1 (beginTransition stopped playback).
    // NOW is intentionally left alone — it gets its start() from RadarView on
    // tab entry and should rest on the latest live frame, not reset to frame 0.
    if committedIsFuture, activeFrameCount > 0 {
      playback.start()
    }
  }

  func refreshForecastTileAvailability() async -> Bool {
    guard timeline.hasForecast, let provider = activeForecastProvider else {
      return false
    }

    let availability = await loader.refreshForecastAvailability(provider: provider)
    forecastTileAvailability = availability
    return availability.hasFrames
  }

  private func beginTransition(targetIsFuture: Bool) {
    transition = RadarModeTransition(
      id: UUID(),
      targetIsFuture: targetIsFuture,
      savedIndex: playback.currentIndex,
      savedWasFuture: committedIsFuture,
      savedForecastAvailability: forecastTileAvailability
    )
    playback.stop()
  }

  private func restorePlaybackIndex(savedIndex: Int, wasFuture: Bool) {
    let frames = timeline.frames(showingFuture: wasFuture)
    guard !frames.isEmpty else { return }
    playback.currentIndex = min(max(savedIndex, 0), frames.count - 1)
  }

  private func syncPlaybackIndex() {
    playback.syncIndex(with: activeFrameCount)
  }

  private func activateCurrentForCommittedMode() {
    if committedIsFuture {
      playback.currentIndex = 0
      return
    }
    if timeline.hasLive {
      playback.currentIndex = max(0, timeline.live.count - 1)
    }
  }
}

extension RadarState {

  func togglePlayback() {
    if playback.isAnimating {
      playback.stop()
    } else if activeFrameCount > 0 {
      playback.start()
    } else {
      playback.isAnimating = false
    }
  }

  func setFutureMode(_ isFuture: Bool) {
    requestModeChange(toFuture: isFuture)
  }

  /// Whether Velocity/SRV chips can do anything (US live mode with a resolved site).
  var siteProductsAvailable: Bool {
    nearestSite != nil
  }

  /// Switch between composite reflectivity and single-site NEXRAD products.
  /// Silent no-op when the site products aren't available or frames fail to load.
  func setProduct(_ product: RadarProduct) async {
    guard product != selectedProduct else { return }

    guard product.isSiteProduct else {
      selectedProduct = .reflectivity
      restoreCompositeLive()
      return
    }

    guard !showsFuture, let site = nearestSite else { return }

    selectedProduct = product
    let frames = await IEMRadarService.loadSiteFrames(site: site.id, product: product)

    // Re-validate across the await: the user may have entered FUTURE mode, picked a
    // different site product, or the resolved site may have changed while loading.
    guard !showsFuture, selectedProduct == product, nearestSite?.id == site.id else { return }

    guard !frames.isEmpty else {
      print("[RadarState] \(product.displayName) unavailable for \(site.id) — keeping current view")
      return
    }

    selectedProduct = product
    timeline.live = frames
    liveTileAvailability = .available
    playback.currentIndex = max(0, frames.count - 1)
    print("[RadarState] \(product.displayName) ready (\(frames.count) scans) — NWS \(site.id)")
  }

  private func restoreCompositeLive() {
    selectedProduct = .reflectivity
    guard let composite = compositeLive else { return }
    timeline.live = composite.frames
    liveTileAvailability = composite.availability
    if !showsFuture {
      playback.currentIndex = max(0, composite.frames.count - 1)
    }
  }

  /// Resolve the nearest NEXRAD site for the selected weather location and keep
  /// any active site product pointed at it. Non-fatal; non-US resolves to nil
  /// (site chips silently unavailable). Superseded calls are dropped.
  func updateNearestSite(for coordinate: CLLocationCoordinate2D) async {
    let token = UUID()
    siteResolutionToken = token

    let site = await IEMRadarService.nearestSite(to: coordinate)
    guard siteResolutionToken == token, site != nearestSite else { return }

    nearestSite = site
    if let site {
      print("[RadarState] Nearest NEXRAD site: \(site.id) (\(site.name))")
    }

    // The active site product belongs to the old site — reload it for the new one.
    guard selectedProduct.isSiteProduct else { return }
    guard let site else {
      restoreCompositeLive()
      return
    }

    let product = selectedProduct
    let frames = await IEMRadarService.loadSiteFrames(site: site.id, product: product)
    guard siteResolutionToken == token, selectedProduct == product else { return }

    guard !frames.isEmpty else {
      restoreCompositeLive()
      return
    }
    timeline.live = frames
    liveTileAvailability = .available
    if !showsFuture {
      playback.currentIndex = max(0, frames.count - 1)
    }
    print("[RadarState] \(product.displayName) moved to NWS \(site.id) (\(frames.count) scans)")
  }

  /// Rebuild the timeline only if the last load is stale (or never happened).
  /// Cheap no-op on quick tab switches; refreshes after a long idle session or
  /// when the selected location moved away from the loaded coordinate.
  func reloadIfStale(for coordinate: CLLocationCoordinate2D) async {
    if let lastLoadedAt, let lastLoadedCoordinate,
      Date().timeIntervalSince(lastLoadedAt) < Self.staleReloadThreshold,
      abs(lastLoadedCoordinate.latitude - coordinate.latitude) < Self.staleReloadDistanceDegrees,
      abs(lastLoadedCoordinate.longitude - coordinate.longitude) < Self.staleReloadDistanceDegrees
    {
      return
    }
    await loadDefaultRadar(for: coordinate)
  }

  func loadDefaultRadar(for coordinate: CLLocationCoordinate2D) async {
    guard !isLoading else { return }
    isLoading = true

    await updateNearestSite(for: coordinate)

    print(
      "[RadarState] Loading radar → \(RadarTileProvider.preferredLive.displayName) (NOW)"
        + " + \(RadarTileProvider.preferredForecast.displayName) (FUTURE)"
    )
    let result = await loader.loadAll(site: nearestSite, coordinate: coordinate)

    // Always cache the composite result so a site product can restore it later —
    // even if the user selected one while this initial load was in flight.
    compositeLive = (result.live, result.liveAvailability)
    timeline.forecast = result.forecast
    forecastTileAvailability = result.forecastAvailability

    // Don't stomp a site product (Super-Res/SRV) the user chose during the load.
    if selectedProduct.isSiteProduct {
      print("[RadarState] Keeping user-selected \(selectedProduct.displayName) over composite load")
    } else {
      selectedProduct = .reflectivity
      timeline.live = result.live
      liveTileAvailability = result.liveAvailability
      activateCurrentForCommittedMode()
    }

    if let provider = result.liveProvider, !result.live.isEmpty {
      print("[RadarState] \(provider.displayName) loaded (\(result.live.count) frames)")
    } else if let message = result.liveUnavailableMessage {
      print("[RadarState] Live radar unavailable — \(message)")
    }

    if let provider = result.forecastProvider, !result.forecast.isEmpty {
      print(
        "[RadarState] Forecast ready (\(result.forecast.count) frames) — \(provider.displayName)")
    } else if result.forecast.isEmpty {
      print("[RadarState] Forecast timeline unavailable")
    }

    lastLoadedAt = Date()
    lastLoadedCoordinate = coordinate
    isLoading = false
  }
}
