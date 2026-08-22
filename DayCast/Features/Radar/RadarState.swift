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

  /// Set when a site product had no scans and we silently reverted to the previous
  /// view. Without this the chip just un-highlights itself and the tap looks ignored.
  private(set) var siteProductUnavailableMessage: String?

  /// Soft note while a site product is showing: fallback neighbor or aging scans.
  /// Cleared when returning to composite reflectivity.
  private(set) var siteProductAdvisory: String?

  /// Site whose tiles are actually on screen for DETAIL/SRV (may differ from nearest
  /// when the home radar is offline and we fell back to a neighbor).
  private(set) var activeSiteProductSite: IEMRadarService.Site?

  var activeLiveProvider: RadarTileProvider? {
    timeline.live.first?.provider
  }

  /// National Live is painting MRMS XYZ tiles (MapsGL rain must stay off).
  var nationalUsesMRMSPaint: Bool {
    guard !showsFuture, selectedProduct == .reflectivity, activeLiveProvider == .mrms else {
      return false
    }
    return MRMSNationalSource.overrideForDebug() != .forceMapsGL
  }

  var activeForecastProvider: RadarTileProvider? {
    timeline.forecast.first?.provider
  }

  var isFutureMode: Bool { committedIsFuture }

  var showsFuture: Bool { transition?.targetIsFuture ?? committedIsFuture }

  var pickerShowsFuture: Bool { showsFuture }

  var isSwitchingMode: Bool { transition != nil }

  var showModeSwitchOverlay: Bool { transition != nil }

  /// Live tries nearest-site N0B. National radar (`reflectivity`) is the dry-site fallback.
  private(set) var selectedProduct: RadarProduct = .defaultLive
  /// Explicit Layers/chip tap on Site Doppler. Live open clears this so a dry
  /// site cannot strand the next open on a blank map.
  private var userPinnedSiteDoppler = false
  /// Test hook: skip the IEM tile probe.
  var sitePrecipProbeForTesting: Bool?
  /// Test hook: skip mosaic tile sampling and supply nearest-precip distance.
  var nationalPrecipMetersForTesting: CLLocationDistance?
  var usesNationalPrecipOverrideForTesting = false
  /// Live-open / product camera. Representable applies this once per `id`.
  private(set) var cameraRequest: RadarCameraRequest?
  /// New Live open: representable drops the pan lock so the framing can apply.
  private(set) var cameraSessionID = UUID()
  /// Client-side raster color treatment (applied in the Mapbox layer).
  /// These four persist via `RadarPreferences`; the controls bind to them directly,
  /// so `didSet` is the one hook that catches every path that can change them.
  var colorScheme: RadarColorScheme = RadarPreferences.colorScheme {
    didSet { RadarPreferences.colorScheme = colorScheme }
  }
  /// Underlying Mapbox base map style.
  var baseMapStyle: RadarBaseMapStyle = RadarPreferences.baseMapStyle {
    didSet { RadarPreferences.baseMapStyle = baseMapStyle }
  }
  /// When false, hides the precipitation radar raster layer so only the base map shows.
  var showRadarOverlay: Bool = RadarPreferences.showRadarOverlay {
    didSet { RadarPreferences.showRadarOverlay = showRadarOverlay }
  }
  #if DEBUG
    /// Force MapsGL rain / force National tiles. Auto is the Live default.
    var debugNationalPaint: DebugFlags.NationalPaint = DebugFlags.nationalPaint {
      didSet { DebugFlags.nationalPaint = debugNationalPaint }
    }
  #endif
  /// Independent Fire overlay (FIRMS hotspots + NIFC perimeters). Does not affect precip rasters.
  var showFireLayer: Bool = RadarPreferences.showFireLayer {
    didSet { RadarPreferences.showFireLayer = showFireLayer }
  }
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
  /// Reload composite frames more often so Live doesn’t sit on a stale set.
  private static let staleReloadThreshold: TimeInterval = RadarLivePresentation.mosaicReload
  /// Even inside the time window, rebuild if the newest live frame is this old.
  private static let newestFrameStaleThreshold: TimeInterval =
    RadarLivePresentation.newestFrameReload

  /// Coordinate the timeline was built for. Provider selection is per-coordinate
  /// (IEM CONUS vs international fallbacks), so a location switch must rebuild
  /// even inside the time threshold.
  private var lastLoadedCoordinate: CLLocationCoordinate2D?
  private static let staleReloadDistanceDegrees = 0.25

  private let loader = RadarLoader()
  var playback = RadarPlayback()
  private var manualIsLoading = false

  /// The load in flight, if any, with the coordinate it was started for. Concurrent
  /// callers join it rather than returning early: a dropped call still completed its
  /// `await`, so the caller could not tell a refresh from a no-op — which is how a
  /// foreground reload could silently leave stale frames on screen.
  private var inFlightLoad:
    (task: Task<Void, Never>, coordinate: CLLocationCoordinate2D, id: UInt64)?
  private var nextLoadID: UInt64 = 0

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

  var isAnimating: Bool { playback.isAnimating || polarPlayWaitTask != nil }

  private var polarPlayWaitTask: Task<Void, Never>?

  /// Clamped on the way in, because `RadarPreferences` clamps on write and
  /// `RadarPlayback.playbackSpeed` is a plain `var` that does not. Assigning raw
  /// left the two disagreeing: an out-of-range value animated at full speed for
  /// the session and then silently changed on the next launch.
  var playbackSpeed: Double {
    get { playback.playbackSpeed }
    set {
      let clamped = RadarPlayback.clampedPlaybackSpeed(newValue)
      playback.playbackSpeed = clamped
      RadarPreferences.playbackSpeed = clamped
    }
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

  /// Selected city's timezone (Open-Meteo `timezone=auto`), same as Hourly.
  var displayTimeZone: TimeZone = .current

  var activeFrameLabels: [String] {
    timeline.activeFrameLabels(showingFuture: showsFuture, timeZone: displayTimeZone)
  }

  var currentFrameDisplayTime: String {
    guard let frame = currentFrame else { return "–:–" }
    if showsFuture {
      let labels = activeFrameLabels
      guard !labels.isEmpty else { return "?" }
      let idx = min(max(currentIndex, 0), labels.count - 1)
      return labels[idx]
    }
    return frame.timelineLabel(
      showingFuture: false, forecastAnchor: nil, timeZone: displayTimeZone)
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
    // Outranks the provider label — a failed product tap needs an explanation more
    // than the user needs to know which mosaic is on screen.
    if !showsFuture, let message = siteProductUnavailableMessage {
      return RadarStatusFooter(text: message, style: .warning)
    }
    if !showsFuture, selectedProduct.isSiteProduct, let note = siteProductAdvisory {
      return RadarStatusFooter(text: note, style: .warning)
    }
    if let provider = activeLiveProvider {
      return RadarStatusFooter(
        text: provider.liveFooterLabel,
        style: .secondary
      )
    }
    if let message = liveUnavailableMessage {
      return RadarStatusFooter(text: message, style: .error)
    }
    return RadarStatusFooter(
      text: "Radar unavailable — check connection and try again",
      style: .error
    )
  }

  var resolvedCurrentTileKey: String? {
    guard let frame = currentFrame else { return nil }
    return frame.tileKey
  }

  init() {
    playback.frameCount = { [weak self] in self?.activeFrameCount ?? 0 }
    playback.frameTimestamps = { [weak self] in self?.activeTimestamps ?? [] }
    playback.playbackSpeed = RadarPreferences.playbackSpeed
    playback.canAdvance = { [weak self] in
      self?.polarPlayCanAdvance ?? true
    }
  }

  /// Hold 2x Site Doppler until the next volume's trapezoid mesh *and* GPU
  /// vertex buffer are already in cache. Hard-gate makeBuffer mid-loop is the hitch.
  private var polarPlayCanAdvance: Bool {
    let frames = activeFrames
    guard frames.count > 1,
      let current = currentFrame,
      current.paintsPolarRadials
    else { return true }
    let nextIndex = playback.currentIndex >= frames.count - 1 ? 0 : playback.currentIndex + 1
    let next = frames[nextIndex]
    let site = activeSiteProductSite?.id ?? nearestSite?.id
    guard let site else { return true }
    let sweepPresent =
      Level3N0BSweepStore.shared.sweep(site: site, timestamp: next.timestamp) != nil
    let key = Level3N0BSweepStore.exactKey(site: site, timestamp: next.timestamp)
    return Level3PolarPlayReadiness.canAdvance(
      sweepPresent: sweepPresent,
      cpuCached: Level3PolarMeshCache.shared.cached(site: site, timestamp: next.timestamp) != nil,
      gpuCached: Level3PolarGPUCache.shared.contains(key),
      gpuDeviceBound: Level3PolarGPUCache.shared.hasBoundDevice)
  }

  func start() { playback.start() }

  func stop() {
    polarPlayWaitTask?.cancel()
    polarPlayWaitTask = nil
    playback.stop()
  }

  /// Tab entry and resume: newest live scan so SCAN is about now, not a 2-hour-old
  /// loop start. Leaves playback paused — Play from newest starts at the oldest
  /// frame and walks toward now. SCAN/stale keys off the newest frame.
  func presentLiveNow() {
    guard !showsFuture, timeline.hasLive else { return }
    playback.landOnNewestLiveFrame(count: timeline.live.count)
    stop()
  }

  /// Live tab entry / location change: re-evaluate dry-site auto National.
  func handleLiveOpen(for coordinate: CLLocationCoordinate2D) async {
    userPinnedSiteDoppler = false
    cameraSessionID = UUID()
    await reloadIfStale(for: coordinate)
    await applyDefaultLiveOpenPolicy()
  }

  func setPlaybackSpeed(_ speedMultiplier: Double) {
    playback.setPlaybackSpeed(speedMultiplier)
    // Persist what playback actually adopted, not the raw request — the two differ
    // when the multiplier is out of range.
    RadarPreferences.playbackSpeed = playback.playbackSpeed
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
    // A live-mode warning would be stale by the time the user comes back.
    siteProductUnavailableMessage = nil
    siteProductAdvisory = nil

    beginTransition(targetIsFuture: true)
  }

  func cancelModeSwitch() {
    abortTransition(restoreIndex: true)
  }

  /// Rolls back the in-flight mode transition. When `expectedID` is supplied, the abort
  /// is a no-op unless that transition is still the active one — this prevents a stale
  /// transition task from tearing down a newer transition that replaced it (rapid taps).
  func abortTransition(
    restoreIndex: Bool = true, unavailableMessage: String? = nil, expectedID: UUID? = nil
  ) {
    guard let activeTransition = transition else { return }
    if let expectedID, activeTransition.id != expectedID { return }
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
    activateCurrentForCommittedMode()
    // Auto-play FUTURE so switching into it animates the forecast immediately
    // instead of sitting paused on frame 1 (beginTransition stopped playback).
    // Live open/resume goes through `presentLiveNow()` so SCAN starts on now.
    if committedIsFuture, activeFrameCount > 0 {
      playback.start()
    }
  }

  func refreshForecastTileAvailability() async -> Bool {
    guard timeline.hasForecast, let provider = activeForecastProvider else {
      return false
    }

    let availability = await loader.refreshForecastAvailability(provider: provider)
    if availability.showsTiles {
      forecastTileAvailability = availability
      return true
    }

    if provider == .xweather, let fallback = await loader.loadOpenWeatherMapForecastIfAvailable() {
      timeline.forecast = fallback.frames
      forecastTileAvailability = fallback.availability
      radarLog("[RadarState] Switched FUTURE provider to OpenWeatherMap after Xweather probe failed")
      return fallback.availability.hasFrames
    }

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
    stop()
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
    if playback.isAnimating || polarPlayWaitTask != nil {
      // Live loops wrap to older frames; pausing mid-loop made SCAN look hours-stale
      // even when the newest volume is fresh. Snap Live back to latest on pause.
      stop()
      if !showsFuture, timeline.hasLive {
        playback.currentIndex = max(0, timeline.live.count - 1)
      }
    } else if activeFrameCount > 0 {
      startPolarAwarePlayback()
    } else {
      playback.isAnimating = false
    }
  }

  private func startPolarAwarePlayback() {
    Level3PolarPlayStats.reset()
    let polar = currentFrame?.paintsPolarRadials == true
    let gpuReady = Level3PolarGPUCache.shared.isPrefetchComplete
    if polar, !Level3PolarMeshCache.shared.isWarmComplete || !gpuReady {
      radarLog("[Level3] polar play waiting for mesh/GPU warm")
      polarPlayWaitTask = Task { @MainActor [weak self] in
        let t0 = CFAbsoluteTimeGetCurrent()
        await Level3PolarMeshCache.shared.waitUntilWarm()
        await Level3PolarGPUCache.shared.waitUntilPrefetched()
        let waitMs = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        guard let self, !Task.isCancelled else { return }
        self.polarPlayWaitTask = nil
        let gpu = Level3PolarGPUCache.shared.stats().count
        radarLog(
          "[Level3] polar play after warm wait=\(Int(waitMs.rounded()))ms gpu=\(gpu)"
        )
        self.playback.start()
      }
      return
    }
    if polar {
      let gpu = Level3PolarGPUCache.shared.stats().count
      radarLog("[Level3] polar play warm-complete→play delay=0ms gpu=\(gpu)")
    }
    playback.start()
  }

  func setFutureMode(_ isFuture: Bool) {
    requestModeChange(toFuture: isFuture)
  }

  /// Whether Velocity/SRV chips can do anything (US live mode with a resolved site).
  var siteProductsAvailable: Bool {
    nearestSite != nil
  }

  /// Switch between National radar and single-site NEXRAD products.
  /// Silent no-op when the site products aren't available or frames fail to load.
  func setProduct(_ product: RadarProduct, userInitiated: Bool = true) async {
    if userInitiated {
      userPinnedSiteDoppler = product == .superResReflectivity
    }
    guard product != selectedProduct else { return }
    siteProductUnavailableMessage = nil
    siteProductAdvisory = nil

    guard product.isSiteProduct else {
      selectedProduct = .reflectivity
      let needsReload = RadarLivePresentation.compositeNeedsReload(
        newestTimestamp: compositeLive?.frames.last?.timestamp,
        lastLoadedAt: lastLoadedAt
      )
      if needsReload, let coordinate = lastLoadedCoordinate {
        await loadDefaultRadar(for: coordinate)
      } else if !restoreCompositeLive(), let coordinate = lastLoadedCoordinate {
        await loadDefaultRadar(for: coordinate)
      }
      presentLiveNow()
      return
    }

    guard !showsFuture, nearestSite != nil else { return }

    // The currently displayed product/timeline stays untouched until fresh frames arrive,
    // so revert to it (not blindly to reflectivity) if the load yields nothing.
    let previousProduct = selectedProduct
    selectedProduct = product
    let refreshed = await refreshActiveSiteProduct()
    guard selectedProduct == product else { return }

    if !refreshed {
      radarLog(
        "[RadarState] \(product.displayName) offline near \(nearestSite?.id ?? "?") — keeping current view"
      )
      siteProductUnavailableMessage = unavailableMessage(for: product)
      activeSiteProductSite = nil
      // Revert so the chip and later composite reloads don't think a site product is active.
      selectedProduct = previousProduct
      return
    }

    if userInitiated, product == .superResReflectivity {
      let hasPrecip: Bool
      if let override = sitePrecipProbeForTesting {
        hasPrecip = override
      } else {
        hasPrecip = await probeSiteLiveWindowPrecip()
      }
      if !hasPrecip {
        siteProductAdvisory = RadarLiveOpenPolicy.clearHint(
          siteID: activeSiteProductSite?.id ?? nearestSite?.id)
      }
      requestLocalCamera(respectUserPan: false)
    }
  }

  /// Home radar offline and no neighbor with scans — plain "unavailable for NQA"
  /// read as a product bug rather than a site outage.
  private func unavailableMessage(for product: RadarProduct) -> String {
    guard let site = nearestSite else {
      return "\(product.displayName) offline — no recent scans"
    }
    return "\(site.id) offline — no recent \(product.shortCode) scans nearby"
  }

  /// Restore mosaic Live only when the *newest* cached scan is still
  /// presentable. A 149m composite labeled Live is a fail — reload or
  /// unavailable, do not paint it. Older frames in a fresh loop are history.
  @discardableResult
  private func restoreCompositeLive() -> Bool {
    selectedProduct = .reflectivity
    activeSiteProductSite = nil
    siteProductAdvisory = nil
    guard let composite = compositeLive else { return false }
    return commitLiveFrames(
      composite.frames, availability: composite.availability, isSiteProduct: false)
  }

  /// Keep the ~1h loop when the newest scan is still Live. Empty / newest
  /// past HUD stale → unavailable. Do not trim history to the stale cap.
  @discardableResult
  private func commitLiveFrames(
    _ frames: [RadarFrame],
    availability: RadarTileAvailability,
    isSiteProduct: Bool
  ) -> Bool {
    let live = RadarLivePresentation.liveFrames(frames, isSiteProduct: isSiteProduct)
    guard RadarLivePresentation.isPresentableAsLive(live, isSiteProduct: isSiteProduct)
    else {
      timeline.live = []
      liveTileAvailability = .unavailable(
        message: RadarLivePresentation.staleUnavailableMessage)
      return false
    }
    timeline.live = live
    liveTileAvailability = availability
    if !showsFuture {
      playback.currentIndex = max(0, live.count - 1)
    }
    return true
  }

  func seedCompositeCacheForTesting(frames: [RadarFrame], loadedAt: Date) {
    compositeLive = (frames, .available)
    lastLoadedAt = loadedAt
  }

  func restoreCompositeLiveForTesting() {
    _ = restoreCompositeLive()
  }

  func setUserPinnedSiteDopplerForTesting(_ pinned: Bool) {
    userPinnedSiteDoppler = pinned
  }

  func seedSiteLiveForTesting(site: IEMRadarService.Site, frames: [RadarFrame]) {
    nearestSite = site
    activeSiteProductSite = site
    selectedProduct = .superResReflectivity
    lastLoadedCoordinate = CLLocationCoordinate2D(latitude: site.lat, longitude: site.lon)
    _ = commitLiveFrames(frames, availability: .available, isSiteProduct: true)
  }

  func applyDefaultLiveOpenPolicyForTesting() async {
    await applyDefaultLiveOpenPolicy()
  }

  /// Dry / failed Site Doppler presents National radar on Live open.
  func applyDefaultLiveOpenPolicy() async {
    guard !showsFuture else { return }
    guard selectedProduct != .stormRelativeVelocity else { return }
    guard !userPinnedSiteDoppler else {
      requestLocalCamera(respectUserPan: true)
      return
    }

    let siteIsSelected = selectedProduct.isSiteProduct
    let siteLoaded =
      siteIsSelected && timeline.hasLive
      && RadarLivePresentation.isPresentableAsLive(timeline.live, isSiteProduct: true)
    let siteFailedOrStale = siteIsSelected && !siteLoaded
    let nationalAvailable: Bool = {
      guard let composite = compositeLive else { return false }
      return RadarLivePresentation.isPresentableAsLive(
        composite.frames, isSiteProduct: false)
    }()

    var siteHasPrecip = false
    if siteLoaded {
      siteHasPrecip = await boundedSitePrecipProbe()
    }

    let present = RadarLiveOpenPolicy.productToPresent(
      userExplicitlyChoseSiteDoppler: userPinnedSiteDoppler,
      siteDopplerLoaded: siteLoaded,
      siteHasPrecipInLiveWindow: siteHasPrecip,
      siteFailedOrStale: siteFailedOrStale,
      nationalAvailable: nationalAvailable
    )
    radarLog(
      "[RadarState] Live open present=\(present) siteLoaded=\(siteLoaded) precip=\(siteHasPrecip) failed=\(siteFailedOrStale) national=\(nationalAvailable)"
    )
    guard present == .nationalRadar else {
      if selectedProduct.isSiteProduct {
        requestLocalCamera(respectUserPan: true)
      }
      return
    }

    let flippingFromSite = selectedProduct.isSiteProduct
    let failedMessage = siteFailedOrStale ? siteProductUnavailableMessage : nil
    let clearHint: String? =
      failedMessage == nil
      ? RadarLiveOpenPolicy.clearHint(siteID: activeSiteProductSite?.id ?? nearestSite?.id)
      : nil

    if flippingFromSite || selectedProduct != .reflectivity {
      restoreCompositeLive()
      presentLiveNow()
    } else {
      presentLiveNow()
    }
    if let failedMessage {
      siteProductUnavailableMessage = failedMessage
    } else if let clearHint {
      siteProductAdvisory = clearHint
    }
    await requestDryNationalCamera()
  }

  private func boundedSitePrecipProbe() async -> Bool {
    if let override = sitePrecipProbeForTesting { return override }
    return await probeSiteLiveWindowPrecip()
  }

  private func requestLocalCamera(respectUserPan: Bool) {
    var center = lastLoadedCoordinate ?? CLLocationCoordinate2D(latitude: 37, longitude: -95)
    var zoom = RadarLiveCameraPolicy.localZoom
    #if DEBUG
      if let debug = RadarLiveCameraPolicy.debugCamera() {
        center = debug.center
        zoom = debug.zoom
      }
    #endif
    cameraRequest = RadarCameraRequest(
      center: center,
      zoom: zoom,
      animated: true,
      respectUserPan: respectUserPan
    )
  }

  private func requestDryNationalCamera() async {
    let center = lastLoadedCoordinate ?? CLLocationCoordinate2D(latitude: 37, longitude: -95)
    let nearest: CLLocationDistance?
    if usesNationalPrecipOverrideForTesting {
      nearest = nationalPrecipMetersForTesting
    } else {
      nearest = await nearestNationalPrecipMeters(from: center)
    }
    let zoom = RadarLiveCameraPolicy.cameraZoom(
      presentingNationalBecauseDry: true,
      userPinnedSiteDoppler: false,
      nearestPrecipMeters: nearest,
      latitude: center.latitude
    )
    radarLog(
      "[RadarState] Dry National camera zoom=\(String(format: "%.2f", zoom)) nearestKm=\(nearest.map { String(format: "%.0f", $0 / 1000) } ?? "none")"
    )
    cameraRequest = RadarCameraRequest(
      center: center,
      zoom: zoom,
      animated: true,
      respectUserPan: true
    )
  }

  private func nearestNationalPrecipMeters(from coordinate: CLLocationCoordinate2D)
    async -> CLLocationDistance?
  {
    let frame = compositeLive?.frames.last ?? timeline.live.last
    guard let frame else { return nil }
    return await IEMRadarService.nearestMosaicPrecipMeters(frame: frame, from: coordinate)
  }

  private func probeSiteLiveWindowPrecip() async -> Bool {
    guard let site = activeSiteProductSite ?? nearestSite else { return false }
    return await IEMRadarService.liveWindowHasOrganizedPrecip(
      frames: timeline.live, site: site)
  }

  /// Reloads Super-Res / SRV frames for the nearest site, walking to neighbors when
  /// the home radar has no recent volumes (common during NEXRAD outages).
  @discardableResult
  private func refreshActiveSiteProduct() async -> Bool {
    guard selectedProduct.isSiteProduct, let preferred = nearestSite, !showsFuture else {
      return false
    }
    let product = selectedProduct
    let coordinate =
      lastLoadedCoordinate
      ?? CLLocationCoordinate2D(latitude: preferred.lat, longitude: preferred.lon)

    let load = await IEMRadarService.loadSiteFramesNear(
      coordinate: coordinate,
      product: product,
      preferredSite: preferred
    )
    guard selectedProduct == product, nearestSite?.id == preferred.id, !showsFuture else {
      return false
    }
    guard let load, !load.frames.isEmpty else {
      activeSiteProductSite = nil
      siteProductAdvisory = nil
      return false
    }

    guard commitLiveFrames(load.frames, availability: .available, isSiteProduct: true)
    else {
      activeSiteProductSite = nil
      siteProductAdvisory = nil
      return false
    }
    siteProductUnavailableMessage = nil
    activeSiteProductSite = load.site
    siteProductAdvisory = Self.advisory(for: load, product: product)

    let via =
      load.isFallback
      ? "\(load.site.id) (fallback from \(load.preferredSite.id))"
      : load.site.id
    radarLog(
      "[RadarState] \(product.displayName) ready (\(timeline.live.count) loop / \(load.frames.count) listed) — NWS \(via)"
        + (load.isStale ? " STALE" : "")
    )
    return true
  }

  /// Human-readable soft status for fallback / aging site volumes.
  private static func advisory(
    for load: IEMRadarService.SiteFrameLoad,
    product: RadarProduct
  ) -> String? {
    if load.isFallback {
      let ageMin = Int(load.newestScanAge / 60)
      if load.isStale, ageMin > 0 {
        return "\(product.shortCode) from \(load.site.id) · \(load.preferredSite.id) offline · \(ageMin)m old"
      }
      return "\(product.shortCode) from \(load.site.id) · \(load.preferredSite.id) offline"
    }
    if load.isStale {
      let ageMin = max(1, Int(load.newestScanAge / 60))
      return "\(load.site.id) \(product.shortCode) \(ageMin)m old"
    }
    return nil
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
      radarLog("[RadarState] Nearest NEXRAD site: \(site.id) (\(site.name))")
    }

    // The active site product belongs to the old site — reload it for the new one.
    guard selectedProduct.isSiteProduct else { return }
    guard site != nil else {
      restoreCompositeLive()
      return
    }
    // First Live open: `performDefaultRadarLoad` refreshes N0B after the mosaic
    // cache exists so a dead site can restore tiles and keep the unavailable copy.
    // Reloading here first would restore an empty mosaic and then the composite
    // branch would wipe that copy.
    guard compositeLive != nil else { return }

    let product = selectedProduct
    let refreshed = await refreshActiveSiteProduct()
    guard siteResolutionToken == token, selectedProduct == product else { return }
    if !refreshed {
      // The new site doesn't carry this product — say so rather than just
      // dropping back to the mosaic.
      siteProductUnavailableMessage = unavailableMessage(for: product)
      restoreCompositeLive()
    }
  }

  /// Rebuild the timeline only if the last load is stale (or never happened).
  /// Cheap no-op on quick tab switches; refreshes after a short idle, when the
  /// newest live frame ages out, or when the selected location moved.
  func reloadIfStale(for coordinate: CLLocationCoordinate2D) async {
    let coordinateUnchanged =
      lastLoadedCoordinate.map { Self.coordinate($0, matches: coordinate) } ?? false

    if let lastLoadedAt, coordinateUnchanged,
      Date().timeIntervalSince(lastLoadedAt) < Self.staleReloadThreshold
    {
      // Still reload if the newest composite frame itself is old (paused on Radar).
      let newestAge = timeline.live.last.map { Date().timeIntervalSince($0.timestamp) } ?? .infinity
      if newestAge < Self.newestFrameStaleThreshold {
        return
      }
    }
    await loadDefaultRadar(for: coordinate)
  }

  /// Provider selection is per-coordinate, so two loads for materially different
  /// places are two different results — only same-place callers can share one.
  private static func coordinate(
    _ lhs: CLLocationCoordinate2D, matches rhs: CLLocationCoordinate2D
  ) -> Bool {
    abs(lhs.latitude - rhs.latitude) < staleReloadDistanceDegrees
      && abs(lhs.longitude - rhs.longitude) < staleReloadDistanceDegrees
  }

  func loadDefaultRadar(for coordinate: CLLocationCoordinate2D) async {
    if let inFlight = inFlightLoad {
      await inFlight.task.value
      // That load's frames are this caller's answer too. A different coordinate
      // still needs its own load, but only once the first one is off the wire.
      if Self.coordinate(inFlight.coordinate, matches: coordinate) { return }
    }

    nextLoadID += 1
    let id = nextLoadID
    let task = Task { await performDefaultRadarLoad(for: coordinate) }
    inFlightLoad = (task, coordinate, id)
    await task.value
    // A later caller may have superseded us while we were suspended; only the
    // owner of the current entry may clear it.
    if inFlightLoad?.id == id { inFlightLoad = nil }
  }

  private func performDefaultRadarLoad(for coordinate: CLLocationCoordinate2D) async {
    isLoading = true

    await updateNearestSite(for: coordinate)

    radarLog(
      "[RadarState] Loading radar → \(RadarTileProvider.preferredLive.displayName) (NOW)"
        + " + \(RadarTileProvider.preferredForecast.displayName) (FUTURE)"
    )
    let result = await loader.loadAll(site: nearestSite, coordinate: coordinate)

    // Always cache the composite result so a site product can restore it later —
    // even if the user selected one while this initial load was in flight.
    let mosaicLive = RadarLivePresentation.liveFrames(result.live, isSiteProduct: false)
    let mosaicAvailability: RadarTileAvailability =
      RadarLivePresentation.isPresentableAsLive(mosaicLive, isSiteProduct: false)
      ? result.liveAvailability
      : .unavailable(message: RadarLivePresentation.staleUnavailableMessage)
    compositeLive = (mosaicLive, mosaicAvailability)
    timeline.forecast = result.forecast
    forecastTileAvailability = result.forecastAvailability

    // Live defaults to nearest-site N0B. Don't stomp a site product (Rain/SRV)
    // if the user flipped during the load — refresh those frames instead so
    // N0B/SRV don't sit on a stale scan while the mosaic reload finishes.
    if selectedProduct.isSiteProduct {
      radarLog("[RadarState] Keeping \(selectedProduct.displayName) over composite load")
      let refreshed = await refreshActiveSiteProduct()
      if !refreshed {
        radarLog(
          "[RadarState] \(selectedProduct.displayName) refresh failed — restoring National radar"
        )
        siteProductUnavailableMessage = unavailableMessage(for: selectedProduct)
        restoreCompositeLive()
      }
      await applyDefaultLiveOpenPolicy()
    } else {
      selectedProduct = .reflectivity
      _ = commitLiveFrames(
        mosaicLive, availability: mosaicAvailability, isSiteProduct: false)
      // A composite reload means we're no longer showing the failed tap's aftermath —
      // otherwise the warning outlives the tab switch that triggered this reload.
      siteProductUnavailableMessage = nil
      activateCurrentForCommittedMode()
    }

    if let provider = result.liveProvider, !result.live.isEmpty {
      radarLog("[RadarState] \(provider.displayName) loaded (\(result.live.count) frames)")
    } else if let message = result.liveUnavailableMessage {
      radarLog("[RadarState] Live radar unavailable — \(message)")
    }

    if let provider = result.forecastProvider, !result.forecast.isEmpty {
      if result.forecastAvailability.showsTiles {
        radarLog(
          "[RadarState] Forecast ready (\(result.forecast.count) frames) — \(provider.displayName)")
      } else if let message = result.futureUnavailableMessage {
        radarLog(
          "[RadarState] Forecast timeline-only (\(result.forecast.count) frames) — \(provider.displayName): \(message)"
        )
      } else {
        radarLog(
          "[RadarState] Forecast timeline-only (\(result.forecast.count) frames) — \(provider.displayName)"
        )
      }
    } else if result.forecast.isEmpty {
      if let message = result.futureUnavailableMessage {
        radarLog("[RadarState] Forecast unavailable — \(message)")
      } else {
        radarLog("[RadarState] Forecast timeline unavailable")
      }
    }

    lastLoadedAt = Date()
    lastLoadedCoordinate = coordinate
    isLoading = false
  }
}
