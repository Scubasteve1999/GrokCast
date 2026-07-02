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
        style: provider == .rainViewer ? .secondary : .warning
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

    guard timeline.hasForecast, !showsFuture, transition == nil else { return }

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
    if committedIsFuture, playback.playbackSpeed > 1.0 {
      playback.playbackSpeed = 1.0
    }
    activateCurrentForCommittedMode()
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

  func loadDefaultRadar(for coordinate: CLLocationCoordinate2D) async {
    _ = coordinate
    guard !isLoading else { return }
    isLoading = true

    print(
      "[RadarState] Loading radar → \(RadarTileProvider.preferredLive.displayName) (NOW)"
        + " + \(RadarTileProvider.preferredForecast.displayName) (FUTURE)"
    )
    let result = await loader.loadAll()

    timeline.live = result.live
    timeline.forecast = result.forecast
    liveTileAvailability = result.liveAvailability
    forecastTileAvailability = result.forecastAvailability
    activateCurrentForCommittedMode()

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

    isLoading = false
  }
}
