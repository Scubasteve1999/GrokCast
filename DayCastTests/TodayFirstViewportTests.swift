import XCTest

@testable import DayCast

final class TodayFirstViewportTests: XCTestCase {

  func testOliveBranchStoryDayFitsYourNewsPeekOnIPhone16() {
    XCTAssertLessThanOrEqual(
      TodayGlanceLayout.oliveBranchStoryStackHeight,
      TodayGlanceLayout.visibleFeedHeightIPhone16
    )
    let peek =
      TodayGlanceLayout.visibleFeedHeightIPhone16
      - TodayGlanceLayout.oliveBranchStoryStackHeight
    XCTAssertGreaterThanOrEqual(peek, 8, "Your News header must still peek")
  }

  func testOutlookRadarPlateIsTallerThanThePostageStamp() {
    XCTAssertEqual(RadarPreviewSource.teaserHeight, 72)
    XCTAssertEqual(RadarPreviewSource.outlookPlateHeight, 168)
    XCTAssertGreaterThanOrEqual(RadarPreviewSource.outlookPlateHeight, 160)
    XCTAssertLessThanOrEqual(RadarPreviewSource.outlookPlateHeight, 180)
    XCTAssertEqual(TodayGlanceLayout.radarMapHeight, RadarPreviewSource.outlookPlateHeight)
    XCTAssertEqual(RadarPreviewSource.previewBaseMap, .dark)
  }

  func testOutlookPlateCopyIsNotIntensityOrScanHeadline() {
    XCTAssertEqual(OutlookRadarCopy.title, "Outlook")
    XCTAssertEqual(OutlookRadarCopy.radarPill, "Radar")
    XCTAssertEqual(OutlookRadarCopy.futurePill, "Future")
    XCTAssertEqual(OutlookRadarCopy.livePill, "LIVE")
    XCTAssertFalse(OutlookRadarCopy.futurePill.localizedCaseInsensitiveContains("Intensity"))
    XCTAssertFalse(OutlookRadarCopy.radarPill.localizedCaseInsensitiveContains("Intensity"))
    XCTAssertEqual(
      OutlookRadarProduct.resolved(requested: .future, futureFramesAvailable: false),
      .radar
    )
    XCTAssertEqual(
      OutlookRadarProduct.resolved(requested: .future, futureFramesAvailable: true),
      .future
    )
    XCTAssertEqual(
      OutlookRadarProduct.resolved(requested: .radar, futureFramesAvailable: true),
      .radar
    )
    XCTAssertEqual(
      OutlookRadarProduct.resolved(
        requested: .future, futureFramesAvailable: true, canUseFuture: false),
      .radar
    )
    XCTAssertEqual(
      OutlookRadarProduct.resolved(
        requested: .future, futureFramesAvailable: true, canUseFuture: true),
      .future
    )
    XCTAssertEqual(TonightOutlook.plateCharacterCount, 44)
    XCTAssertLessThan(TonightOutlook.plateCharacterCount, TonightOutlook.maxCharacterCount)
    let spoken = OutlookRadarCopy.accessibilityLabel(
      sentence: "Thunderstorms possible after 2 AM.",
      product: .radar
    )
    XCTAssertTrue(spoken.contains("Outlook"))
    XCTAssertTrue(spoken.contains("Thunderstorms possible after 2 AM."))
    XCTAssertFalse(spoken.localizedCaseInsensitiveContains("Rain now · TLH"))
    XCTAssertFalse(spoken.localizedCaseInsensitiveContains("Intensity"))
  }

  func testNowGlanceTempIsTighterThanDisplayHero() {
    XCTAssertEqual(TodayGlanceLayout.nowTempSize, 88)
    XCTAssertLessThan(TodayGlanceLayout.nowTempSize, 96)
    XCTAssertGreaterThan(TodayGlanceLayout.nowTempSize, 44)
  }

  func testNowHeroBudgetIsCinematicPhotographyNotAGlyphChip() {
    XCTAssertGreaterThanOrEqual(TodayGlanceLayout.nowBudgetHeight, 112)
    XCTAssertLessThan(TodayGlanceLayout.nowBudgetHeight, 240)
    XCTAssertEqual(TodayGlanceLayout.nowBudgetHeight, 200)
    XCTAssertFalse(NowHeroPhotography.glyphIsSectionFace)
    XCTAssertEqual(
      NowHeroPhotography.treatment(conditionCode: 0, isDay: true),
      .photography(assetName: "NewsHeroSky")
    )
  }

  func testFirstViewportOrderIsNowAlertsHourlyRadar() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 1,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: true,
      hasAQI: true,
      hasSunriseOrSunset: false,
      showFireCard: false,
      showAIInsight: false,
      hasLocalBriefing: true
    )
    let items = FeedAssembler.items(from: snapshot)
    XCTAssertEqual(
      Array(items.prefix(4)),
      [.now, .alerts, .hourly, .radar]
    )
    XCTAssertLessThan(items.firstIndex(of: .radar)!, items.firstIndex(of: .yourNews)!)
    XCTAssertLessThan(items.firstIndex(of: .yourNews)!, items.firstIndex(of: .daily)!)
  }

  func testAlertChipIsASingleRow() {
    XCTAssertEqual(TodayGlanceLayout.alertChipMinHeight, 56)
    XCTAssertLessThan(TodayGlanceLayout.alertChipMinHeight, 80)
  }

  func testHourlyGraphFitsInTheOldChipBudget() {
    XCTAssertEqual(TodayGlanceLayout.hourlyGraphHeight, HourlyGraphLayout.height)
    XCTAssertEqual(
      TodayGlanceLayout.hourlyCardHeight,
      TodayGlanceLayout.hourlyCardPadding * 2
        + TodayGlanceLayout.hourlyGraphHeight
        + TodayGlanceLayout.hourlyInnerSpacing
    )
    XCTAssertLessThan(TodayGlanceLayout.hourlyCardHeight, 280)
  }

  func testDuplicateAQIAlertsCollapseToOneChip() {
    let first = aqiAlert(id: "aqi-1")
    let second = aqiAlert(id: "aqi-2")
    let chips = AlertsFeedCard.glanceChips(from: [first, second])
    XCTAssertEqual(chips.count, 1)
    XCTAssertEqual(chips.first?.id, "aqi-1")
    XCTAssertEqual(
      AlertsFeedCard.chipTitle(for: first),
      "Air Quality Alert"
    )
  }

  func testGlanceKeepsOneOfficialChipAndPrefersWarning() {
    XCTAssertEqual(AlertsFeedCard.maxGlanceChips, 1)
    let advisory = NWSAlert(
      id: "adv",
      event: "Flood Advisory",
      severity: "Minor",
      headline: "Flood Advisory issued August 25 at 11:27PM EDT",
      description: nil,
      instruction: nil,
      expires: Date().addingTimeInterval(3_600),
      areaDesc: "Decatur, GA",
      latitude: nil,
      longitude: nil
    )
    let warning = NWSAlert(
      id: "ffw",
      event: "Flash Flood Warning",
      severity: "Severe",
      headline: "Flash Flood Warning issued August 25 at 11:47PM EDT",
      description: nil,
      instruction: nil,
      expires: Date().addingTimeInterval(7_200),
      areaDesc: "Decatur, GA",
      latitude: nil,
      longitude: nil
    )
    let chips = AlertsFeedCard.glanceChips(from: [advisory, warning])
    XCTAssertEqual(chips.count, 1)
    XCTAssertEqual(chips.first?.id, "ffw")
    XCTAssertEqual(AlertsFeedCard.chipTitle(for: warning), "Flash Flood Warning")
  }

  func testStoryDayKeepsAlertsHourlyAndYourNews() {
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
      [.now, .alerts, .hourly, .radar, .yourNews]
    )
    XCTAssertTrue(FeedAssembler.isRadarStory(snapshot))
    XCTAssertTrue(snapshot.showAlertsSlot)
    XCTAssertTrue(items.contains(.alerts))
    XCTAssertLessThan(items.firstIndex(of: .radar)!, items.firstIndex(of: .yourNews)!)
    XCTAssertLessThan(items.firstIndex(of: .yourNews)!, items.firstIndex(of: .daily)!)
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
