import XCTest

@testable import DayCast

final class HonestyStripCopyTests: XCTestCase {
  private var chicago: TimeZone { TimeZone(identifier: "America/Chicago")! }
  private let now = date(year: 2026, month: 9, day: 9, hour: 15, minute: 0)

  func testMemphisHomeDefaultReadsLikeNWSMemphis() {
    XCTAssertEqual(
      HonestyStripCopy.wfoLabel(officeName: "Memphis, TN", cwa: "MEG"),
      "nws memphis"
    )
    XCTAssertEqual(
      HonestyStripCopy.wfoLabel(officeName: "NWS Memphis, TN", cwa: "MEG"),
      "nws memphis"
    )
  }

  func testAnyWFOUsesTheSameShape() {
    XCTAssertEqual(
      HonestyStripCopy.wfoLabel(officeName: "Tampa Bay Area, FL", cwa: "TBW"),
      "nws tampa bay area"
    )
    XCTAssertEqual(
      HonestyStripCopy.wfoLabel(officeName: "New York, NY", cwa: "OKX"),
      "nws new york"
    )
    XCTAssertEqual(
      HonestyStripCopy.wfoLabel(officeName: "Miami, FL", cwa: "MFL"),
      "nws miami"
    )
  }

  func testMissingOfficeNameFallsBackToCWA() {
    XCTAssertEqual(HonestyStripCopy.wfoLabel(officeName: nil, cwa: "MEG"), "nws meg")
    XCTAssertEqual(HonestyStripCopy.wfoLabel(officeName: "  ", cwa: "OKX"), "nws okx")
  }

  func testNoOfficeMeansNoStrip() {
    XCTAssertNil(HonestyStripCopy.wfoLabel(officeName: nil, cwa: nil))
    XCTAssertNil(HonestyStripCopy.wfoLabel(officeName: nil, cwa: ""))
    XCTAssertNil(HonestyStripCopy.wfoLabel(officeName: "  ", cwa: "  "))
  }

  func testCalmContentIsWFOOnly() {
    let content = HonestyStripCopy.content(
      officeName: "Memphis, TN",
      cwa: "MEG",
      alerts: [advisory()],
      briefingItems: [afdItem()],
      now: now,
      timeZone: chicago
    )
    XCTAssertEqual(content?.wfoLabel, "nws memphis")
    XCTAssertNil(content?.headline)
    XCTAssertNil(content?.snippet)
    XCTAssertEqual(content?.primaryLine, "nws memphis")
    XCTAssertFalse(content?.isExpanded == true)
  }

  func testWatchExpandsWithUntilTime() {
    let expires = date(year: 2026, month: 9, day: 9, hour: 21, minute: 0)
    let content = HonestyStripCopy.content(
      officeName: "Memphis, TN",
      cwa: "MEG",
      alerts: [watch(expires: expires)],
      briefingItems: [],
      now: now,
      timeZone: chicago
    )
    XCTAssertEqual(
      content?.primaryLine,
      "nws memphis · severe thunderstorm watch until 9pm"
    )
    XCTAssertTrue(content?.isExpanded == true)
    XCTAssertNil(content?.snippet)
  }

  func testWarningPreferredOverAdvisoryAndUsesMinutesWhenNeeded() {
    let expires = date(year: 2026, month: 9, day: 9, hour: 21, minute: 30)
    let content = HonestyStripCopy.content(
      officeName: "Tampa Bay Area, FL",
      cwa: "TBW",
      alerts: [advisory(), warning(expires: expires)],
      briefingItems: [],
      now: now,
      timeZone: chicago
    )
    XCTAssertEqual(
      content?.primaryLine,
      "nws tampa bay area · tornado warning until 9:30pm"
    )
  }

  func testNextDayUntilNamesWeekday() {
    let expires = date(year: 2026, month: 9, day: 10, hour: 2, minute: 0)
    XCTAssertEqual(
      HonestyStripCopy.untilPhrase(expires: expires, now: now, timeZone: chicago),
      "until thu 2am"
    )
  }

  func testAFDSnippetOnlyWhenSevere() {
    let expires = date(year: 2026, month: 9, day: 9, hour: 21, minute: 0)
    let items = [afdItem(), newsItem()]
    let severe = HonestyStripCopy.content(
      officeName: "Memphis, TN",
      cwa: "MEG",
      alerts: [watch(expires: expires)],
      briefingItems: items,
      now: now,
      timeZone: chicago
    )
    XCTAssertEqual(
      severe?.snippet,
      "Scattered storms after 4pm. Hail possible in the strongest cells."
    )

    let calm = HonestyStripCopy.content(
      officeName: "Memphis, TN",
      cwa: "MEG",
      alerts: [],
      briefingItems: items,
      now: now,
      timeZone: chicago
    )
    XCTAssertNil(calm?.snippet)
  }

  func testAFDSnippetSkipsWhenUnavailable() {
    let expires = date(year: 2026, month: 9, day: 9, hour: 21, minute: 0)
    let content = HonestyStripCopy.content(
      officeName: "Memphis, TN",
      cwa: "MEG",
      alerts: [watch(expires: expires)],
      briefingItems: [newsItem()],
      now: now,
      timeZone: chicago
    )
    XCTAssertNil(content?.snippet)
    XCTAssertNil(HonestyStripCopy.afdSnippet(from: []))
  }

  func testStandaloneStripOnlyWhenCalm() {
    XCTAssertTrue(HonestyStripCopy.showsStandaloneStrip(hasWFO: true, showAlertsSlot: false))
    XCTAssertFalse(HonestyStripCopy.showsStandaloneStrip(hasWFO: true, showAlertsSlot: true))
    XCTAssertFalse(HonestyStripCopy.showsStandaloneStrip(hasWFO: false, showAlertsSlot: false))
  }

  func testCopyNeverClaimsAccuracyPrecisionOrWEA() {
    let expires = date(year: 2026, month: 9, day: 9, hour: 21, minute: 0)
    let content = HonestyStripCopy.content(
      officeName: "Memphis, TN",
      cwa: "MEG",
      alerts: [watch(expires: expires)],
      briefingItems: [afdItem()],
      now: now,
      timeZone: chicago
    )
    let visible = [content?.primaryLine, content?.snippet].compactMap { $0 }.joined(separator: " ")
    XCTAssertFalse(visible.localizedCaseInsensitiveContains("most accurate"))
    XCTAssertFalse(visible.localizedCaseInsensitiveContains("minutecast"))
    XCTAssertFalse(visible.localizedCaseInsensitiveContains("minute cast"))
    XCTAssertFalse(visible.localizedCaseInsensitiveContains("WEA"))
    XCTAssertFalse(visible.localizedCaseInsensitiveContains("wireless emergency"))
    XCTAssertTrue(
      content?.accessibilityLabel.localizedCaseInsensitiveContains(
        "DayCast is not an official wireless emergency alert"
      ) == true
    )
  }

  func testWatchWarningUsesGlancePriority() {
    let expires = date(year: 2026, month: 9, day: 9, hour: 21, minute: 0)
    let picked = HonestyStripCopy.watchWarning(from: [advisory(), watch(expires: expires)])
    XCTAssertEqual(picked?.event, "Severe Thunderstorm Watch")
    XCTAssertNil(HonestyStripCopy.watchWarning(from: [advisory()]))
  }

  func testAlertChipFoldsHonestyOnWatch() {
    let expires = date(year: 2026, month: 9, day: 9, hour: 21, minute: 0)
    let honesty = HonestyStripCopy.content(
      officeName: "Memphis, TN",
      cwa: "MEG",
      alerts: [watch(expires: expires)],
      briefingItems: [afdItem()],
      now: now,
      timeZone: chicago
    )
    XCTAssertEqual(
      AlertsFeedCard.chipTitle(for: watch(expires: expires), honesty: honesty),
      "nws memphis · severe thunderstorm watch until 9pm"
    )
    XCTAssertEqual(
      AlertsFeedCard.chipUntil(for: watch(expires: expires), honesty: honesty),
      "Scattered storms after 4pm. Hail possible in the strongest cells."
    )
    XCTAssertEqual(AlertsFeedCard.chipTitle(for: watch(expires: expires)), "Severe Thunderstorm Watch")
  }

  func testAlertChipPrefixesWFOOnAdvisory() {
    let honesty = HonestyStripCopy.content(
      officeName: "Memphis, TN",
      cwa: "MEG",
      alerts: [advisory()],
      briefingItems: [],
      now: now,
      timeZone: chicago
    )
    XCTAssertEqual(AlertsFeedCard.chipTitle(for: advisory(), honesty: honesty), "Heat Advisory")
    XCTAssertTrue(
      AlertsFeedCard.chipUntil(for: advisory(), honesty: honesty)
        .hasPrefix("nws memphis · ")
    )
  }

  func testAssemblerInsertsCalmStripAfterNow() {
    let rows = FeedAssembler.rows(
      items: [.now, .hourly],
      weatherError: nil,
      showsStandaloneHonestyStrip: true
    )
    XCTAssertEqual(rows, [.item(.now), .honestyStrip, .item(.hourly)])
  }

  func testEnsembleDisagreeBecomesSecondLineAndWinsOverAFD() {
    let expires = date(year: 2026, month: 9, day: 9, hour: 21, minute: 0)
    let times = (0..<6).map { date(year: 2026, month: 9, day: 9, hour: 15 + $0) }
    let verdict = EnsembleAgreement.evaluate(
      times: times,
      members: [
        wetAt(1, length: 6),
        wetAt(2, length: 6),
        wetAt(4, length: 6),
        wetAt(4, length: 6),
      ],
      stormByMember: [
        [false, true, false, false, false, false],
        [false, false, false, false, false, false],
        [false, false, false, false, true, false],
        [false, false, false, false, false, false],
      ],
      now: now
    )
    let content = HonestyStripCopy.content(
      officeName: "Memphis, TN",
      cwa: "MEG",
      alerts: [watch(expires: expires)],
      briefingItems: [afdItem()],
      ensemble: verdict,
      now: now,
      timeZone: chicago
    )
    XCTAssertEqual(
      content?.primaryLine,
      "nws memphis · severe thunderstorm watch until 9pm"
    )
    XCTAssertEqual(
      content?.secondLine,
      "models disagree — storm may start 4–7pm"
    )
    XCTAssertTrue(content?.showsEnsembleLine == true)
    XCTAssertEqual(
      AlertsFeedCard.chipUntil(for: watch(expires: expires), honesty: content),
      "models disagree — storm may start 4–7pm"
    )
  }

  func testEnsembleAgreeKeepsAFDOnSevereAndOmitsCalmSecondLine() {
    let expires = date(year: 2026, month: 9, day: 9, hour: 21, minute: 0)
    let times = (0..<6).map { date(year: 2026, month: 9, day: 9, hour: 15 + $0) }
    let agree = EnsembleAgreement.evaluate(
      times: times,
      members: Array(repeating: Array(repeating: 0.0, count: 6), count: 6),
      now: now
    )
    let severe = HonestyStripCopy.content(
      officeName: "Memphis, TN",
      cwa: "MEG",
      alerts: [watch(expires: expires)],
      briefingItems: [afdItem()],
      ensemble: agree,
      now: now,
      timeZone: chicago
    )
    XCTAssertNil(severe?.ensembleSentence)
    XCTAssertEqual(
      severe?.secondLine,
      "Scattered storms after 4pm. Hail possible in the strongest cells."
    )

    let calm = HonestyStripCopy.content(
      officeName: "Memphis, TN",
      cwa: "MEG",
      alerts: [],
      briefingItems: [afdItem()],
      ensemble: agree,
      now: now,
      timeZone: chicago
    )
    XCTAssertNil(calm?.secondLine)
    XCTAssertEqual(calm?.primaryLine, "nws memphis")
  }

  func testMissingEnsembleLeavesMVP1Strip() {
    let content = HonestyStripCopy.content(
      officeName: "Memphis, TN",
      cwa: "MEG",
      alerts: [],
      briefingItems: [],
      ensemble: nil,
      now: now,
      timeZone: chicago
    )
    XCTAssertEqual(content?.primaryLine, "nws memphis")
    XCTAssertNil(content?.secondLine)
    XCTAssertFalse(content?.showsEnsembleLine == true)
  }

  func testAssemblerOmitsStripOnStoryDay() {
    let rows = FeedAssembler.rows(
      items: [.now, .alerts, .hourly],
      weatherError: "No internet connection.",
      showsStandaloneHonestyStrip: false
    )
    XCTAssertEqual(rows, [.errorBanner, .item(.now), .item(.alerts), .item(.hourly)])
    XCTAssertFalse(rows.contains(.honestyStrip))
  }

  private func watch(expires: Date) -> NWSAlert {
    NWSAlert(
      id: "svs",
      event: "Severe Thunderstorm Watch",
      severity: "Severe",
      headline: "Severe Thunderstorm Watch issued September 9 at 3:00PM CDT",
      description: nil,
      instruction: nil,
      expires: expires,
      areaDesc: "DeSoto, MS",
      latitude: 34.96,
      longitude: -89.83
    )
  }

  private func warning(expires: Date) -> NWSAlert {
    NWSAlert(
      id: "tor",
      event: "Tornado Warning",
      severity: "Extreme",
      headline: "Tornado Warning issued September 9 at 3:00PM CDT",
      description: nil,
      instruction: nil,
      expires: expires,
      areaDesc: "Hillsborough, FL",
      latitude: 27.95,
      longitude: -82.46
    )
  }

  private func advisory() -> NWSAlert {
    NWSAlert(
      id: "ht",
      event: "Heat Advisory",
      severity: "Moderate",
      headline: "Heat Advisory issued September 9 at 3:00PM CDT",
      description: nil,
      instruction: nil,
      expires: date(year: 2026, month: 9, day: 9, hour: 20, minute: 0),
      areaDesc: "DeSoto, MS",
      latitude: 34.96,
      longitude: -89.83
    )
  }

  private func afdItem() -> LocalBriefingItem {
    LocalBriefingItem(
      id: "afd-1",
      title: "Scattered storms after 4pm. Hail possible in the strongest cells.",
      sourceName: "NWS Memphis",
      issuedAt: now,
      url: LocalBriefingParser.productPageURL(cwa: "MEG", productCode: "AFD"),
      productCode: "AFD",
      officeID: "MEG",
      imageURL: nil
    )
  }

  private func wetAt(_ index: Int, length: Int) -> [Double] {
    var series = Array(repeating: 0.0, count: length)
    series[index] = 0.05
    return series
  }

  private func newsItem() -> LocalBriefingItem {
    LocalBriefingItem(
      id: "news-1",
      title: "Local station recap",
      sourceName: "WMC",
      issuedAt: now,
      url: URL(string: "https://example.com/news")!,
      productCode: "NEWS",
      officeID: "MEG",
      imageURL: nil
    )
  }

}

private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "America/Chicago")!
  return calendar.date(
    from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
  )!
}
