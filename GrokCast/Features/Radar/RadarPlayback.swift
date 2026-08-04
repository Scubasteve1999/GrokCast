import Foundation

@MainActor
@Observable
final class RadarPlayback {
  var currentIndex: Int = 0
  var isAnimating = false
  var playbackSpeed: Double = 2.0

  var frameCount: () -> Int = { 0 }
  var frameTimestamps: () -> [Date] = { [] }

  private var timer: Timer?

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
  /// Measured against Xweather Live, which serves ~18 frames at the clamped 3.0s
  /// interval and default 2.0x speed — a ~27s loop. Providers with fewer frames run
  /// shorter, so this is a ceiling on the wall-clock cap, not a fixed duration.
  private static let maxLoops = 9

  private static let baselineScreenInterval: TimeInterval = 2.8
  private static let referenceDataGap: TimeInterval = 5 * 60
  /// Minimum time a frame stays on screen during playback so tiles can crossfade in.
  private static let minAnimatingInterval: TimeInterval = 0.45
  /// Upper bound on a single frame's screen time (before speed). Without this,
  /// wide real gaps — hourly FUTURE frames are 60 min apart — scale to ~30s per
  /// frame, so playback looks frozen. Caps every mode to a watchable cadence.
  private static let maxScreenInterval: TimeInterval = 3.0

  func start() {
    let count = frameCount()
    guard count > 1 else {
      isAnimating = false
      return
    }
    // Stay on the current frame (usually newest after load). Looping wraps in
    // `advance()` — do not jump to the oldest frame when opening / resuming Live.
    timer?.invalidate()
    completedLoops = 0
    isAnimating = true
    scheduleNextTick()
  }

  func stop() {
    isAnimating = false
    timer?.invalidate()
    timer = nil
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
    guard isAnimating, count > 1 else { return }

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
    playbackSpeed = max(0.25, min(speedMultiplier, 4.0))
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

  private func scheduleNextTick() {
    timer?.invalidate()
    guard isAnimating else { return }

    let interval = intervalUntilNextFrame()
    let t = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
      Task { @MainActor in
        guard let self, self.isAnimating else { return }
        self.advance()
        self.scheduleNextTick()
      }
    }
    t.tolerance = min(0.1, interval * 0.1)
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
    return min(ceiling, max(floor, scaled))
  }
}
