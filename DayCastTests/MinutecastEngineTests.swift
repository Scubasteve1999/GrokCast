import XCTest

@testable import DayCast

final class MinutecastEngineTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_700_000_000)

  // MARK: - Summaries from fixture slots

  func testClearSummaryWhenAllSlotsDry() {
    let summary = MinutecastEngine.summary(from: drySlots(), units: .fahrenheit, now: now)
    XCTAssertEqual(summary.kind, .clear)
    XCTAssertEqual(summary.message, "Dry for the next 2 hours")
    XCTAssertEqual(summary.icon, "sun.max.fill")
    XCTAssertEqual(summary.strip.count, 8)
    XCTAssertFalse(PrecipFeedVisibility.hasContent(summary: summary))
    XCTAssertTrue(PrecipFeedVisibility.showsCard(summary: summary))
    XCTAssertEqual(
      PrecipFeedVisibility.timingSentence(for: summary),
      "Dry for the next 2 hours")
  }

  func testStartsSoonSummaryFromFirstWetAt30Min() {
    let summary = MinutecastEngine.summary(
      from: slots(wetAt: [2]), units: .fahrenheit, now: now)
    XCTAssertEqual(summary.kind, .startsSoon)
    XCTAssertEqual(summary.message, "Rain likely in ~30 min")
    XCTAssertEqual(summary.icon, "cloud.rain.fill")
    XCTAssertTrue(PrecipFeedVisibility.hasContent(summary: summary))
    XCTAssertEqual(
      PrecipFeedVisibility.timingSentence(for: summary),
      "Rain likely in ~30 min")
  }

  func testOngoingSummaryWhenEverySlotIsWet() {
    let summary = MinutecastEngine.summary(
      from: slots(wetAt: Array(0..<8)), units: .fahrenheit, now: now)
    XCTAssertEqual(summary.kind, .ongoing)
    XCTAssertEqual(summary.message, "Rain likely for the next 2 hours")
    XCTAssertEqual(summary.icon, "cloud.rain.fill")
    XCTAssertTrue(PrecipFeedVisibility.hasContent(summary: summary))
  }

  func testOngoingSummaryWhenRainIsNowButNotEverySlot() {
    let summary = MinutecastEngine.summary(
      from: slots(wetAt: [0, 7]), units: .fahrenheit, now: now)
    XCTAssertEqual(summary.kind, .ongoing)
    XCTAssertEqual(summary.message, "Rain now")
    XCTAssertTrue(PrecipFeedVisibility.hasContent(summary: summary))
  }

  func testStoppingSoonSummaryWhenRainEndsInsideTheStrip() {
    let summary = MinutecastEngine.summary(
      from: slots(wetAt: [0, 1]), units: .fahrenheit, now: now)
    XCTAssertEqual(summary.kind, .stoppingSoon)
    XCTAssertEqual(summary.message, "Rain ending in ~30 min")
    XCTAssertEqual(summary.icon, "cloud.drizzle.fill")
    XCTAssertTrue(PrecipFeedVisibility.hasContent(summary: summary))
  }

  func testEmptySlotsAreClearAndHidden() {
    let summary = MinutecastEngine.summary(from: [], units: .fahrenheit, now: now)
    XCTAssertEqual(summary.kind, .clear)
    XCTAssertEqual(summary.message, "Precipitation data unavailable")
    XCTAssertTrue(summary.strip.isEmpty)
    XCTAssertFalse(PrecipFeedVisibility.hasContent(summary: summary))
    XCTAssertFalse(PrecipFeedVisibility.showsCard(summary: summary))
  }

  func testChanceThresholdFortyFiveCountsAsWet() {
    let borderline = (0..<8).map { index in
      MinutelyForecast(
        time: now.addingTimeInterval(Double(index) * 15 * 60),
        precipitation: 0,
        precipChance: index == 2 ? 45 : 0)
    }
    let summary = MinutecastEngine.summary(from: borderline, units: .fahrenheit, now: now)
    XCTAssertEqual(summary.kind, .startsSoon)
    XCTAssertEqual(MinutecastEngine.firstWetIndex(in: borderline, units: .fahrenheit, now: now), 2)
  }

  func testClearIconAndHiddenWhenChanceIsJustUnderThreshold() {
    let dry = (0..<8).map { index in
      MinutelyForecast(
        time: now.addingTimeInterval(Double(index) * 15 * 60),
        precipitation: 0,
        precipChance: 44)
    }
    let summary = MinutecastEngine.summary(from: dry, units: .fahrenheit, now: now)
    XCTAssertEqual(summary.kind, .clear)
    XCTAssertNil(MinutecastEngine.firstWetIndex(in: dry, units: .fahrenheit, now: now))
    XCTAssertFalse(PrecipFeedVisibility.hasContent(summary: summary))
  }

  // MARK: - Agreement

  func testAgreementWhenBothClear() {
    let result = MinutecastAgreement.compare(
      hrrr: drySlots(),
      openMeteo: drySlots(),
      units: .fahrenheit,
      now: now)
    XCTAssertEqual(result, .agree)
    XCTAssertNil(MinutecastAgreement.caption(for: result))
    XCTAssertNil(MinutecastAgreement.grokNote(for: result))
  }

  func testAgreementWhenKindsMatchAndFirstWetWithinOneSlot() {
    let result = MinutecastAgreement.compare(
      hrrr: slots(wetAt: [2]),
      openMeteo: slots(wetAt: [3]),
      units: .fahrenheit,
      now: now)
    XCTAssertEqual(result, .agree)
    XCTAssertNil(MinutecastAgreement.caption(for: result))
  }

  func testDisagreementWhenKindDiffers() {
    let hrrr = slots(wetAt: Array(0..<8))
    let openMeteo = drySlots()
    let result = MinutecastAgreement.compare(
      hrrr: hrrr, openMeteo: openMeteo, units: .fahrenheit, now: now)
    guard case .disagree(let preferred, let otherKind) = result else {
      return XCTFail("expected kind disagreement")
    }
    XCTAssertEqual(preferred.kind, .ongoing)
    XCTAssertEqual(otherKind, .clear)
    XCTAssertEqual(MinutecastAgreement.caption(for: result), "Sources differ · Open-Meteo clearer")
    XCTAssertEqual(
      MinutecastAgreement.grokNote(for: result),
      "Open-Meteo blended minutecast differs: clear / drier")
  }

  func testDisagreementWhenFirstWetIndexDiffersByTwoSlots() {
    let hrrr = slots(wetAt: [2])
    let openMeteo = slots(wetAt: [4])
    XCTAssertEqual(MinutecastEngine.firstWetIndex(in: hrrr, units: .fahrenheit, now: now), 2)
    XCTAssertEqual(MinutecastEngine.firstWetIndex(in: openMeteo, units: .fahrenheit, now: now), 4)
    let result = MinutecastAgreement.compare(
      hrrr: hrrr, openMeteo: openMeteo, units: .fahrenheit, now: now)
    guard case .disagree(let preferred, let otherKind) = result else {
      return XCTFail("expected timing disagreement of ≥ 2 slots")
    }
    XCTAssertEqual(preferred.kind, .startsSoon)
    XCTAssertEqual(otherKind, .startsSoon)
    XCTAssertEqual(
      MinutecastAgreement.caption(for: result),
      "Sources differ · Open-Meteo starts sooner")
    XCTAssertNotNil(MinutecastAgreement.caption(for: result))
  }

  func testEmptySourceArraysAgreeAndCaptionIsNil() {
    XCTAssertEqual(
      MinutecastAgreement.compare(hrrr: [], openMeteo: drySlots(), now: now),
      .agree)
    XCTAssertEqual(
      MinutecastAgreement.compare(hrrr: drySlots(), openMeteo: [], now: now),
      .agree)
    XCTAssertNil(MinutecastAgreement.caption(for: .agree))
  }

  func testCaptionNilWhenAgreeNonNilWhenDisagree() {
    let agree = MinutecastAgreement.compare(
      hrrr: slots(wetAt: [0, 1]),
      openMeteo: slots(wetAt: [0, 1]),
      units: .fahrenheit,
      now: now)
    XCTAssertEqual(agree, .agree)
    XCTAssertNil(MinutecastAgreement.caption(for: agree))

    let disagree = MinutecastAgreement.compare(
      hrrr: slots(wetAt: [0, 1]),
      openMeteo: slots(wetAt: Array(0..<8)),
      units: .fahrenheit,
      now: now)
    guard case .disagree(_, .ongoing) = disagree else {
      return XCTFail("expected Open-Meteo ongoing vs HRRR stoppingSoon")
    }
    XCTAssertEqual(
      MinutecastAgreement.caption(for: disagree),
      "Sources differ · Open-Meteo wetter now")
  }

  // MARK: - Strip visibility + VoiceOver

  func testPrecipStripHiddenWhenClearShownWhenWet() {
    XCTAssertFalse(
      PrecipFeedVisibility.hasContent(
        summary: MinutecastEngine.summary(from: drySlots(), now: now)))
    XCTAssertTrue(
      PrecipFeedVisibility.hasContent(
        summary: MinutecastEngine.summary(from: slots(wetAt: [2]), now: now)))
    XCTAssertTrue(
      PrecipFeedVisibility.hasContent(
        summary: MinutecastEngine.summary(from: slots(wetAt: Array(0..<8)), now: now)))
    XCTAssertTrue(
      PrecipFeedVisibility.hasContent(
        summary: MinutecastEngine.summary(from: slots(wetAt: [0, 1]), now: now)))
  }

  func testStripAccessibilitySaysNextHourNotMinutecast() {
    let label = MinutecastStrip.accessibilityLabel(
      message: "Precipitation likely in ~30 min")
    XCTAssertEqual(label, "Next 2 Hours. Precipitation likely in ~30 min")
    XCTAssertFalse(label.localizedCaseInsensitiveContains("minutecast"))

    let withCaption = MinutecastStrip.accessibilityLabel(
      message: "Precipitation now",
      disagreementCaption: "Sources differ · Open-Meteo clearer")
    XCTAssertEqual(
      withCaption,
      "Next 2 Hours. Precipitation now. Sources differ · Open-Meteo clearer")
    XCTAssertFalse(withCaption.localizedCaseInsensitiveContains("minutecast"))
  }

  func testHeroLineUsesChanceWhenDryAndTimingWhenWet() {
    let dry = MinutecastEngine.summary(from: drySlots(), now: now)
    XCTAssertEqual(
      PrecipOutlookCopy.heroLine(summary: dry, rainChance: 1),
      "Next 2 Hours rain chance 1%"
    )
    let wet = MinutecastEngine.summary(from: slots(wetAt: [2]), now: now)
    XCTAssertEqual(wet.kind, .startsSoon)
    XCTAssertEqual(
      PrecipOutlookCopy.heroLine(summary: wet, rainChance: 40),
      wet.message
    )
    XCTAssertFalse(wet.message.localizedCaseInsensitiveContains("minutecast"))
  }

  func testPrecipCardAccessibilityKeepsNextHourTitle() {
    let label = PrecipFeedCard.accessibilityLabel(
      message: "Precipitation likely in ~30 min")
    XCTAssertEqual(label, "Next 2 Hours. Precipitation likely in ~30 min. Opens forecast.")
    XCTAssertFalse(label.localizedCaseInsensitiveContains("minutecast"))
  }

  // MARK: - Fixtures

  private func drySlots() -> [MinutelyForecast] {
    slots(wetAt: [])
  }

  private func slots(wetAt: [Int]) -> [MinutelyForecast] {
    (0..<8).map { index in
      let wet = wetAt.contains(index)
      return MinutelyForecast(
        time: now.addingTimeInterval(Double(index) * 15 * 60),
        precipitation: wet ? 0.05 : 0,
        precipChance: wet ? 80 : 5)
    }
  }
}
