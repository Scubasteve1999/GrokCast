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

  func testLiveLoopDropsTheThreeHourArchive() {
    let now = Date()
    let frames = (0...17).map { step in
      frame(ageMinutes: (17 - step) * 10, now: now)
    }
    let live = RadarLivePresentation.liveFrames(frames, isSiteProduct: false, now: now)
    XCTAssertFalse(live.isEmpty)
    XCTAssertEqual(live.count, 2, "15m window at 10m steps is current + -10m")
    XCTAssertTrue(
      live.allSatisfy { now.timeIntervalSince($0.timestamp) <= 15 * 60 }
    )
    XCTAssertFalse(live.contains { Int(now.timeIntervalSince($0.timestamp) / 60) >= 149 })
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
    XCTAssertTrue(
      state.timeline.live.allSatisfy {
        now.timeIntervalSince($0.timestamp) <= RadarLivePresentation.mosaicStale
      }
    )
    XCTAssertEqual(state.currentIndex, state.timeline.live.count - 1)
  }
}
