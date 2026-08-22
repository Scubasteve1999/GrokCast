import XCTest

@testable import DayCast

final class MRMSNationalSourceTests: XCTestCase {
  override func setUp() {
    super.setUp()
    UserDefaults.standard.removeObject(forKey: "radar.debug.nationalPaint")
    MRMSRadarService.framesForTesting = nil
    MRMSRadarService.timestampsURLOverride = nil
  }

  override func tearDown() {
    MRMSRadarService.framesForTesting = nil
    MRMSRadarService.timestampsURLOverride = nil
    UserDefaults.standard.removeObject(forKey: "radar.debug.nationalPaint")
    super.tearDown()
  }

  func testAutoPresentsFreshFrames() {
    let now = Date()
    let frames = mrmsFrames(newestAgeMinutes: 3, count: 6, now: now)
    XCTAssertTrue(
      MRMSNationalSource.shouldPresent(frames, override: .auto, now: now)
    )
  }

  func testAutoFallsBackWhenEmpty() {
    XCTAssertFalse(
      MRMSNationalSource.shouldPresent([], override: .auto, now: Date())
    )
  }

  func testAutoFallsBackWhenNewestPastMosaicStale() {
    let now = Date()
    let frames = mrmsFrames(newestAgeMinutes: 16, count: 4, now: now)
    XCTAssertFalse(
      MRMSNationalSource.shouldPresent(frames, override: .auto, now: now)
    )
    XCTAssertEqual(MRMSNationalSource.staleThreshold, RadarLivePresentation.mosaicStale)
  }

  func testForceTilesKeepsStaleFrames() {
    let now = Date()
    let frames = mrmsFrames(newestAgeMinutes: 40, count: 3, now: now)
    XCTAssertTrue(
      MRMSNationalSource.shouldPresent(frames, override: .forceTiles, now: now)
    )
    XCTAssertFalse(
      MRMSNationalSource.shouldPresent([], override: .forceTiles, now: now)
    )
  }

  func testForceMapsGLAlwaysFallsBack() {
    let now = Date()
    let frames = mrmsFrames(newestAgeMinutes: 1, count: 8, now: now)
    XCTAssertFalse(
      MRMSNationalSource.shouldPresent(frames, override: .forceMapsGL, now: now)
    )
  }

  func testManifestDecodesNewestFirstIntoOldestToNewestFrames() {
    let newest = "2026-08-22T05:48:41Z"
    let older = "2026-08-22T04:48:41Z"
    let json = """
      {
        "product": "national",
        "frames": [
          {"t": "\(newest)", "id": "new", "template": "http://127.0.0.1:8765/new/{z}/{x}/{y}.png"},
          {"t": "\(older)", "id": "old", "template": "http://127.0.0.1:8765/old/{z}/{x}/{y}.png"}
        ]
      }
      """.data(using: .utf8)!
    let now = ISO8601DateFormatter().date(from: newest)!
    let frames = MRMSRadarService.frames(from: json, now: now)
    XCTAssertEqual(frames.count, 2)
    XCTAssertEqual(frames.first?.timestamp, ISO8601DateFormatter().date(from: older))
    XCTAssertEqual(frames.last?.timestamp, now)
    XCTAssertEqual(frames.last?.provider, .mrms)
    XCTAssertTrue(frames.last?.tileURLTemplates.first?.contains("{z}") == true)
    XCTAssertEqual(frames.last?.tileKey.split(separator: ":").first, "mrms")
  }

  func testChromeNeverSaysMRMS() {
    XCTAssertEqual(RadarTileProvider.mrms.displayName, "National radar")
    XCTAssertEqual(RadarTileProvider.mrms.liveFooterLabel, "Live radar · National radar")
    XCTAssertEqual(RadarTileProvider.mrms.hudSourceLabel, "NATIONAL")
    XCTAssertFalse(RadarTileProvider.mrms.displayName.localizedCaseInsensitiveContains("MRMS"))
    XCTAssertFalse(RadarTileProvider.mrms.liveFooterLabel.localizedCaseInsensitiveContains("MRMS"))
    XCTAssertFalse(RadarProduct.reflectivity.displayName.localizedCaseInsensitiveContains("MRMS"))
  }

  func testMapsGLRainOffWhenNationalUsesMRMS() {
    XCTAssertFalse(
      MapsGLRadarPalette.shouldUseMapsGL(
        overlayOn: true, isSiteProduct: false, keysPresent: true, nationalUsesMRMS: true)
    )
    XCTAssertFalse(
      MapsGLLiveRainLayers.shouldAttachRadar(
        overlayOn: true, isSiteProduct: false, keysPresent: true, nationalUsesMRMS: true)
    )
    XCTAssertTrue(
      MapsGLLiveRainLayers.shouldShow(
        overlayOn: true, isSiteProduct: false, keysPresent: true, isLive: true)
    )
    XCTAssertTrue(
      MapsGLRadarPalette.shouldUseMapsGL(
        overlayOn: true, isSiteProduct: false, keysPresent: true, nationalUsesMRMS: false)
    )
  }

  @MainActor
  func testRadarStateFlagsMRMSPaintFromLiveProvider() {
    let now = Date()
    let frames = mrmsFrames(newestAgeMinutes: 2, count: 5, now: now)
    let state = RadarState()
    state.seedCompositeCacheForTesting(frames: frames, loadedAt: now)
    state.restoreCompositeLiveForTesting()
    XCTAssertEqual(state.selectedProduct, .reflectivity)
    XCTAssertEqual(state.activeLiveProvider, .mrms)
    XCTAssertTrue(state.nationalUsesMRMSPaint)
  }

  private func mrmsFrames(newestAgeMinutes: Int, count: Int, now: Date) -> [RadarFrame] {
    (0..<count).map { step in
      let age = newestAgeMinutes + (count - 1 - step) * 2
      return RadarFrame(
        provider: .mrms,
        kind: .livePrecipitation,
        tileEpoch: Int(now.timeIntervalSince1970) - age * 60,
        timestamp: now.addingTimeInterval(TimeInterval(-age * 60)),
        tileURLTemplates: ["http://127.0.0.1:8765/\(age)/{z}/{x}/{y}.png"]
      )
    }
  }
}
