import XCTest

@testable import DayCast

final class TodayFirstViewportTests: XCTestCase {

  func testOliveBranchStoryDayFitsYourNewsPeekOnIPhone16() {
    XCTAssertLessThanOrEqual(
      TodayGlanceLayout.oliveBranchStoryStackHeight,
      TodayGlanceLayout.visibleFeedHeightIPhone16
    )
    XCTAssertGreaterThanOrEqual(
      TodayGlanceLayout.visibleFeedHeightIPhone16
        - TodayGlanceLayout.oliveBranchStoryStackHeight,
      8
    )
  }

  func testRadarTeaserIsShorterThanTheOld160Map() {
    XCTAssertEqual(RadarPreviewSource.teaserHeight, 72)
    XCTAssertLessThan(RadarPreviewSource.teaserHeight, 160)
    XCTAssertEqual(TodayGlanceLayout.radarMapHeight, RadarPreviewSource.teaserHeight)
  }

  func testNowGlanceTempIsTighterThanDisplayHero() {
    XCTAssertEqual(TodayGlanceLayout.nowTempSize, 72)
    XCTAssertLessThan(TodayGlanceLayout.nowTempSize, 96)
    XCTAssertGreaterThan(TodayGlanceLayout.nowTempSize, 44)
  }

  func testAlertChipIsASingleRow() {
    XCTAssertEqual(TodayGlanceLayout.alertChipMinHeight, 44)
    XCTAssertLessThan(TodayGlanceLayout.alertChipMinHeight, 80)
  }

  func testHourlyGraphFitsInTheOldChipBudget() {
    let oldChipCardHeight: CGFloat = 8 * 2 + 20 + 8 + 100 + 24
    XCTAssertEqual(TodayGlanceLayout.hourlyGraphHeight, HourlyGraphLayout.height)
    XCTAssertLessThan(TodayGlanceLayout.hourlyCardHeight, oldChipCardHeight)
    XCTAssertGreaterThan(TodayGlanceLayout.hourlyTonightLineHeight, 28)
    XCTAssertLessThanOrEqual(TodayGlanceLayout.hourlyCardHeight, 168)
  }

  func testDuplicateAQIAlertsCollapseToOneChip() {
    let first = aqiAlert(id: "aqi-1")
    let second = aqiAlert(id: "aqi-2")
    let chips = AlertsFeedCard.glanceChips(from: [first, second])
    XCTAssertEqual(chips.count, 1)
    XCTAssertEqual(chips.first?.id, "aqi-1")
    XCTAssertEqual(
      AlertsFeedCard.chipTitle(for: first, in: [first, second]),
      "Air Quality Alert · 2"
    )
  }

  func testStoryDayKeepsHoistAlertsHourlyAndYourNews() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 1,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: false,
      hasAQI: true,
      hasSunriseOrSunset: false,
      showFireCard: false,
      showAIInsight: false,
      hasLocalBriefing: true
    )
    let items = FeedAssembler.items(from: snapshot)
    XCTAssertEqual(
      Array(items.prefix(5)),
      [.now, .alerts, .radar, .hourly, .yourNews]
    )
    XCTAssertTrue(FeedAssembler.isRadarStory(snapshot))
    XCTAssertTrue(items.contains(.alerts))
    XCTAssertEqual(
      items.firstIndex(of: .hourly)! + 1,
      items.firstIndex(of: .yourNews)
    )
  }

  func testHoistedSiteCopyStillNamesScanAndSite() {
    let age = RadarFeedCopy.scanAgeLine(scanDate: Date(), now: Date())
    XCTAssertTrue(age.hasPrefix("SCAN"))
    XCTAssertEqual(
      RadarFeedCopy.siteTitle(conditionCode: 0, siteID: "NQA", ageLine: "SCAN <1m"),
      "NQA is clear · SCAN <1m"
    )
    XCTAssertEqual(RadarFeedCopy.siteProductName, "Site Doppler")
  }

  func testMEGHeadlinesStayPunchyAndGrounded() {
    XCTAssertEqual(
      megItem(
        "Isolated shower and thunderstorm chances will increase Tuesday morning for areas along and west of the Mississippi River."
      ).displayTitle,
      "Why Tuesday morning still has an isolated storm window."
    )
    XCTAssertEqual(
      megItem(
        "Additional chances for showers and thunderstorms are expected each day through Thursday."
      ).displayTitle,
      "The Thursday storm round MEG says isn\u{2019}t done yet."
    )
    XCTAssertEqual(
      megItem(
        "Near to slightly above normal temperatures are expected across the Mid-South for most of the week, but extreme heat is not expected."
      ).displayTitle,
      "The Mid-South stays warm. Extreme heat? MEG says no."
    )
  }

  private func aqiAlert(id: String) -> NWSAlert {
    NWSAlert(
      id: id,
      event: "Air Quality Alert",
      severity: "Moderate",
      headline: "Air Quality Alert issued August 24 at 4:18PM CDT by NWS Memphis TN",
      description: nil,
      instruction: nil,
      expires: nil,
      areaDesc: nil,
      latitude: nil,
      longitude: nil
    )
  }

  private func megItem(_ title: String) -> LocalBriefingItem {
    LocalBriefingItem(
      id: "test-afd",
      title: title,
      sourceName: "NWS Memphis",
      issuedAt: Date(timeIntervalSince1970: 1_787_515_000),
      url: LocalBriefingParser.productPageURL(cwa: "MEG", productCode: "AFD"),
      productCode: "AFD",
      officeID: "MEG",
      imageURL: nil
    )
  }
}
