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

  func testProductMatchingLocalNowFollowsLiveOpenRule() {
    XCTAssertEqual(
      RadarLiveOpenPolicy.productMatchingLocalNow(hasPrecip: true),
      .siteDoppler
    )
    XCTAssertEqual(
      RadarLiveOpenPolicy.productMatchingLocalNow(hasPrecip: false),
      .nationalRadar
    )
  }

  func testTodayRadarTeaserCopyMatchesNationalPreview() {
    XCTAssertEqual(
      RadarFeedCopy.title(conditionCode: 61),
      "Rain now · National radar"
    )
    XCTAssertEqual(
      RadarFeedCopy.title(conditionCode: 95),
      "Storm now · National radar"
    )
    XCTAssertEqual(
      RadarFeedCopy.title(conditionCode: 71),
      "Snow now · National radar"
    )
    XCTAssertEqual(
      RadarFeedCopy.title(conditionCode: 66),
      "Sleet now · National radar"
    )
    XCTAssertEqual(
      RadarFeedCopy.title(conditionCode: 51),
      "Rain now · National radar"
    )
    XCTAssertEqual(
      RadarFeedCopy.title(conditionCode: 0),
      "Local is clear · National radar"
    )
    XCTAssertEqual(
      RadarFeedCopy.title(conditionCode: 3),
      "Local is clear · National radar"
    )
    XCTAssertEqual(
      RadarFeedCopy.title(conditionCode: 0, siteID: "NQA"),
      "NQA is clear · National radar"
    )
    XCTAssertEqual(
      RadarFeedCopy.accessibilityLabel(conditionCode: 61),
      "Rain now. National radar. Opens the Radar tab."
    )
    XCTAssertEqual(
      RadarFeedCopy.accessibilityLabel(conditionCode: 0),
      "Local is clear. National radar. Opens the Radar tab."
    )
    let strings = [
      RadarFeedCopy.title(conditionCode: 61),
      RadarFeedCopy.title(conditionCode: 95),
      RadarFeedCopy.title(conditionCode: 71),
      RadarFeedCopy.title(conditionCode: 66),
      RadarFeedCopy.title(conditionCode: 0),
      RadarFeedCopy.accessibilityLabel(conditionCode: 61),
      RadarFeedCopy.accessibilityLabel(conditionCode: 0),
    ]
    for copy in strings {
      XCTAssertTrue(copy.localizedCaseInsensitiveContains("National radar"), copy)
      XCTAssertFalse(copy.localizedCaseInsensitiveContains("Site Doppler"), copy)
      XCTAssertFalse(copy.localizedCaseInsensitiveContains("Mosaic"), copy)
      XCTAssertFalse(copy == "Radar. Opens the Radar tab.", copy)
    }
  }

  func testHoistedSiteDopplerCopyNamesSiteAndScanAge() {
    let age = ChaseRadarHUDLogic.scanAgeLine(
      showsFuture: false, futureFrameLabel: "", ageMinutes: 3)
    XCTAssertEqual(age, "SCAN 3m")
    XCTAssertEqual(
      RadarFeedCopy.siteTitle(conditionCode: 61, siteID: "NQA", ageLine: age),
      "Rain now · NQA"
    )
    XCTAssertEqual(
      RadarFeedCopy.siteTitle(conditionCode: 95, siteID: "NQA", ageLine: age),
      "Storm now · NQA"
    )
    XCTAssertEqual(
      RadarFeedCopy.siteTitle(conditionCode: 71, siteID: "NQA", ageLine: age),
      "Snow now · NQA"
    )
    XCTAssertEqual(
      RadarFeedCopy.siteTitle(conditionCode: 66, siteID: "NQA", ageLine: age),
      "Sleet now · NQA"
    )
    XCTAssertEqual(
      RadarFeedCopy.siteTitle(conditionCode: 0, siteID: "NQA", ageLine: age),
      "NQA is clear · SCAN 3m"
    )
    XCTAssertEqual(
      RadarFeedCopy.siteAccessibilityLabel(
        conditionCode: 61, siteID: "NQA", ageLine: age),
      "Rain now. NQA. Site Doppler. SCAN 3m. Opens the Radar tab."
    )
    XCTAssertEqual(
      RadarFeedCopy.siteAccessibilityLabel(
        conditionCode: 0, siteID: "NQA", ageLine: age),
      "NQA is clear. SCAN 3m. Site Doppler. Opens the Radar tab."
    )
    XCTAssertEqual(RadarFeedCopy.failLine(siteID: "NQA"), "NQA · scan unavailable")
    XCTAssertEqual(
      RadarFeedCopy.headline(
        conditionCode: 61,
        siteID: "NQA",
        ageLine: "SCAN <1m",
        hoisted: true,
        availability: .unavailable,
        paint: .siteDoppler
      ),
      "NQA · scan unavailable"
    )
    XCTAssertEqual(
      RadarFeedCopy.headline(
        conditionCode: 0,
        siteID: nil,
        ageLine: "SCAN —",
        hoisted: false,
        availability: .unavailable,
        paint: .unavailable
      ),
      RadarChromeCopy.unavailableTitle
    )
    XCTAssertEqual(
      RadarFeedCopy.headline(
        conditionCode: 61,
        siteID: "NQA",
        ageLine: "SCAN 18m",
        hoisted: true,
        availability: .stale,
        paint: .siteDoppler
      ),
      "Stale · SCAN 18m"
    )
    XCTAssertEqual(
      RadarFeedCopy.failLine(siteID: nil),
      "Site Doppler · scan unavailable"
    )
    XCTAssertEqual(RadarFeedCopy.siteProductName, "Site Doppler")
    let wet = RadarFeedCopy.siteTitle(conditionCode: 61, siteID: "NQA", ageLine: age)
    XCTAssertFalse(wet.localizedCaseInsensitiveContains("National radar"))
    XCTAssertFalse(wet.localizedCaseInsensitiveContains("Mosaic"))
    XCTAssertTrue(wet.contains("NQA"))
  }

  func testHoistedPreviewNeverResolvesToBlankRect() {
    XCTAssertEqual(
      RadarPreviewPaint.resolve(
        hoisted: true, hasDrawableSweep: true, mapboxPresent: true, mapsGLKeysPresent: true),
      .siteDoppler
    )
    XCTAssertEqual(
      RadarPreviewPaint.resolve(
        hoisted: true, hasDrawableSweep: false, mapboxPresent: true, mapsGLKeysPresent: true),
      .unavailable
    )
    XCTAssertEqual(
      RadarPreviewPaint.resolve(
        hoisted: true, hasDrawableSweep: true, mapboxPresent: false, mapsGLKeysPresent: true),
      .unavailable
    )
    XCTAssertEqual(
      RadarPreviewPaint.resolve(
        hoisted: false, hasDrawableSweep: false, mapboxPresent: true, mapsGLKeysPresent: true),
      .nationalMapsGL
    )
    XCTAssertEqual(
      RadarPreviewPaint.resolve(
        hoisted: false, hasDrawableSweep: false, mapboxPresent: false, mapsGLKeysPresent: true),
      .unavailable
    )
    XCTAssertEqual(RadarPreviewSource.siteZoom, RadarLiveCameraPolicy.localZoom)
    XCTAssertEqual(RadarPreviewSource.previewZoom, RadarLiveCameraPolicy.conusZoom)
    XCTAssertEqual(RadarPreviewSource.teaserHeight, 72)
    XCTAssertLessThan(RadarPreviewSource.teaserHeight, 160)
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

  @MainActor
  func testNationalDownRestoresCachedSiteDoppler() async {
    let now = Date()
    let state = RadarState()
    state.seedCompositeCacheForTesting(frames: [], loadedAt: now)
    let site = IEMRadarService.Site(id: "NQA", name: "Memphis", lon: -89.9, lat: 35.0)
    state.seedSiteLiveForTesting(
      site: site,
      frames: [frame(ageMinutes: 2, now: now, provider: .iem)]
    )
    state.restoreCompositeLiveForTesting()
    state.sitePrecipProbeForTesting = false

    await state.applyDefaultLiveOpenPolicyForTesting()

    XCTAssertEqual(state.selectedProduct, .superResReflectivity)
    XCTAssertFalse(state.timeline.live.isEmpty)
    XCTAssertEqual(state.cameraRequest?.zoom, RadarLiveCameraPolicy.localZoom)
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
