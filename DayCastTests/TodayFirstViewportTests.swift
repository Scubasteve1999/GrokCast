import XCTest

@testable import DayCast

final class TodayFirstViewportTests: XCTestCase {

  func testOliveBranchStoryDayFitsYourNewsCardOnIPhone16() {
    XCTAssertLessThanOrEqual(
      TodayGlanceLayout.oliveBranchStoryStackHeight,
      TodayGlanceLayout.visibleFeedHeightIPhone16
    )
    XCTAssertEqual(TodayGlanceLayout.sheetSectionSpacing, DesignTokens.Spacing.space12)
    XCTAssertEqual(TodayGlanceLayout.sheetTopPadding, DesignTokens.Spacing.space12)
    XCTAssertEqual(TodayGlanceLayout.heroBottomPadding, DesignTokens.Spacing.space8)
    XCTAssertGreaterThanOrEqual(
      TodayGlanceLayout.oliveBranchYourNewsPeek,
      TodayGlanceLayout.yourNewsCardPeekHeight,
      "Your News card body must sit in the first viewport, not header-only"
    )
  }

  func testCalmHonestyStripDoesNotBlowYourNewsPeek() {
    XCTAssertEqual(TodayGlanceLayout.honestyStripCalmHeight, 20)
    XCTAssertLessThan(TodayGlanceLayout.honestyStripCalmHeight, TodayGlanceLayout.alertChipMinHeight)
    XCTAssertLessThanOrEqual(
      TodayGlanceLayout.oliveBranchCalmStackHeight,
      TodayGlanceLayout.visibleFeedHeightIPhone16
    )
    XCTAssertGreaterThanOrEqual(
      TodayGlanceLayout.oliveBranchCalmYourNewsPeek,
      TodayGlanceLayout.yourNewsCardPeekHeight,
      "Calm WFO strip must leave a Your News card in the first viewport"
    )
    XCTAssertGreaterThan(
      TodayGlanceLayout.oliveBranchCalmYourNewsPeek,
      TodayGlanceLayout.oliveBranchYourNewsPeek
    )
  }

  func testCalmEnsembleLineDoesNotBlowYourNewsPeek() {
    XCTAssertEqual(TodayGlanceLayout.honestyStripEnsembleLineHeight, 16)
    XCTAssertEqual(TodayGlanceLayout.honestyStripEnsembleHeight, 36)
    XCTAssertLessThan(
      TodayGlanceLayout.honestyStripEnsembleHeight,
      TodayGlanceLayout.alertChipMinHeight
    )
    XCTAssertLessThanOrEqual(
      TodayGlanceLayout.oliveBranchCalmEnsembleStackHeight,
      TodayGlanceLayout.visibleFeedHeightIPhone16
    )
    XCTAssertGreaterThanOrEqual(
      TodayGlanceLayout.oliveBranchCalmEnsembleYourNewsPeek,
      TodayGlanceLayout.yourNewsCardPeekHeight,
      "Ensemble second line must leave a Your News card in the first viewport"
    )
    XCTAssertGreaterThan(
      TodayGlanceLayout.oliveBranchCalmEnsembleYourNewsPeek,
      TodayGlanceLayout.oliveBranchYourNewsPeek
    )
  }

  func testOutlookRadarPlateIsTallerThanThePostageStamp() {
    XCTAssertEqual(RadarPreviewSource.teaserHeight, 72)
    XCTAssertEqual(RadarPreviewSource.outlookPlateHeight, 168)
    XCTAssertGreaterThanOrEqual(RadarPreviewSource.outlookPlateHeight, 160)
    XCTAssertLessThanOrEqual(RadarPreviewSource.outlookPlateHeight, 180)
    XCTAssertEqual(TodayGlanceLayout.radarMapHeight, RadarPreviewSource.outlookPlateHeight)
    XCTAssertEqual(RadarPreviewPaint.reservedPlateHeight, RadarPreviewSource.outlookPlateHeight)
    XCTAssertEqual(RadarPreviewSource.previewBaseMap, .dark)
  }

  func testOutlookPreviewNeverResolvesToZeroHeight() {
    let missingSweep = RadarPreviewPaint.display(
      paint: .siteDoppler,
      hasCoordinate: true,
      hasSweep: false,
      mapsGLReady: true
    )
    XCTAssertEqual(missingSweep, .nationalMapsGL)

    let missingKeys = RadarPreviewPaint.display(
      paint: .siteDoppler,
      hasCoordinate: true,
      hasSweep: false,
      mapsGLReady: false
    )
    XCTAssertEqual(missingKeys, .unavailable)

    let missingCoord = RadarPreviewPaint.display(
      paint: .nationalMapsGL,
      hasCoordinate: false,
      hasSweep: false,
      mapsGLReady: true
    )
    XCTAssertEqual(missingCoord, .unavailable)

    let explicitHole = RadarPreviewPaint.display(
      paint: .unavailable,
      hasCoordinate: false,
      hasSweep: false,
      mapsGLReady: false
    )
    XCTAssertEqual(explicitHole, .unavailable)
    XCTAssertEqual(RadarPreviewPaint.reservedPlateHeight, 168)
    XCTAssertEqual(RadarPreviewPaint.reservedPlateHeight, RadarPreviewSource.outlookPlateHeight)
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
    XCTAssertEqual(TodayGlanceLayout.nowBudgetHeight, 160)
    XCTAssertEqual(TodayGlanceLayout.nowHeroMaxHeight, TodayGlanceLayout.nowBudgetHeight)
    XCTAssertEqual(
      NowHeroPhotography.stillName(conditionCode: 0, isDay: true),
      "NewsHeroSky"
    )
  }

  func testWetNowCannotGrowPastTheHeroBudget() {
    XCTAssertEqual(TodayGlanceLayout.nowBudgetHeight, 160)
    XCTAssertEqual(TodayGlanceLayout.nowHeroMaxHeight, 160)
    XCTAssertLessThanOrEqual(
      TodayGlanceLayout.oliveBranchStoryStackHeight,
      TodayGlanceLayout.visibleFeedHeightIPhone16
    )
    XCTAssertGreaterThanOrEqual(
      TodayGlanceLayout.oliveBranchYourNewsPeek,
      TodayGlanceLayout.yourNewsCardPeekHeight
    )
  }

  func testFirstViewportOrderIsNowAlertsHourlyRadar() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 1,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: true,
      showFireCard: false,
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
      TodayGlanceLayout.hourlyGraphHeight
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

  func testYourNewsPeekIsTextFirstAndHoldsWhileBriefingPending() {
    XCTAssertTrue(YourNewsPeekLayout.headlineBeforePhoto)
    XCTAssertEqual(YourNewsCopy.title, "Your News")
    XCTAssertEqual(YourNewsCopy.loading, "Loading local briefing…")
    XCTAssertGreaterThanOrEqual(
      TodayGlanceLayout.yourNewsCardPeekHeight, 80)

    XCTAssertTrue(
      LocalBriefingSlot.isPending(
        currentLocationID: "olive",
        storeLocationID: nil,
        itemCount: 0,
        isRefreshing: false
      )
    )
    XCTAssertTrue(
      LocalBriefingSlot.isPending(
        currentLocationID: "olive",
        storeLocationID: "tampa",
        itemCount: 2,
        isRefreshing: true
      )
    )
    XCTAssertFalse(
      LocalBriefingSlot.isPending(
        currentLocationID: "olive",
        storeLocationID: "olive",
        itemCount: 0,
        isRefreshing: false
      )
    )

    let pending = FeedSnapshot(
      hasWeather: true,
      alertCount: 1,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: true,
      showFireCard: false,
      hasLocalBriefing: false,
      isLocalBriefingPending: true
    )
    let items = FeedAssembler.items(from: pending)
    XCTAssertTrue(items.contains(.yourNews))
    XCTAssertLessThan(items.firstIndex(of: .radar)!, items.firstIndex(of: .yourNews)!)
    XCTAssertLessThan(items.firstIndex(of: .yourNews)!, items.firstIndex(of: .daily)!)
  }

  func testStoryDayKeepsAlertsHourlyAndYourNews() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 1,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: false,
      showFireCard: false,
      hasLocalBriefing: true,
      hasRadarRelevantAlert: true
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
