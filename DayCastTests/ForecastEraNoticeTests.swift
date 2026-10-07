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
    ForecastEraNotice.dataLoader = ForecastEraNotice.liveLoad
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
    XCTAssertEqual(ForecastEraNotice.fallbackId, "scn-26-48-2026-10-14")
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
    XCTAssertEqual(
      ForecastEraNotice.Copy.banner(for: ForecastEraNotice.fallback, locale: Locale(identifier: "en_US")),
      "Upstream NWS models change Oct 14, 2026, 7 AM CT")
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

  func testRemoteSlipShowsNewDateAndReshowsBanner() async {
    suite.set(ForecastEraNotice.fallbackId, forKey: ForecastEraNotice.dismissedIdKey)
    ForecastEraNotice.dataLoader = { Data(Self.slippedJSON.utf8) }

    let config = await ForecastEraNotice.refreshRemote(
      now: utc("2026-10-10T12:00:00Z"),
      defaults: suite,
      force: true
    )
    XCTAssertEqual(config.id, "scn-26-48-2026-10-15")
    XCTAssertEqual(config.status, .slipped)
    XCTAssertEqual(config.cutoverUTC, utc("2026-10-15T12:00:00Z"))
    XCTAssertEqual(ForecastEraNotice.effective(defaults: suite).id, "scn-26-48-2026-10-15")

    let now = utc("2026-10-15T12:00:00Z")
    XCTAssertTrue(ForecastEraNotice.shouldShowBanner(now: now, defaults: suite))
    let opener = ForecastEraNotice.Copy.opener(
      for: config,
      locale: Locale(identifier: "en_US")
    )
    XCTAssertTrue(opener.contains("Oct 15, 2026, 7 AM CT"))
    XCTAssertTrue(opener.hasPrefix("NWS moved the switch"))

    ForecastEraNotice.dismiss(defaults: suite)
    XCTAssertEqual(
      suite.string(forKey: ForecastEraNotice.dismissedIdKey),
      "scn-26-48-2026-10-15"
    )
    XCTAssertFalse(ForecastEraNotice.shouldShowBanner(now: now, defaults: suite))
  }

  func testBadJSONFallsBackToConstants() async {
    ForecastEraNotice.dataLoader = { Data("{".utf8) }
    let config = await ForecastEraNotice.refreshRemote(
      now: utc("2026-10-10T12:00:00Z"),
      defaults: suite,
      force: true
    )
    XCTAssertEqual(config, ForecastEraNotice.fallback)
    XCTAssertEqual(ForecastEraNotice.effective(defaults: suite).id, ForecastEraNotice.fallbackId)
    XCTAssertNil(suite.string(forKey: ForecastEraNotice.cachedJSONKey))
  }

  func testOutOfBoundsDatesFallBackToConstants() async {
    ForecastEraNotice.dataLoader = { Data(Self.outOfBoundsJSON.utf8) }
    let config = await ForecastEraNotice.refreshRemote(
      now: utc("2026-10-10T12:00:00Z"),
      defaults: suite,
      force: true
    )
    XCTAssertEqual(config, ForecastEraNotice.fallback)
    XCTAssertEqual(ForecastEraNotice.effective(defaults: suite).cutoverUTC, ForecastEraNotice.cutoverUTC)
  }

  func testOfflineUsesCache() async {
    ForecastEraNotice.dataLoader = { Data(Self.slippedJSON.utf8) }
    _ = await ForecastEraNotice.refreshRemote(
      now: utc("2026-10-10T12:00:00Z"),
      defaults: suite,
      force: true
    )
    ForecastEraNotice.dataLoader = { nil }
    let config = await ForecastEraNotice.refreshRemote(
      now: utc("2026-10-10T12:20:00Z"),
      defaults: suite,
      force: true
    )
    XCTAssertEqual(config.id, "scn-26-48-2026-10-15")
    XCTAssertEqual(config.cutoverUTC, utc("2026-10-15T12:00:00Z"))
    XCTAssertEqual(ForecastEraNotice.effective(defaults: suite).status, .slipped)
  }

  func testScheduledOpenerKeepsCurrentSentence() {
    let opener = ForecastEraNotice.Copy.opener(
      for: ForecastEraNotice.fallback,
      locale: Locale(identifier: "en_US")
    )
    XCTAssertEqual(
      opener,
      "On or around Oct 14, 2026, 7 AM CT, NCEP is replacing older short-range systems (NAM, HREF, SREF, HiresW) with RRFS and REFS."
    )
  }

  func testCutoverFormatsInCentralTimeFromRemoteDate() {
    let en = Locale(identifier: "en_US")
    XCTAssertEqual(
      ForecastEraNotice.formattedCutoverDateTime(ForecastEraNotice.cutoverUTC, locale: en),
      "Oct 14, 2026, 7 AM CT")
    XCTAssertEqual(
      ForecastEraNotice.formattedCutoverDateTime(utc("2026-10-15T12:00:00Z"), locale: en),
      "Oct 15, 2026, 7 AM CT", "a slip must move the date")
    XCTAssertEqual(
      ForecastEraNotice.formattedCutoverDateTime(utc("2026-10-14T12:30:00Z"), locale: en),
      "Oct 14, 2026, 7:30 AM CT")
    // After the DST change the same UTC hour is 6 AM local; the label stays "CT".
    XCTAssertEqual(
      ForecastEraNotice.formattedCutoverDateTime(utc("2026-11-10T12:00:00Z"), locale: en),
      "Nov 10, 2026, 6 AM CT")
    XCTAssertEqual(
      ForecastEraNotice.formattedCutoverShort(ForecastEraNotice.cutoverUTC, locale: en), "Oct 14")
  }

  func testSettingsRowTitleAndBannerFollowTheConfig() {
    let en = Locale(identifier: "en_US")
    XCTAssertEqual(
      ForecastEraNotice.Copy.settingsRowTitle(for: ForecastEraNotice.fallback, locale: en),
      "NWS model change (Oct 14)")
    var slipped = ForecastEraNotice.fallback
    slipped.cutoverUTC = utc("2026-10-15T12:00:00Z")
    slipped.status = .slipped
    XCTAssertEqual(
      ForecastEraNotice.Copy.settingsRowTitle(for: slipped, locale: en),
      "NWS model change (Oct 15)")
    XCTAssertEqual(
      ForecastEraNotice.Copy.banner(for: ForecastEraNotice.fallback, locale: en),
      "Upstream NWS models change Oct 14, 2026, 7 AM CT")
    XCTAssertEqual(
      ForecastEraNotice.Copy.banner(for: slipped, locale: en),
      "Upstream NWS model change moved to Oct 15, 2026, 7 AM CT")
    XCTAssertTrue(
      ForecastEraNotice.Copy.bannerAccessibility.contains(ForecastEraNotice.Copy.banner))
  }

  func testDoneOpenerUsesPastTense() {
    var config = ForecastEraNotice.fallback
    config.status = .done
    let opener = ForecastEraNotice.Copy.opener(for: config, locale: Locale(identifier: "en_US"))
    XCTAssertTrue(opener.hasPrefix("On Oct 14, 2026, 7 AM CT, NCEP replaced"))
  }

  func testRetiringStayingLineShowsForEveryStatus() async {
    let expected =
      "Retiring that day: NAM, HREF, SREF, and HiresW (except Guam). Staying: RAP, HRRR, and HiresW Guam."
    XCTAssertEqual(ForecastEraNotice.Copy.retiringStaying, expected)

    for status in ["scheduled", "slipped", "done"] {
      let json = Self.slippedJSON.replacingOccurrences(of: "\"slipped\"", with: "\"\(status)\"")
      ForecastEraNotice.dataLoader = { Data(json.utf8) }
      let config = await ForecastEraNotice.refreshRemote(
        now: utc("2026-10-10T12:00:00Z"),
        defaults: suite,
        force: true
      )
      XCTAssertEqual(config.status.rawValue, status)
      XCTAssertEqual(ForecastEraNotice.Copy.paragraphs[1], expected, status)
      XCTAssertTrue(ForecastEraNotice.Copy.paragraphs.contains(expected), status)
    }

    let joined = ForecastEraNotice.Copy.visibleStrings.joined(separator: " ").lowercased()
    XCTAssertFalse(joined.contains("hrrr is"))
    XCTAssertFalse(joined.contains("all hiresw"))
    XCTAssertFalse(joined.contains("october 6"))
  }

  func testRefreshThrottlesWithinFifteenMinutes() async {
    let loads = LoadCounter()
    ForecastEraNotice.dataLoader = {
      loads.value += 1
      return Data(Self.slippedJSON.utf8)
    }
    _ = await ForecastEraNotice.refreshRemote(
      now: utc("2026-10-10T12:00:00Z"),
      defaults: suite
    )
    _ = await ForecastEraNotice.refreshRemote(
      now: utc("2026-10-10T12:14:00Z"),
      defaults: suite
    )
    XCTAssertEqual(loads.value, 1)
    _ = await ForecastEraNotice.refreshRemote(
      now: utc("2026-10-10T12:15:00Z"),
      defaults: suite
    )
    XCTAssertEqual(loads.value, 2)
  }

  #if DEBUG
    func testDebugForceShowIgnoresDateWindow() {
      let before = utc("2026-09-14T12:00:00Z")
      XCTAssertFalse(ForecastEraNotice.isInWindow(now: before))
      suite.set(true, forKey: ForecastEraNotice.forceShowKey)
      XCTAssertTrue(ForecastEraNotice.shouldShowBanner(now: before, defaults: suite))
      XCTAssertTrue(ForecastEraNotice.shouldOfferExplainer(now: before, defaults: suite))
    }

    func testDebugForceShowOverridesDismiss() {
      ForecastEraNotice.dismiss(defaults: suite)
      suite.set(true, forKey: ForecastEraNotice.forceShowKey)
      XCTAssertTrue(
        ForecastEraNotice.shouldShowBanner(now: ForecastEraNotice.cutoverUTC, defaults: suite)
      )
    }
  #endif

  private final class LoadCounter: @unchecked Sendable {
    var value = 0
  }

  private static let slippedJSON = """
    {
      "id": "scn-26-48-2026-10-15",
      "cutoverUTC": "2026-10-15T12:00:00Z",
      "windowStartUTC": "2026-10-07T12:00:00Z",
      "windowEndUTC": "2026-10-28T12:00:00Z",
      "status": "slipped",
      "updatedAt": "2026-10-13T18:00:00Z"
    }
    """

  private static let outOfBoundsJSON = """
    {
      "id": "scn-26-48-2025-10-14",
      "cutoverUTC": "2025-10-14T12:00:00Z",
      "windowStartUTC": "2025-10-07T12:00:00Z",
      "windowEndUTC": "2025-10-28T12:00:00Z",
      "status": "scheduled",
      "updatedAt": "2026-10-03T00:00:00Z"
    }
    """

  private func utc(_ string: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.date(from: string)!
  }
}
