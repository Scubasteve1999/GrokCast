import Foundation

@MainActor
@Observable
final class RadarPlayback {
  /// `nonisolated` because the class is `@MainActor`, so its statics inherit that
  /// isolation, and `RadarPreferences` — which is not main-actor bound — reads
  /// `defaultPlaybackSpeed` and calls `clampedPlaybackSpeed`. Both are immutable
  /// `Sendable` values, so opting them out is safe.
  nonisolated static let defaultPlaybackSpeed: Double = 2.0
  nonisolated private static let playbackSpeedRange: ClosedRange<Double> = 0.25...4.0

  /// Single definition of the supported speed range, shared with `RadarPreferences`
  /// so a restored value can't land outside what the controls can produce.
  ///
  /// NaN is mapped to the default rather than passed through: `min`/`max`
  /// propagate it, and a NaN speed divides into a NaN frame interval, which gives
  /// `Timer` a fire date that never arrives — playback wedges with `isAnimating`
  /// still true.
  nonisolated static func clampedPlaybackSpeed(_ speedMultiplier: Double) -> Double {
    guard speedMultiplier.isFinite else { return defaultPlaybackSpeed }
    return min(max(speedMultiplier, playbackSpeedRange.lowerBound), playbackSpeedRange.upperBound)
  }

  var currentIndex: Int = 0
  var isAnimating = false
  var playbackSpeed: Double = RadarPlayback.defaultPlaybackSpeed

  var frameCount: () -> Int = { 0 }
  var frameTimestamps: () -> [Date] = { [] }
  /// Polar Site Doppler holds the playhead until the next volume's CPU mesh is warm.
  var canAdvance: () -> Bool = { true }

  private var timer: Timer?
  private var advanceHoldStarted: CFAbsoluteTime?

  /// Loops completed since playback last started. Reset in `start()`, which every
  /// resume path funnels through (play button, scrub auto-resume, tab entry, mode switch).
  private var completedLoops = 0

  /// Playback stops after this many loops rather than animating forever.
  ///
  /// Each frame transition pulls a viewport of tiles, so a Radar tab left open was an
  /// unbounded draw on provider quota — Xweather's is metered and has been exhausted
  /// before. Sized for roughly four minutes of continuous animation: long enough not
  /// to interrupt someone watching a storm, short enough to bound a tab nobody is
  /// looking at.
  ///
  /// Measured against Xweather Live, which serves ~7 frames (~1h at 10m) at the
  /// clamped 3.0s interval and default 2.0x speed. Providers with fewer frames run
  /// shorter, so this is a ceiling on the wall-clock cap, not a fixed duration.
  private static let maxLoops = 9

  private static let baselineScreenInterval: TimeInterval = 2.8
  private static let referenceDataGap: TimeInterval = 5 * 60
  /// Minimum time a frame stays on screen during playback so tiles can crossfade in.
  /// Must stay at or above the live animating fade (700ms) or the blend never lands.
  private static let minAnimatingInterval: TimeInterval = 0.72
  /// Upper bound on a single frame's screen time (before speed). Without this,
  /// wide real gaps — hourly FUTURE frames are 60 min apart — scale to ~30s per
  /// frame, so playback looks frozen. Caps every mode to a watchable cadence.
  private static let maxScreenInterval: TimeInterval = 3.0

  /// Live open/re-entry: last index is the newest scan. Play does not call this.
  func landOnNewestLiveFrame(count: Int) {
    guard count > 0 else {
      currentIndex = 0
      return
    }
    currentIndex = count - 1
  }

  /// Play from the newest scan starts at the oldest frame and walks toward now.
  /// Mid-loop resume (not on newest) keeps the current frame.
  static func playheadIndexForStart(currentIndex: Int, count: Int) -> Int {
    guard count > 1 else { return max(0, currentIndex) }
    if currentIndex >= count - 1 { return 0 }
    return currentIndex
  }

  func start() {
    let count = frameCount()
    guard count > 1 else {
      isAnimating = false
      return
    }
    // Play from newest used to sit one tick on now, then wrap — a 2-hour jump
    // that looked like Play broke radar. Begin the loop at the oldest scan.
    currentIndex = Self.playheadIndexForStart(currentIndex: currentIndex, count: count)
    timer?.invalidate()
    completedLoops = 0
    advanceHoldStarted = nil
    isAnimating = true
    scheduleNextTick()
  }

  func stop() {
    isAnimating = false
    timer?.invalidate()
    timer = nil
    advanceHoldStarted = nil
  }

  func toggle() {
    if isAnimating {
      stop()
    } else {
      start()
    }
  }

  func advance() {
    let count = frameCount()
    guard isAnimating else { return }

    // A refresh can empty the timeline mid-playback. Returning without stopping
    // left `scheduleNextTick` re-arming forever against a frozen map, with the
    // control still showing "playing".
    guard count > 1 else {
      stop()
      return
    }

    if !allowAdvance() { return }

    guard currentIndex >= count - 1 else {
      currentIndex += 1
      return
    }

    completedLoops += 1
    guard completedLoops < Self.maxLoops else {
      // Stop without wrapping, so playback rests on the final frame. In Live that
      // is the newest scan — the same place a manual pause lands — so the map is
      // left showing current conditions rather than the oldest frame in the loop.
      stop()
      return
    }
    currentIndex = 0
  }

  func setPlaybackSpeed(_ speedMultiplier: Double) {
    playbackSpeed = Self.clampedPlaybackSpeed(speedMultiplier)
    if isAnimating {
      stop()
      start()
    }
  }

  func seek(to index: Int, maxValidIndex: Int) {
    currentIndex = max(0, min(index, maxValidIndex))
    if isAnimating {
      scheduleNextTick()
    }
  }

  func clampIndex(to maxValidIndex: Int) {
    currentIndex = max(0, min(currentIndex, maxValidIndex))
  }

  func syncIndex(with frameCount: Int) {
    clampIndex(to: max(0, frameCount - 1))
    if isAnimating {
      scheduleNextTick()
    }
  }

  private func allowAdvance() -> Bool {
    if canAdvance() {
      advanceHoldStarted = nil
      return true
    }
    let now = CFAbsoluteTimeGetCurrent()
    if advanceHoldStarted == nil { advanceHoldStarted = now }
    if now - (advanceHoldStarted ?? now) >= 8 {
      advanceHoldStarted = nil
      return true
    }
    return false
  }

  private func scheduleNextTick() {
    timer?.invalidate()
    guard isAnimating else { return }

    let holding = !canAdvance()
    let interval = holding ? 0.05 : intervalUntilNextFrame()
    let t = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
      Task { @MainActor in
        guard let self, self.isAnimating else { return }
        self.advance()
        self.scheduleNextTick()
      }
    }
    t.tolerance = holding ? 0.01 : min(0.1, interval * 0.1)
    RunLoop.main.add(t, forMode: .common)
    timer = t
  }

  private func intervalUntilNextFrame() -> TimeInterval {
    let timestamps = frameTimestamps()
    let count = frameCount()
    guard count > 1, timestamps.count >= 2 else {
      return Self.baselineScreenInterval / max(playbackSpeed, 0.25)
    }

    let idx = min(max(currentIndex, 0), min(count, timestamps.count) - 1)
    let realGap: TimeInterval

    if idx < timestamps.count - 1 {
      realGap = abs(timestamps[idx + 1].timeIntervalSince(timestamps[idx]))
    } else {
      realGap = abs(
        timestamps[timestamps.count - 1].timeIntervalSince(timestamps[timestamps.count - 2]))
    }

    return compressedInterval(realGap)
  }

  private func compressedInterval(_ realGap: TimeInterval) -> TimeInterval {
    let speed = max(playbackSpeed, 0.25)
    let scaled = realGap * (Self.baselineScreenInterval / Self.referenceDataGap) / speed
    let ceiling = Self.maxScreenInterval / speed
    // Crossfade duration is wall-clock (Mapbox ms), so never advance faster than
    // minAnimatingInterval even at 2×–4× — otherwise frames queue-skip and flicker.
    let floor: TimeInterval
    if isAnimating {
      floor = max(Self.minAnimatingInterval / speed, Self.minAnimatingInterval)
    } else {
      floor = 0.15
    }
    // Floor applied last: `min(ceiling, ...)` on the outside let a ceiling below
    // the floor win, which is how a high speed produced a 30ms tick — far under
    // the crossfade duration this floor exists to protect.
    return max(floor, min(ceiling, scaled))
  }
}
