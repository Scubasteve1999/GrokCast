import CoreLocation
import XCTest

@testable import DayCast

final class RadarLiveOpenPolicyTests: XCTestCase {
  func testDrySiteOpenPresentsNationalRadar() {
    XCTAssertEqual(
      RadarLiveOpenPolicy.productToPresent(
        userExplicitlyChoseSiteDoppler: false,
        siteDopplerLoaded: true,
        siteHasPrecipInLiveWindow: false,
        siteFailedOrStale: false,
        nationalAvailable: true),
      .nationalRadar
    )
  }

  func testWetSiteOpenStaysOnSiteDoppler() {
    XCTAssertEqual(
      RadarLiveOpenPolicy.productToPresent(
        userExplicitlyChoseSiteDoppler: false,
        siteDopplerLoaded: true,
        siteHasPrecipInLiveWindow: true,
        siteFailedOrStale: false,
        nationalAvailable: true),
      .siteDoppler
    )
  }

  func testFailedOrStaleSitePresentsNationalWhenAvailable() {
    XCTAssertEqual(
      RadarLiveOpenPolicy.productToPresent(
        userExplicitlyChoseSiteDoppler: false,
        siteDopplerLoaded: false,
        siteHasPrecipInLiveWindow: false,
        siteFailedOrStale: true,
        nationalAvailable: true),
      .nationalRadar
    )
  }

  func testExplicitDrySiteTapStaysOnSiteDoppler() {
    XCTAssertEqual(
      RadarLiveOpenPolicy.productToPresent(
        userExplicitlyChoseSiteDoppler: true,
        siteDopplerLoaded: true,
        siteHasPrecipInLiveWindow: false,
        siteFailedOrStale: false,
        nationalAvailable: true),
      .siteDoppler
    )
  }

  func testNoNationalKeepsSiteEvenWhenDry() {
    XCTAssertEqual(
      RadarLiveOpenPolicy.productToPresent(
        userExplicitlyChoseSiteDoppler: false,
        siteDopplerLoaded: true,
        siteHasPrecipInLiveWindow: false,
        siteFailedOrStale: false,
        nationalAvailable: false),
      .siteDoppler
    )
  }

  func testSiteStillLoadingPresentsNationalWhenAvailable() {
    XCTAssertEqual(
      RadarLiveOpenPolicy.productToPresent(
        userExplicitlyChoseSiteDoppler: false,
        siteDopplerLoaded: false,
        siteHasPrecipInLiveWindow: false,
        siteFailedOrStale: false,
        nationalAvailable: true),
      .nationalRadar
    )
  }

  func testClearHintUsesSiteIdOrLocal() {
    XCTAssertEqual(RadarLiveOpenPolicy.clearHint(siteID: "NQA"), "NQA is clear")
    XCTAssertEqual(RadarLiveOpenPolicy.clearHint(siteID: nil), "Local is clear")
    XCTAssertEqual(RadarLiveOpenPolicy.clearHint(siteID: ""), "Local is clear")
  }

  func testUserVisibleLabelsNeverSayMosaic() {
    XCTAssertEqual(RadarProduct.reflectivity.displayName, "National radar")
    XCTAssertEqual(RadarProduct.superResReflectivity.displayName, "Site Doppler")
    XCTAssertFalse(RadarProduct.reflectivity.displayName.localizedCaseInsensitiveContains("Mosaic"))
    XCTAssertFalse(
      RadarProduct.superResReflectivity.displayName.localizedCaseInsensitiveContains("Mosaic"))
    XCTAssertEqual(RadarTileProvider.iem.liveFooterLabel, "Live radar · National radar")
    XCTAssertFalse(RadarTileProvider.iem.liveFooterLabel.localizedCaseInsensitiveContains("mosaic"))
  }

  @MainActor
  func testLiveOpenFlipsDrySiteToNationalAndLandsOnNewest() async {
    let now = Date()
    let state = RadarState()
    let national = (0...6).map { step in
      frame(ageMinutes: (6 - step) * 10, now: now)
    }
    state.seedCompositeCacheForTesting(frames: national, loadedAt: now)

    let site = IEMRadarService.Site(id: "NQA", name: "Memphis", lon: -89.9, lat: 35.0)
    let siteFrames = (0...5).map { step in
      frame(ageMinutes: (5 - step) * 5, now: now, provider: .iem)
    }
    state.seedSiteLiveForTesting(site: site, frames: siteFrames)
    state.sitePrecipProbeForTesting = false
    state.usesNationalPrecipOverrideForTesting = true
    state.nationalPrecipMetersForTesting = 1_100_000

    await state.applyDefaultLiveOpenPolicyForTesting()

    XCTAssertEqual(state.selectedProduct, .reflectivity)
    XCTAssertEqual(state.selectedProduct.displayName, "National radar")
    XCTAssertFalse(state.timeline.live.isEmpty)
    XCTAssertEqual(state.currentIndex, state.timeline.live.count - 1)
    XCTAssertEqual(state.siteProductAdvisory, "NQA is clear")
    XCTAssertLessThan(state.cameraRequest?.zoom ?? 99, RadarLiveCameraPolicy.localZoom)
    XCTAssertGreaterThanOrEqual(
      state.cameraRequest?.zoom ?? 0, RadarLiveCameraPolicy.conusZoom)
    XCTAssertEqual(state.cameraRequest?.latitude ?? 0, 35.0, accuracy: 0.01)
  }

  @MainActor
  func testWetSiteOpenStaysOnSiteDopplerInState() async {
    let now = Date()
    let state = RadarState()
    let national = (0...6).map { step in
      frame(ageMinutes: (6 - step) * 10, now: now)
    }
    state.seedCompositeCacheForTesting(frames: national, loadedAt: now)

    let site = IEMRadarService.Site(id: "NQA", name: "Memphis", lon: -89.9, lat: 35.0)
    let siteFrames = (0...5).map { step in
      frame(ageMinutes: (5 - step) * 5, now: now, provider: .iem)
    }
    state.seedSiteLiveForTesting(site: site, frames: siteFrames)
    state.sitePrecipProbeForTesting = true

    await state.applyDefaultLiveOpenPolicyForTesting()

    XCTAssertEqual(state.selectedProduct, .superResReflectivity)
    XCTAssertEqual(state.selectedProduct.displayName, "Site Doppler")
    XCTAssertEqual(state.cameraRequest?.zoom, RadarLiveCameraPolicy.localZoom)
  }

  @MainActor
  func testPinnedDrySiteIsNotAutoFlipped() async {
    let now = Date()
    let state = RadarState()
    let national = (0...6).map { step in
      frame(ageMinutes: (6 - step) * 10, now: now)
    }
    state.seedCompositeCacheForTesting(frames: national, loadedAt: now)
    let site = IEMRadarService.Site(id: "NQA", name: "Memphis", lon: -89.9, lat: 35.0)
    state.seedSiteLiveForTesting(
      site: site,
      frames: [frame(ageMinutes: 2, now: now, provider: .iem)]
    )
    state.sitePrecipProbeForTesting = false
    state.setUserPinnedSiteDopplerForTesting(true)

    await state.applyDefaultLiveOpenPolicyForTesting()

    XCTAssertEqual(state.selectedProduct, .superResReflectivity)
    XCTAssertEqual(state.cameraRequest?.zoom, RadarLiveCameraPolicy.localZoom)
  }

  @MainActor
  func testFailedSiteKeepsUnavailableCopyOnNational() async {
    let now = Date()
    let state = RadarState()
    let national = (0...6).map { step in
      frame(ageMinutes: (6 - step) * 10, now: now)
    }
    state.seedCompositeCacheForTesting(frames: national, loadedAt: now)
    let site = IEMRadarService.Site(id: "NQA", name: "Memphis", lon: -89.9, lat: 35.0)
    state.seedSiteLiveForTesting(site: site, frames: [])
    state.sitePrecipProbeForTesting = false
    state.usesNationalPrecipOverrideForTesting = true
    state.nationalPrecipMetersForTesting = nil

    await state.applyDefaultLiveOpenPolicyForTesting()

    XCTAssertEqual(state.selectedProduct, .reflectivity)
    XCTAssertFalse(state.timeline.live.isEmpty)
    XCTAssertEqual(state.cameraRequest?.zoom, RadarLiveCameraPolicy.conusZoom)
  }

  func testNQATilesCoverTheSiteUmbrella() {
    let nqa = IEMRadarService.Site(id: "NQA", name: "Memphis", lon: -89.983, lat: 34.984)
    let origin = IEMRadarService.webMercatorTile(
      lat: nqa.lat, lon: nqa.lon, zoom: IEMRadarService.precipProbeZoom)
    let tiles = IEMRadarService.tilesCoveringSite(nqa, zoom: IEMRadarService.precipProbeZoom)
    XCTAssertFalse(tiles.isEmpty)
    XCTAssertTrue(tiles.contains { $0.x == origin.x && $0.y == origin.y })
    XCTAssertLessThanOrEqual(tiles.count, 9)
    let here = CLLocation(latitude: nqa.lat, longitude: nqa.lon)
    for tile in tiles {
      let center = IEMRadarService.tileCenter(
        x: tile.x, y: tile.y, zoom: IEMRadarService.precipProbeZoom)
      let meters = here.distance(
        from: CLLocation(latitude: center.lat, longitude: center.lon))
      XCTAssertLessThanOrEqual(meters, IEMRadarService.precipProbeRangeMeters + 1)
    }
  }

  @MainActor
  func testHandleLiveOpenClearsPinAndFitsDryNationalCamera() async {
    let now = Date()
    let state = RadarState()
    let national = (0...6).map { step in
      frame(ageMinutes: (6 - step) * 10, now: now)
    }
    state.seedCompositeCacheForTesting(frames: national, loadedAt: now)
    let site = IEMRadarService.Site(id: "NQA", name: "Memphis", lon: -89.9, lat: 35.0)
    state.seedSiteLiveForTesting(
      site: site,
      frames: [frame(ageMinutes: 2, now: now, provider: .iem)]
    )
    state.sitePrecipProbeForTesting = false
    state.usesNationalPrecipOverrideForTesting = true
    state.nationalPrecipMetersForTesting = nil
    state.setUserPinnedSiteDopplerForTesting(true)

    await state.handleLiveOpen(
      for: CLLocationCoordinate2D(latitude: site.lat, longitude: site.lon))

    XCTAssertEqual(state.selectedProduct, .reflectivity)
    XCTAssertEqual(state.siteProductAdvisory, "NQA is clear")
    XCTAssertEqual(state.cameraRequest?.zoom, RadarLiveCameraPolicy.conusZoom)
    XCTAssertEqual(state.currentIndex, state.timeline.live.count - 1)
  }

  private func frame(
    ageMinutes: Int, now: Date, provider: RadarTileProvider = .xweather
  ) -> RadarFrame {
    let date = now.addingTimeInterval(-Double(ageMinutes) * 60)
    return RadarFrame(
      provider: provider,
      kind: .livePrecipitation,
      tileEpoch: Int(date.timeIntervalSince1970),
      timestamp: date,
      tileURLTemplates: ["https://example.com/{z}/{x}/{y}"]
    )
  }
}
