import XCTest

@testable import DayCast

final class ForecastEraNoticeTests: XCTestCase {
  private static let suiteName = "ForecastEraNoticeTests"
  private var suite: UserDefaults!

  override func setUp() {
    super.setUp()
    UserDefaults.standard.removePersistentDomain(forName: Self.suiteName)
    suite = UserDefaults(suiteName: Self.suiteName)
    ForecastEraNotice.store = suite
  }

  override func tearDown() {
    ForecastEraNotice.store = .standard
    suite.removePersistentDomain(forName: Self.suiteName)
    suite = nil
    super.tearDown()
  }

  func testCutoverIs14October2026At1200UTC() {
    XCTAssertEqual(ForecastEraNotice.cutoverUTC, utc("2026-10-14T12:00:00Z"))
    XCTAssertEqual(ForecastEraNotice.windowStartUTC, utc("2026-10-07T12:00:00Z"))
    XCTAssertEqual(ForecastEraNotice.windowEndUTC, utc("2026-10-28T12:00:00Z"))
  }

  func testHiddenBeforeWindow() {
    let now = utc("2026-10-07T11:59:59Z")
    XCTAssertFalse(ForecastEraNotice.isInWindow(now: now))
    XCTAssertFalse(ForecastEraNotice.shouldShowBanner(now: now, defaults: suite))
    XCTAssertFalse(ForecastEraNotice.shouldOfferExplainer(now: now, defaults: suite))
  }

  func testVisibleAtWindowStart() {
    let now = utc("2026-10-07T12:00:00Z")
    XCTAssertTrue(ForecastEraNotice.isInWindow(now: now))
    XCTAssertTrue(ForecastEraNotice.shouldShowBanner(now: now, defaults: suite))
    XCTAssertTrue(ForecastEraNotice.shouldOfferExplainer(now: now, defaults: suite))
  }

  func testVisibleAtCutover() {
    XCTAssertTrue(ForecastEraNotice.shouldShowBanner(now: ForecastEraNotice.cutoverUTC, defaults: suite))
  }

  func testHiddenAtWindowEnd() {
    let now = utc("2026-10-28T12:00:00Z")
    XCTAssertFalse(ForecastEraNotice.isInWindow(now: now))
    XCTAssertFalse(ForecastEraNotice.shouldShowBanner(now: now, defaults: suite))
    XCTAssertFalse(ForecastEraNotice.shouldOfferExplainer(now: now, defaults: suite))
  }

  func testStillVisibleJustBeforeWindowEnd() {
    let now = utc("2026-10-28T11:59:59Z")
    XCTAssertTrue(ForecastEraNotice.shouldShowBanner(now: now, defaults: suite))
  }

  func testDismissHidesBannerButKeepsExplainer() {
    let now = ForecastEraNotice.cutoverUTC
    ForecastEraNotice.dismiss(defaults: suite)
    XCTAssertFalse(ForecastEraNotice.shouldShowBanner(now: now, defaults: suite))
    XCTAssertTrue(ForecastEraNotice.shouldOfferExplainer(now: now, defaults: suite))
  }

  func testBumpedNoticeIdReappears() {
    let now = ForecastEraNotice.cutoverUTC
    suite.set("scn-26-48-old", forKey: ForecastEraNotice.dismissedIdKey)
    XCTAssertTrue(ForecastEraNotice.shouldShowBanner(now: now, defaults: suite))
    ForecastEraNotice.dismiss(defaults: suite)
    XCTAssertEqual(suite.string(forKey: ForecastEraNotice.dismissedIdKey), ForecastEraNotice.id)
    XCTAssertFalse(ForecastEraNotice.shouldShowBanner(now: now, defaults: suite))
  }

  func testResetDismissShowsAgain() {
    let now = ForecastEraNotice.cutoverUTC
    ForecastEraNotice.dismiss(defaults: suite)
    ForecastEraNotice.resetDismiss(defaults: suite)
    XCTAssertTrue(ForecastEraNotice.shouldShowBanner(now: now, defaults: suite))
  }

  func testNationwideNotMemphisGated() {
    XCTAssertEqual(ForecastEraNotice.id, "scn-26-48-2026-10-14")
    XCTAssertTrue(
      ForecastEraNotice.Copy.memphisSample.hasPrefix("NWS Memphis"),
      "MEG is a sample string only"
    )
    XCTAssertFalse(ForecastEraNotice.Copy.banner.localizedCaseInsensitiveContains("memphis"))
    XCTAssertFalse(ForecastEraNotice.Copy.banner.localizedCaseInsensitiveContains("mid-south"))
    XCTAssertFalse(ForecastEraNotice.Copy.opener.localizedCaseInsensitiveContains("memphis"))
  }

  func testCopyContracts() {
    let joined = ForecastEraNotice.Copy.visibleStrings.joined(separator: " ")
    XCTAssertEqual(ForecastEraNotice.Copy.banner, "Upstream NWS short-range models are changing")
    XCTAssertEqual(ForecastEraNotice.Copy.cardTitle, "What this means")
    XCTAssertTrue(ForecastEraNotice.Copy.opener.contains("RRFS"))
    XCTAssertTrue(ForecastEraNotice.Copy.opener.contains("REFS"))
    XCTAssertTrue(ForecastEraNotice.Copy.opener.contains("NAM"))
    XCTAssertTrue(ForecastEraNotice.Copy.timingRisk.contains("Critical Weather Day"))
    XCTAssertTrue(ForecastEraNotice.Copy.behavior.contains("not inventing a new forecast engine"))
    XCTAssertTrue(ForecastEraNotice.Copy.notOfficial.contains("Keep Government Alerts on"))
    XCTAssertTrue(joined.contains("SCN 26-48"))
    XCTAssertTrue(joined.contains("SCN 26-47"))

    XCTAssertFalse(joined.localizedCaseInsensitiveContains("chaos"))
    XCTAssertFalse(joined.localizedCaseInsensitiveContains("broken forecast"))
    XCTAssertFalse(joined.localizedCaseInsensitiveContains("trust nothing"))
    XCTAssertFalse(joined.localizedCaseInsensitiveContains("most accurate"))
    XCTAssertFalse(joined.localizedCaseInsensitiveContains("AI upgraded"))
    XCTAssertFalse(joined.localizedCaseInsensitiveContains("we're ready"))
    XCTAssertFalse(joined.localizedCaseInsensitiveContains("we’re ready"))
    XCTAssertFalse(joined.localizedCaseInsensitiveContains("Storm Window"))
    XCTAssertFalse(joined.localizedCaseInsensitiveContains("MinuteCast"))
    XCTAssertFalse(joined.localizedCaseInsensitiveContains("upgraded models"))
    XCTAssertFalse(ForecastEraNotice.Copy.banner.contains("WEA"))
    XCTAssertFalse(ForecastEraNotice.Copy.opener.contains("WEA"))
    XCTAssertFalse(joined.localizedCaseInsensitiveContains("DayCast is NWS"))
    XCTAssertFalse(joined.localizedCaseInsensitiveContains("DayCast is NOAA"))
  }

  func testVoiceOverIncludesNotWEAHonesty() {
    XCTAssertTrue(
      ForecastEraNotice.Copy.bannerAccessibility.localizedCaseInsensitiveContains(
        "DayCast is not an official wireless emergency alert"
      )
    )
    XCTAssertTrue(
      ForecastEraNotice.Copy.cardAccessibility.localizedCaseInsensitiveContains(
        "not a wireless emergency alert"
      )
    )
  }

  func testOfficialPDFCitationsAreWeatherGov() {
    XCTAssertEqual(
      AppLinks.nwsSCN2648.absoluteString,
      "https://www.weather.gov/media/notification/pdf_2026/scn26-048_Updated_RRFS_and_REFS_Implementation_aad.pdf"
    )
    XCTAssertTrue(AppLinks.nwsSCN2648.host?.contains("weather.gov") == true)
    XCTAssertTrue(AppLinks.nwsSCN2647.host?.contains("weather.gov") == true)
    XCTAssertTrue(AppLinks.nwsSCN2647.absoluteString.contains("SCN26-47"))
    XCTAssertTrue(AppLinks.nwsSCN2647.pathExtension.lowercased() == "pdf")
    XCTAssertTrue(AppLinks.nwsSCN2648.pathExtension.lowercased() == "pdf")
  }

  func testCalmPlacesNoticeAfterHonestyStripNotInSecondLine() {
    let rows = FeedAssembler.rows(
      items: [.now, .hourly, .yourNews],
      weatherError: nil,
      showsStandaloneHonestyStrip: true,
      showsForecastEraNotice: true
    )
    XCTAssertEqual(
      rows,
      [.item(.now), .honestyStrip, .forecastEraNotice, .item(.hourly), .item(.yourNews)]
    )
    XCTAssertNotEqual(TodayFeedRow.forecastEraNotice, .honestyStrip)
  }

  func testStoryDayPlacesNoticeAfterYourNews() throws {
    let rows = FeedAssembler.rows(
      items: [.now, .alerts, .hourly, .radar, .yourNews],
      weatherError: nil,
      showsStandaloneHonestyStrip: false,
      showsForecastEraNotice: true
    )
    XCTAssertEqual(rows.first, .item(.now))
    XCTAssertEqual(rows.dropFirst().first, .item(.alerts))
    XCTAssertFalse(rows.contains(.honestyStrip))
    let newsIndex = try XCTUnwrap(rows.firstIndex(of: .item(.yourNews)))
    XCTAssertEqual(rows[rows.index(after: newsIndex)], .forecastEraNotice)
    XCTAssertTrue(rows.firstIndex(of: .forecastEraNotice)! > newsIndex)
  }

  func testMissingYourNewsStillSurfacesNoticeAfterAlerts() {
    let rows = FeedAssembler.rows(
      items: [.now, .alerts, .hourly],
      weatherError: nil,
      showsStandaloneHonestyStrip: false,
      showsForecastEraNotice: true
    )
    XCTAssertEqual(
      rows,
      [.item(.now), .item(.alerts), .forecastEraNotice, .item(.hourly)]
    )
  }

  func testOmittedNoticeLeavesExistingHonestyPlacement() {
    let rows = FeedAssembler.rows(
      items: [.now, .hourly],
      weatherError: nil,
      showsStandaloneHonestyStrip: true,
      showsForecastEraNotice: false
    )
    XCTAssertEqual(rows, [.item(.now), .honestyStrip, .item(.hourly)])
    XCTAssertFalse(rows.contains(.forecastEraNotice))
  }

  func testSeasonalNoticeIsNotBakedIntoYearRoundViewport() {
    XCTAssertEqual(TodayGlanceLayout.forecastEraNoticeHeight, 20)
    XCTAssertEqual(TodayGlanceLayout.honestyStripCalmHeight, 20)
    let calmWithNotice =
      TodayGlanceLayout.oliveBranchCalmStackHeight
      + TodayGlanceLayout.feedSpacing
      + TodayGlanceLayout.forecastEraNoticeHeight
    XCTAssertLessThanOrEqual(calmWithNotice, TodayGlanceLayout.visibleFeedHeightIPhone16)
    XCTAssertGreaterThanOrEqual(
      TodayGlanceLayout.visibleFeedHeightIPhone16 - calmWithNotice,
      TodayGlanceLayout.yourNewsCardPeekHeight,
      "Calm + notice must still peek a Your News card"
    )
  }

  #if DEBUG
    func testDebugForceShowIgnoresDateWindow() {
      let before = utc("2026-09-14T12:00:00Z")
      XCTAssertFalse(ForecastEraNotice.isInWindow(now: before))
      suite.set(true, forKey: ForecastEraNotice.forceShowKey)
      XCTAssertTrue(ForecastEraNotice.shouldShowBanner(now: before, defaults: suite))
      XCTAssertTrue(ForecastEraNotice.shouldOfferExplainer(now: before, defaults: suite))
    }
  #endif

  private func utc(_ string: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.date(from: string)!
  }
}
