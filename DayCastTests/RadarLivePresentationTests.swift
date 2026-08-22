import XCTest

@testable import DayCast

final class RadarLivePresentationTests: XCTestCase {
  private func frame(ageMinutes: Int, now: Date) -> RadarFrame {
    let date = now.addingTimeInterval(-Double(ageMinutes) * 60)
    return RadarFrame(
      provider: .xweather,
      kind: .livePrecipitation,
      tileEpoch: Int(date.timeIntervalSince1970),
      timestamp: date,
      tileURLTemplates: ["https://example.com/{z}/{x}/{y}"]
    )
  }

  func testMosaic149mIsNotLive() {
    let now = Date()
    let frames = (0...17).map { step in
      frame(ageMinutes: (17 - step) * 10, now: now)
    }
    XCTAssertEqual(frames.count, 18)
    XCTAssertEqual(Int(RadarLivePresentation.newestAge(frames, now: now) / 60), 0)
    XCTAssertTrue(
      RadarLivePresentation.isPresentableAsLive(frames, isSiteProduct: false, now: now)
    )

    let parked = [frame(ageMinutes: 149, now: now)]
    XCTAssertFalse(
      RadarLivePresentation.isPresentableAsLive(parked, isSiteProduct: false, now: now)
    )
    XCTAssertTrue(
      RadarLivePresentation.liveFrames(parked, isSiteProduct: false, now: now).isEmpty
    )
  }

  func testLiveLoopKeepsAboutOneHourNotTheHudCap() {
    let now = Date()
    let frames = (0...17).map { step in
      frame(ageMinutes: (17 - step) * 10, now: now)
    }
    let live = RadarLivePresentation.liveFrames(frames, isSiteProduct: false, now: now)
    XCTAssertEqual(RadarLivePresentation.mosaicLoopMaxFrames, 7)
    XCTAssertEqual(RadarTimelineConfig.liveMaxFrames, 7)
    XCTAssertEqual(live.count, 7, "1h window at 10m steps is current through -60m")
    XCTAssertTrue(
      live.allSatisfy {
        now.timeIntervalSince($0.timestamp) <= RadarLivePresentation.loopWindow
      }
    )
    XCTAssertFalse(live.contains { Int(now.timeIntervalSince($0.timestamp) / 60) >= 70 })
    XCTAssertFalse(live.contains { Int(now.timeIntervalSince($0.timestamp) / 60) >= 149 })
    XCTAssertGreaterThan(
      live.count, 2, "HUD 15m trim left 2 mosaic frames and deleted Play")
  }

  func testSiteLoopKeepsNativeHourNotTenMinuteHudCap() {
    let now = Date()
    let frames = (0...11).map { step in
      frame(ageMinutes: (11 - step) * 5, now: now)
    }
    let live = RadarLivePresentation.liveFrames(frames, isSiteProduct: true, now: now)
    XCTAssertEqual(live.count, 12, "12×5m N0B volumes are ~1h, not 1–2 HUD frames")
    XCTAssertTrue(RadarLivePresentation.isPresentableAsLive(live, isSiteProduct: true, now: now))
    XCTAssertEqual(Int(RadarLivePresentation.newestAge(live, now: now) / 60), 0)
  }

  func testSiteLiveWindowIsTighterThanMosaic() {
    let now = Date()
    let twelve = [frame(ageMinutes: 12, now: now)]
    XCTAssertFalse(
      RadarLivePresentation.isPresentableAsLive(twelve, isSiteProduct: true, now: now)
    )
    XCTAssertTrue(
      RadarLivePresentation.isPresentableAsLive(twelve, isSiteProduct: false, now: now)
    )
  }

  func testCompositeNeedsReloadAtFiveAndTenMinutes() {
    let now = Date()
    let newest = now.addingTimeInterval(-3 * 60)
    XCTAssertFalse(
      RadarLivePresentation.compositeNeedsReload(
        newestTimestamp: newest, lastLoadedAt: now.addingTimeInterval(-60), now: now)
    )
    XCTAssertTrue(
      RadarLivePresentation.compositeNeedsReload(
        newestTimestamp: newest,
        lastLoadedAt: now.addingTimeInterval(-6 * 60),
        now: now)
    )
    XCTAssertTrue(
      RadarLivePresentation.compositeNeedsReload(
        newestTimestamp: now.addingTimeInterval(-11 * 60),
        lastLoadedAt: now.addingTimeInterval(-60),
        now: now)
    )
    XCTAssertTrue(
      RadarLivePresentation.compositeNeedsReload(
        newestTimestamp: nil, lastLoadedAt: now, now: now)
    )
  }

  @MainActor
  func testRestoreCompositeLiveDoesNotPaint149m() {
    let now = Date()
    let state = RadarState()
    let stale = (0...17).map { step in
      frame(ageMinutes: 149 - step, now: now)
    }
    state.seedCompositeCacheForTesting(
      frames: stale, loadedAt: now.addingTimeInterval(-149 * 60))
    state.restoreCompositeLiveForTesting()

    XCTAssertTrue(state.timeline.live.isEmpty)
    XCTAssertEqual(
      state.liveUnavailableMessage, RadarLivePresentation.staleUnavailableMessage)
    XCTAssertEqual(state.selectedProduct, .reflectivity)
  }

  @MainActor
  func testRestoreCompositeLiveKeepsCurrentScansOnly() {
    let now = Date()
    let state = RadarState()
    let frames = (0...17).map { step in
      frame(ageMinutes: (17 - step) * 10, now: now)
    }
    state.seedCompositeCacheForTesting(frames: frames, loadedAt: now)
    state.restoreCompositeLiveForTesting()

    XCTAssertFalse(state.timeline.live.isEmpty)
    XCTAssertNil(state.liveUnavailableMessage)
    XCTAssertGreaterThanOrEqual(state.timeline.live.count, 6)
    XCTAssertLessThanOrEqual(state.timeline.live.count, 7)
    XCTAssertTrue(
      state.timeline.live.allSatisfy {
        Date().timeIntervalSince($0.timestamp) <= RadarLivePresentation.loopWindow + 1
      }
    )
    XCTAssertEqual(state.currentIndex, state.timeline.live.count - 1)
    XCTAssertEqual(
      Int(now.timeIntervalSince(state.timeline.live.last!.timestamp) / 60), 0)
    XCTAssertFalse(
      state.timeline.live.contains {
        Int(now.timeIntervalSince($0.timestamp) / 60) >= 149
      })

    state.playback.start()
    XCTAssertTrue(state.isAnimating, "a 1h loop must be playable")
    XCTAssertEqual(state.currentIndex, 0, "Play from newest walks oldest → now")
    state.playback.stop()
  }

  @MainActor
  func testOpenLandsOnNewestNotOldestLoopFrame() {
    let now = Date()
    let state = RadarState()
    let frames = (0...11).map { step in
      frame(ageMinutes: (11 - step) * 5, now: now)
    }
    state.seedCompositeCacheForTesting(frames: frames, loadedAt: now)
    state.restoreCompositeLiveForTesting()
    state.presentLiveNow()

    XCTAssertEqual(state.currentIndex, state.timeline.live.count - 1)
    XCTAssertFalse(state.isAnimating)
    XCTAssertEqual(
      Int(now.timeIntervalSince(state.currentFrameDate ?? .distantPast) / 60), 0,
      "Live chip / open must not sit on a 149m or hour-old loop start")
  }
}
