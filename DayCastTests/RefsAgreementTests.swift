import XCTest

@testable import DayCast

final class RefsAgreementTests: XCTestCase {
  private var chicago: TimeZone { TimeZone(identifier: "America/Chicago")! }

  private func utc(_ string: String) -> Date {
    ISO8601DateFormatter().date(from: string)!
  }

  private func sample(_ iso: String, _ eas: Double) -> RefsAgreement.HourSample {
    RefsAgreement.HourSample(valid: utc(iso), easPercent: eas)
  }

  private func meta(asOf: String, hrrr: String? = nil) -> RefsAgreement.Meta {
    RefsAgreement.Meta(
      refsCycle: "2026-09-21T12:00:00Z",
      hrrrCycle: hrrr,
      domain: "conus",
      asOf: utc(asOf)
    )
  }

  func testDryConsensusOmitsWindowAndSoftPeak() {
    let payload = RefsAgreement.classify(
      refsHours: [
        sample("2026-09-21T18:00:00Z", 4),
        sample("2026-09-21T19:00:00Z", 8),
      ],
      hrrrHours: [],
      timeZone: chicago,
      meta: meta(asOf: "2026-09-21T17:30:00Z", hrrr: "2026-09-21T17:00:00Z")
    )
    XCTAssertEqual(payload.agreementTier, .dryConsensus)
    XCTAssertNil(payload.timingWindow)
    XCTAssertNil(payload.divergence)
    XCTAssertEqual(payload.sources.labels, ["REFS", "HRRR"])
    XCTAssertTrue(payload.parallel)
    XCTAssertFalse(RefsAgreementCopy.accessibility(payload, timeZone: chicago).contains("EAS"))
  }

  func testLockedWindowKeepsSoftPeakInside() {
    let payload = RefsAgreement.classify(
      refsHours: [
        sample("2026-09-21T19:00:00Z", 12),
        sample("2026-09-21T20:00:00Z", 72),
        sample("2026-09-21T21:00:00Z", 61),
        sample("2026-09-21T22:00:00Z", 5),
      ],
      hrrrHours: [
        RefsAgreement.HrrrSample(valid: utc("2026-09-21T20:00:00Z"), apcpMillimeters: 1)
      ],
      timeZone: chicago,
      meta: meta(asOf: "2026-09-21T18:00:00Z")
    )
    XCTAssertEqual(payload.agreementTier, .locked)
    XCTAssertEqual(payload.timingWindow?.widthHours, 2)
    let peak = payload.timingWindow?.softPeakLocal
    let start = payload.timingWindow?.startLocal
    let end = payload.timingWindow?.endLocal
    XCTAssertNotNil(peak)
    XCTAssertGreaterThanOrEqual(peak ?? .distantPast, start ?? .distantFuture)
    XCTAssertLessThan(peak ?? .distantFuture, end ?? .distantPast)
    XCTAssertNil(payload.divergence)
  }

  func testLikelyWindowWithoutHourlyModel() {
    let payload = RefsAgreement.classify(
      refsHours: [
        sample("2026-09-21T19:00:00Z", 44),
        sample("2026-09-21T20:00:00Z", 51),
        sample("2026-09-21T21:00:00Z", 40),
      ],
      hrrrHours: nil,
      timeZone: chicago,
      meta: meta(asOf: "2026-09-21T18:00:00Z")
    )
    XCTAssertEqual(payload.agreementTier, .likelyWindow)
    XCTAssertEqual(payload.timingWindow?.widthHours, 3)
    XCTAssertEqual(payload.sources.labels, ["REFS"])
    XCTAssertNil(payload.sources.hrrrCycle)
  }

  func testWideWindow() {
    let payload = RefsAgreement.classify(
      refsHours: [
        sample("2026-09-21T18:00:00Z", 31),
        sample("2026-09-21T19:00:00Z", 33),
        sample("2026-09-21T22:00:00Z", 36),
        sample("2026-09-21T23:00:00Z", 31),
      ],
      hrrrHours: [],
      timeZone: chicago,
      meta: meta(asOf: "2026-09-21T17:00:00Z")
    )
    XCTAssertEqual(payload.agreementTier, .wideWindow)
    XCTAssertGreaterThanOrEqual(payload.timingWindow?.widthHours ?? 0, 5)
  }

  func testSplitWhenHourlyPeakIsOutsideTheWindow() {
    let payload = RefsAgreement.classify(
      refsHours: [
        sample("2026-09-21T19:00:00Z", 48),
        sample("2026-09-21T20:00:00Z", 62),
        sample("2026-09-21T21:00:00Z", 40),
      ],
      hrrrHours: [
        RefsAgreement.HrrrSample(valid: utc("2026-09-21T18:00:00Z"), apcpMillimeters: 2.4)
      ],
      timeZone: chicago,
      meta: meta(asOf: "2026-09-21T17:40:00Z", hrrr: "2026-09-21T17:00:00Z")
    )
    XCTAssertEqual(payload.agreementTier, .split)
    XCTAssertEqual(payload.divergence?.present, true)
    XCTAssertEqual(
      payload.divergence?.sentence,
      "The hourly model puts the rain near 1pm; the ensemble still says anywhere from 2 to 5pm — the timing isn't locked yet."
    )
    XCTAssertFalse(payload.divergence?.sentence.contains("EAS") ?? true)
    XCTAssertEqual(
      RefsAgreementCopy.primaryLine(payload, timeZone: chicago),
      "2 to 5pm"
    )
  }

  func testSplitWithoutAWindowDoesNotClaimDry() {
    let payload = RefsAgreement.classify(
      refsHours: [
        sample("2026-09-21T19:00:00Z", 8),
        sample("2026-09-21T20:00:00Z", 4),
      ],
      hrrrHours: [
        RefsAgreement.HrrrSample(valid: utc("2026-09-21T20:00:00Z"), apcpMillimeters: 1.2)
      ],
      timeZone: chicago,
      meta: meta(asOf: "2026-09-21T18:00:00Z", hrrr: "2026-09-21T18:00:00Z")
    )
    XCTAssertEqual(payload.agreementTier, .split)
    XCTAssertNil(payload.timingWindow)
    XCTAssertNotEqual(
      RefsAgreementCopy.primaryLine(payload, timeZone: chicago),
      RefsAgreementCopy.dryLine
    )
    XCTAssertEqual(
      RefsAgreementCopy.primaryLine(payload, timeZone: chicago),
      payload.divergence?.sentence
    )
  }

  func testCanonicalSentenceStaysOnTheHour() {
    let start = utc("2026-09-21T19:00:00Z")
    let end = utc("2026-09-21T22:00:00Z")
    XCTAssertEqual(RefsAgreement.hourLabel(start, timeZone: chicago), "2pm")
    XCTAssertEqual(
      RefsAgreement.rangePhrase(start: start, end: end, timeZone: chicago),
      "2 to 5pm"
    )
    XCTAssertEqual(
      RefsAgreement.divergenceSentence(
        hrrrPeak: utc("2026-09-21T20:00:00Z"),
        windowStart: start,
        windowEnd: end,
        timeZone: chicago
      ),
      "The hourly model puts the rain near 3pm; the ensemble still says anywhere from 2 to 5pm — the timing isn't locked yet."
    )
  }

  func testParallelFlipsAtCutover() {
    XCTAssertTrue(RefsAgreement.parallel(at: utc("2026-10-14T11:59:00Z")))
    XCTAssertFalse(RefsAgreement.parallel(at: utc("2026-10-14T12:00:00Z")))
    XCTAssertEqual(RefsAgreement.cutoverUTC, utc("2026-10-14T12:00:00Z"))
  }

  func testDecodeDropsSoftPeakWithoutAWindowAndStripsEASCopy() throws {
    let json = """
      {
        "agreement_tier": "dry_consensus",
        "timing_window": {
          "start_local": "2026-09-21T14:17:00-05:00",
          "end_local": "2026-09-21T17:00:00-05:00",
          "width_hours": 3,
          "soft_peak_local": "2026-09-21T18:00:00-05:00"
        },
        "sources": {
          "refs_cycle": "2026-09-21T12:00:00Z",
          "domain": "conus",
          "labels": ["REFS", "EAS", "HRRR"]
        },
        "divergence": {
          "present": true,
          "sentence": "EAS says 3:17pm."
        },
        "as_of": "2026-09-21T18:00:00.000Z",
        "parallel": true
      }
      """.data(using: .utf8)!
    let payload = try XCTUnwrap(RefsAgreement.decode(json))
    XCTAssertEqual(payload.agreementTier, .dryConsensus)
    XCTAssertNil(payload.timingWindow)
    XCTAssertEqual(payload.sources.labels, ["REFS", "HRRR"])
    XCTAssertNil(payload.divergence)
    XCTAssertTrue(payload.parallel)
  }

  func testDecodeFloorsMinutesAndDropsASoftPeakOutsideTheWindow() throws {
    let json = """
      {
        "agreement_tier": "likely_window",
        "timing_window": {
          "start_local": "2026-09-21T14:17:00-05:00",
          "end_local": "2026-09-21T17:00:00-05:00",
          "width_hours": 3,
          "soft_peak_local": "2026-09-21T18:00:00-05:00"
        },
        "sources": {
          "refs_cycle": "2026-09-21T12:00:00Z",
          "domain": "conus",
          "labels": ["REFS"]
        },
        "as_of": "2026-09-21T18:00:00Z",
        "parallel": true
      }
      """.data(using: .utf8)!
    let payload = try XCTUnwrap(RefsAgreement.decode(json))
    XCTAssertEqual(payload.timingWindow?.startLocal, utc("2026-09-21T19:00:00Z"))
    XCTAssertNil(payload.timingWindow?.softPeakLocal)
    XCTAssertEqual(
      RefsAgreementCopy.windowPhrase(payload.timingWindow!, timeZone: chicago),
      "2 to 5pm"
    )
  }

  func testDebugSampleIsTheCanonicalSentenceAndMarkedStub() {
    let sample = RefsAgreement.debugSample
    XCTAssertEqual(sample.agreementTier, .split)
    XCTAssertEqual(sample.stub, true)
    XCTAssertTrue(sample.parallel)
    XCTAssertEqual(
      sample.divergence?.sentence,
      "The hourly model puts the rain near 3pm; the ensemble still says anywhere from 2 to 5pm — the timing isn't locked yet."
    )
    XCTAssertEqual(
      RefsAgreementCopy.windowPhrase(sample.timingWindow!, timeZone: chicago),
      "2 to 5pm"
    )
    XCTAssertEqual(RefsAgreementCopy.sourceLine(sample.sources.labels), "REFS · HRRR")
    XCTAssertFalse(RefsAgreementCopy.tierTitle(sample.agreementTier).contains("EAS"))
  }

  func testChipSitsUnderHourlyAndApartFromTheOtherStrips() {
    let rows = FeedAssembler.rows(
      items: [.now, .hourly, .radar],
      weatherError: nil,
      showsStandaloneHonestyStrip: true,
      showsForecastEraNotice: true,
      showsRefsAgreement: true
    )
    XCTAssertEqual(
      rows,
      [
        .item(.now),
        .honestyStrip,
        .forecastEraNotice,
        .item(.hourly),
        .refsAgreement,
        .item(.radar),
      ]
    )
    XCTAssertNotEqual(TodayFeedRow.refsAgreement, .honestyStrip)
    XCTAssertNotEqual(TodayFeedRow.refsAgreement, .forecastEraNotice)
  }

  func testRefsChipIsOmittedWhenHourlyIsHidden() {
    var rows: [TodayFeedRow] = [.item(.now), .item(.radar)]
    FeedAssembler.insertRefsAgreement(into: &rows)
    XCTAssertFalse(rows.contains(.refsAgreement))
  }
}
