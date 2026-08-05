import XCTest

@testable import DayCast

@MainActor
final class RadarPlaybackTests: XCTestCase {

  /// Playback advances one frame per tick, so the loop cap is exercised by calling
  /// `advance()` directly — no timer, no UI.
  private func makePlayback(frames: Int) -> RadarPlayback {
    let playback = RadarPlayback()
    playback.frameCount = { frames }
    playback.frameTimestamps = {
      (0..<frames).map { Date(timeIntervalSince1970: Double($0) * 300) }
    }
    return playback
  }

  /// Steps `advance()` until playback stops, or until `limit` iterations as a guard
  /// against an uncapped loop hanging the test.
  @discardableResult
  private func runUntilStopped(_ playback: RadarPlayback, limit: Int = 10_000) -> Int {
    var steps = 0
    while playback.isAnimating && steps < limit {
      playback.advance()
      steps += 1
    }
    return steps
  }

  func testAdvanceWrapsWithinTheLoopCap() {
    let playback = makePlayback(frames: 4)
    playback.start()

    playback.advance()
    playback.advance()
    playback.advance()
    XCTAssertEqual(playback.currentIndex, 3)

    // Fourth advance completes a loop and wraps — well inside the cap.
    playback.advance()
    XCTAssertEqual(playback.currentIndex, 0)
    XCTAssertTrue(playback.isAnimating)
  }

  func testPlaybackStopsAfterTheLoopCap() {
    let frames = 4
    let playback = makePlayback(frames: frames)
    playback.start()

    let steps = runUntilStopped(playback)

    XCTAssertFalse(playback.isAnimating, "playback must not animate indefinitely")
    // 9 loops of 4 frames: the final advance stops instead of wrapping.
    XCTAssertEqual(steps, 9 * frames)
  }

  func testPlaybackRestsOnTheFinalFrameWhenCapped() {
    let frames = 6
    let playback = makePlayback(frames: frames)
    playback.start()

    runUntilStopped(playback)

    // In Live the last frame is the newest scan, so stopping here leaves the map on
    // current conditions rather than the oldest frame in the loop.
    XCTAssertEqual(playback.currentIndex, frames - 1)
  }

  func testStartResetsTheLoopCounter() {
    let frames = 3
    let playback = makePlayback(frames: frames)
    playback.start()
    runUntilStopped(playback)
    XCTAssertFalse(playback.isAnimating)

    // `start()` deliberately keeps the current frame, and the cap leaves that on the
    // last one — so rewind first to measure the allowance rather than the position.
    playback.currentIndex = 0
    playback.start()
    XCTAssertTrue(playback.isAnimating)

    // Tapping play again must give a full allowance, not immediately re-stop.
    let steps = runUntilStopped(playback)
    XCTAssertEqual(steps, 9 * frames)
  }

  func testResumingAtTheEndOfALoopDoesNotGrantAnExtraPass() {
    let frames = 3
    let playback = makePlayback(frames: frames)
    playback.start()
    runUntilStopped(playback)

    // Resuming where the cap left off (the final frame) means the next advance
    // immediately completes a loop, so the fresh allowance is 9 loops from there —
    // not 9 full passes plus the partial one already on screen.
    playback.start()
    let steps = runUntilStopped(playback)

    XCTAssertEqual(steps, 1 + (8 * frames))
  }

  func testStopLeavesTheIndexAlone() {
    let playback = makePlayback(frames: 5)
    playback.start()
    playback.advance()
    playback.advance()

    playback.stop()

    XCTAssertFalse(playback.isAnimating)
    XCTAssertEqual(playback.currentIndex, 2)
  }

  func testSingleFrameTimelineNeverAnimates() {
    let playback = makePlayback(frames: 1)
    playback.start()

    XCTAssertFalse(playback.isAnimating, "a one-frame timeline has nothing to animate")
    playback.advance()
    XCTAssertEqual(playback.currentIndex, 0)
  }

  func testAdvanceIsInertWhilePaused() {
    let playback = makePlayback(frames: 4)
    playback.start()
    playback.stop()

    playback.advance()

    XCTAssertEqual(playback.currentIndex, 0, "a paused timeline must not drift")
  }

  /// A refresh can empty the timeline while playback is running. `advance()` used
  /// to return without stopping, so the tick kept rescheduling against a frozen
  /// map with the control still showing "playing".
  func testTimelineEmptiedMidPlaybackStopsAnimating() {
    var frames = 6
    let playback = RadarPlayback()
    playback.frameCount = { frames }
    playback.frameTimestamps = {
      (0..<frames).map { Date(timeIntervalSince1970: Double($0) * 300) }
    }

    playback.start()
    XCTAssertTrue(playback.isAnimating)

    frames = 0
    playback.advance()

    XCTAssertFalse(playback.isAnimating, "an emptied timeline must stop playback")
  }

  func testClampRejectsNonFiniteSpeeds() {
    // NaN survives min/max, and a NaN interval gives Timer a fire date that never
    // arrives — playback wedges with isAnimating still true.
    XCTAssertEqual(
      RadarPlayback.clampedPlaybackSpeed(.nan),
      RadarPlayback.defaultPlaybackSpeed,
      accuracy: 0.0001)
    XCTAssertEqual(
      RadarPlayback.clampedPlaybackSpeed(.infinity),
      RadarPlayback.defaultPlaybackSpeed,
      accuracy: 0.0001)
    XCTAssertEqual(RadarPlayback.clampedPlaybackSpeed(99), 4.0, accuracy: 0.0001)
    XCTAssertEqual(RadarPlayback.clampedPlaybackSpeed(-5), 0.25, accuracy: 0.0001)
  }
}
