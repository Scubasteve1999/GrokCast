import CoreLocation
import XCTest

@testable import DayCast

final class ChaseRadarHUDTests: XCTestCase {
  func testScanAgeLineForFutureMode() {
    let line = ChaseRadarHUDLogic.scanAgeLine(
      showsFuture: true,
      futureFrameLabel: "4:30 PM",
      ageMinutes: 99
    )
    XCTAssertEqual(line, "24-hr 4:30 PM")
    XCTAssertFalse(line.contains("FUT"))
  }

  func testScanDateKeysOffNewestFrameNotTheScrubbedFrame() {
    let now = Date()
    let visible = now.addingTimeInterval(-50 * 60)
    let newest = now.addingTimeInterval(-3 * 60)
    let shown = ChaseRadarHUDLogic.scanDateForDisplay(
      currentFrameDate: visible,
      newestTimestamp: newest,
      isAnimating: true,
      showsFuture: false
    )
    XCTAssertEqual(shown, newest)
    XCTAssertEqual(ChaseRadarHUDLogic.scanAgeMinutes(now: now, scanDate: shown), 3)

    let future = ChaseRadarHUDLogic.scanDateForDisplay(
      currentFrameDate: visible,
      newestTimestamp: newest,
      isAnimating: false,
      showsFuture: true
    )
    XCTAssertEqual(future, visible)
  }

  func testScanAgeLineBuckets() {
    XCTAssertEqual(
      ChaseRadarHUDLogic.scanAgeLine(showsFuture: false, futureFrameLabel: "", ageMinutes: nil),
      "SCAN —"
    )
    XCTAssertEqual(
      ChaseRadarHUDLogic.scanAgeLine(showsFuture: false, futureFrameLabel: "", ageMinutes: 0),
      "SCAN <1m"
    )
    XCTAssertEqual(
      ChaseRadarHUDLogic.scanAgeLine(showsFuture: false, futureFrameLabel: "", ageMinutes: 3),
      "SCAN 3m"
    )
  }

  func testSiteProductUsesTighterFreshnessThresholds() {
    // 7 minutes: aging for site, still fresh for mosaic.
    XCTAssertEqual(
      ChaseRadarHUDLogic.scanFreshness(showsFuture: false, ageMinutes: 7, isSiteProduct: true),
      .aging
    )
    XCTAssertEqual(
      ChaseRadarHUDLogic.scanFreshness(showsFuture: false, ageMinutes: 7, isSiteProduct: false),
      .fresh
    )

    XCTAssertEqual(
      ChaseRadarHUDLogic.scanFreshness(showsFuture: false, ageMinutes: 12, isSiteProduct: true),
      .stale
    )
    XCTAssertEqual(
      ChaseRadarHUDLogic.scanFreshness(showsFuture: false, ageMinutes: 12, isSiteProduct: false),
      .aging
    )
  }

  func testHudCityAndProductArePlainLanguage() {
    XCTAssertEqual(
      ChaseRadarHUDLogic.hudCityLine(locationName: "San Francisco, CA"),
      "San Francisco"
    )
    XCTAssertEqual(ChaseRadarHUDLogic.hudCityLine(locationName: "Seattle, WA"), "Seattle")
    XCTAssertEqual(ChaseRadarHUDLogic.hudCityLine(locationName: nil), "This location")
    XCTAssertEqual(
      ChaseRadarHUDLogic.lookingAtLine(product: .reflectivity, showsFuture: false),
      "National radar"
    )
    XCTAssertEqual(
      ChaseRadarHUDLogic.lookingAtLine(product: .reflectivity, showsFuture: true),
      "24-hr · National radar"
    )
    XCTAssertEqual(
      ChaseRadarHUDLogic.lookingAtLine(product: .stormRelativeVelocity, showsFuture: false),
      "Storm winds"
    )
    let national = ChaseRadarHUDLogic.lookingAtLine(product: .reflectivity, showsFuture: false)
    XCTAssertFalse(national.localizedCaseInsensitiveContains("XWEATHER"))
    XCTAssertFalse(national.localizedCaseInsensitiveContains("Mosaic"))
    XCTAssertFalse(national.contains("RAIN"))
  }

  func testHudLinesStayOperationalNotOutlook() {
    // SPC Day 1 / outlook lives on Alerts and Today, not the chase strip.
    let product = ChaseRadarHUDLogic.lookingAtLine(
      product: .superResReflectivity, showsFuture: false, siteID: "TFX")
    let site = ChaseRadarHUDLogic.lookingAtSiteSecondary(
      product: .superResReflectivity, showsFuture: false, siteID: "TFX")
    XCTAssertEqual(product, "Site Doppler")
    XCTAssertEqual(site, "TFX")
    XCTAssertFalse(product.localizedCaseInsensitiveContains("Day 1"))
    XCTAssertFalse(product.localizedCaseInsensitiveContains("outlook"))
    XCTAssertNil(
      ChaseRadarHUDLogic.nearestAlertLine(
        alerts: [],
        mapCenter: CLLocationCoordinate2D(latitude: 47.5, longitude: -111.3)
      )
    )
  }

  func testLookingAtLineNamesNearestSiteDoppler() {
    XCTAssertEqual(
      ChaseRadarHUDLogic.lookingAtLine(
        product: .superResReflectivity, showsFuture: false, siteID: "NQA"),
      "Site Doppler"
    )
    XCTAssertEqual(
      ChaseRadarHUDLogic.lookingAtSiteSecondary(
        product: .superResReflectivity, showsFuture: false, siteID: "NQA"),
      "NQA"
    )
    XCTAssertEqual(
      ChaseRadarHUDLogic.lookingAtSiteSecondary(
        product: .superResReflectivity, showsFuture: false, siteID: "KNQA"),
      "KNQA"
    )
    XCTAssertEqual(
      ChaseRadarHUDLogic.lookingAtLine(product: .superResReflectivity, showsFuture: false),
      "Site Doppler"
    )
    XCTAssertNil(
      ChaseRadarHUDLogic.lookingAtSiteSecondary(
        product: .superResReflectivity, showsFuture: false, siteID: nil)
    )
    XCTAssertEqual(
      ChaseRadarHUDLogic.lookingAtLine(
        product: .stormRelativeVelocity, showsFuture: false, siteID: "NQA"),
      "Storm winds"
    )
    XCTAssertEqual(
      ChaseRadarHUDLogic.lookingAtLine(
        product: .reflectivity, showsFuture: false, siteID: "NQA"),
      "National radar"
    )
    XCTAssertNil(
      ChaseRadarHUDLogic.lookingAtSiteSecondary(
        product: .reflectivity, showsFuture: false, siteID: "NQA")
    )
    let site = ChaseRadarHUDLogic.lookingAtLine(
      product: .superResReflectivity, showsFuture: false, siteID: "NQA")
    XCTAssertFalse(site.localizedCaseInsensitiveContains("XWEATHER"))
    XCTAssertFalse(site.localizedCaseInsensitiveContains("Mosaic"))
    XCTAssertFalse(site.localizedCaseInsensitiveContains("Xweather"))
  }

  func testShortEventSpeaksTheWarning() {
    XCTAssertEqual(ChaseRadarHUDLogic.shortEvent("Tornado Warning"), "Tornado Warning")
    XCTAssertEqual(ChaseRadarHUDLogic.shortEvent("Severe Thunderstorm Watch"), "Severe Thunderstorm Watch")
    XCTAssertEqual(ChaseRadarHUDLogic.shortEvent("Flash Flood Warning"), "Flash Flood Warning")
    XCTAssertEqual(
      ChaseRadarHUDLogic.shortEvent("Special Weather Statement"),
      "Special Weather Statement"
    )
    XCTAssertEqual(ChaseRadarHUDLogic.shortEvent("Winter Storm Warning"), "Winter Storm Warning")
    XCTAssertFalse(ChaseRadarHUDLogic.shortEvent("Tornado Warning").contains("TOR"))
    XCTAssertFalse(ChaseRadarHUDLogic.shortEvent("Severe Thunderstorm Warning").contains("SVR"))
  }

  func testCoveringAlertTakesPriorityOverDistance() {
    let covering = NWSAlert(
      id: "1",
      event: "Tornado Warning",
      severity: "Extreme",
      headline: nil,
      description: nil,
      instruction: nil,
      expires: nil,
      areaDesc: nil,
      latitude: 34.0,
      longitude: -90.0,
      containsSelectedPoint: true
    )
    let distant = NWSAlert(
      id: "2",
      event: "Severe Thunderstorm Warning",
      severity: "Severe",
      headline: nil,
      description: nil,
      instruction: nil,
      expires: nil,
      areaDesc: nil,
      latitude: 35.0,
      longitude: -89.0,
      containsSelectedPoint: false
    )
    let result = ChaseRadarHUDLogic.nearestAlertLine(
      alerts: [distant, covering],
      mapCenter: CLLocationCoordinate2D(latitude: 34.96, longitude: -89.83)
    )
    XCTAssertEqual(result?.text, "IN Tornado Warning")
    XCTAssertEqual(result?.isCovering, true)
    XCTAssertEqual(result?.isLifeThreatening, true)
  }

  func testNearestAlertReportsDistanceWhenNoneCover() {
    let alert = NWSAlert(
      id: "3",
      event: "Severe Thunderstorm Warning",
      severity: "Severe",
      headline: nil,
      description: nil,
      instruction: nil,
      expires: nil,
      areaDesc: nil,
      latitude: 35.0,
      longitude: -89.0,
      containsSelectedPoint: false
    )
    let result = ChaseRadarHUDLogic.nearestAlertLine(
      alerts: [alert],
      mapCenter: CLLocationCoordinate2D(latitude: 34.96, longitude: -89.83)
    )
    XCTAssertEqual(result?.text.contains("Severe Thunderstorm Warning"), true)
    XCTAssertFalse(result?.text.contains("SVR") == true)
    XCTAssertEqual(result?.isCovering, false)
  }
}
