import XCTest

@testable import DayCast

final class EnsembleAgreementTests: XCTestCase {
  private var chicago: TimeZone { TimeZone(identifier: "America/Chicago")! }
  private let now = date(year: 2026, month: 9, day: 9, hour: 15, minute: 0)

  func testThinSampleHides() {
    let times = hourlyTimes(from: 15, count: 6)
    XCTAssertNil(
      EnsembleAgreement.evaluate(
        times: times,
        members: [dry(6), dry(6), wetAt(0, length: 6)],
        now: now
      )
    )
  }

  func testAgreeDryHidesChip() {
    let times = hourlyTimes(from: 15, count: 8)
    let verdict = EnsembleAgreement.evaluate(
      times: times,
      members: Array(repeating: dry(8), count: 8),
      now: now
    )
    XCTAssertEqual(verdict?.state, .agree)
    XCTAssertEqual(verdict?.showsChip, false)
    XCTAssertNil(EnsembleAgreementCopy.sentence(for: verdict, timeZone: chicago))
  }

  func testAgreeTightClusterHidesChip() {
    let times = hourlyTimes(from: 15, count: 8)
    let members = [
      wetAt(2, length: 8),
      wetAt(2, length: 8),
      wetAt(2, length: 8),
      wetAt(3, length: 8),
    ]
    let verdict = EnsembleAgreement.evaluate(times: times, members: members, now: now)
    XCTAssertEqual(verdict?.state, .agree)
    XCTAssertNil(EnsembleAgreementCopy.sentence(for: verdict, timeZone: chicago))
  }

  func testSoftDisagreeTwoHourSpread() {
    let times = hourlyTimes(from: 15, count: 8)
    let members = [
      wetAt(1, length: 8),
      wetAt(2, length: 8),
      wetAt(3, length: 8),
      wetAt(3, length: 8),
    ]
    let verdict = EnsembleAgreement.evaluate(times: times, members: members, now: now)
    XCTAssertEqual(verdict?.state, .softDisagree)
    XCTAssertEqual(
      EnsembleAgreementCopy.sentence(for: verdict, timeZone: chicago),
      "models differ — rain may start 4–6pm"
    )
  }

  func testStrongDisagreeFourHourSpread() {
    let times = hourlyTimes(from: 15, count: 8)
    let members = [
      wetAt(1, length: 8),
      wetAt(2, length: 8),
      wetAt(4, length: 8),
      wetAt(5, length: 8),
    ]
    let verdict = EnsembleAgreement.evaluate(times: times, members: members, now: now)
    XCTAssertEqual(verdict?.state, .strongDisagree)
    XCTAssertEqual(
      EnsembleAgreementCopy.sentence(for: verdict, timeZone: chicago),
      "models disagree — rain may start 4–8pm"
    )
  }

  func testWetDrySplitIsStrongDisagree() {
    let times = hourlyTimes(from: 15, count: 8)
    let members = [
      wetAt(1, length: 8),
      wetAt(1, length: 8),
      dry(8),
      dry(8),
    ]
    let verdict = EnsembleAgreement.evaluate(times: times, members: members, now: now)
    XCTAssertEqual(verdict?.state, .strongDisagree)
    XCTAssertEqual(verdict?.wetFraction, 0.5)
    XCTAssertEqual(
      EnsembleAgreementCopy.sentence(for: verdict, timeZone: chicago),
      "models disagree — rain may miss or start around 4pm"
    )
  }

  func testPrimaryWetEnsembleDryIsSoftHoldOff() {
    let times = hourlyTimes(from: 15, count: 8)
    let verdict = EnsembleAgreement.evaluate(
      times: times,
      members: Array(repeating: dry(8), count: 6),
      primaryIsWetInWindow: true,
      now: now
    )
    XCTAssertEqual(verdict?.state, .softDisagree)
    XCTAssertEqual(
      EnsembleAgreementCopy.sentence(for: verdict, timeZone: chicago),
      "models differ — rain may hold off"
    )
  }

  func testStormNounWhenThunderCodes() {
    let times = hourlyTimes(from: 15, count: 6)
    let members = [
      wetAt(1, length: 6),
      wetAt(3, length: 6),
      wetAt(4, length: 6),
      wetAt(4, length: 6),
    ]
    let storm = [
      [false, true, false, false, false, false],
      [false, false, false, true, false, false],
      [false, false, false, false, false, false],
      [false, false, false, false, false, false],
    ]
    let verdict = EnsembleAgreement.evaluate(
      times: times,
      members: members,
      stormByMember: storm,
      now: now
    )
    XCTAssertEqual(verdict?.state, .strongDisagree)
    XCTAssertEqual(verdict?.isStorm, true)
    XCTAssertEqual(
      EnsembleAgreementCopy.sentence(for: verdict, timeZone: chicago),
      "models disagree — storm may start 4–7pm"
    )
  }

  func testUpcomingHourIsNotAlreadyWetAfterHalfPast() {
    let halfPast = date(year: 2026, month: 9, day: 9, hour: 15, minute: 45)
    let firstWet = date(year: 2026, month: 9, day: 9, hour: 16, minute: 0)
    let lookbackAhead = halfPast.addingTimeInterval(
      Double(EnsembleAgreement.Thresholds.lookbackMinutes) * 60
    )
    // 16:00 is inside now+30m, but that must not count as already raining.
    XCTAssertTrue(firstWet <= lookbackAhead)
    XCTAssertFalse(firstWet <= halfPast)

    let times = hourlyTimes(from: 15, count: 8)
    let members = [
      wetAt(1, length: 8),
      wetAt(1, length: 8),
      dry(8),
      dry(8),
    ]
    let verdict = EnsembleAgreement.evaluate(times: times, members: members, now: halfPast)
    XCTAssertEqual(verdict?.alreadyWet, false)
    XCTAssertEqual(verdict?.startRange?.lowerBound, firstWet)
    let sentence = EnsembleAgreementCopy.sentence(for: verdict, timeZone: chicago)
    XCTAssertEqual(sentence, "models disagree — rain may miss or start around 4pm")
    XCTAssertFalse(sentence?.contains("linger") == true)
    XCTAssertFalse(sentence?.contains("through") == true)
  }

  func testCurrentHourStaysAlreadyWetAfterHalfPast() {
    let halfPast = date(year: 2026, month: 9, day: 9, hour: 15, minute: 45)
    let firstWet = date(year: 2026, month: 9, day: 9, hour: 15, minute: 0)
    XCTAssertTrue(firstWet <= halfPast)

    let times = hourlyTimes(from: 15, count: 6)
    let members = [
      wetAt(0, length: 6),
      wetAt(3, length: 6),
      dry(6),
      dry(6),
    ]
    let verdict = EnsembleAgreement.evaluate(times: times, members: members, now: halfPast)
    XCTAssertEqual(verdict?.alreadyWet, true)
    XCTAssertEqual(verdict?.wetCount, 2)
    XCTAssertEqual(verdict?.startRange?.lowerBound, firstWet)
    XCTAssertEqual(
      EnsembleAgreementCopy.sentence(for: verdict, timeZone: chicago),
      "models disagree — rain may miss or linger through 6pm"
    )
  }

  func testFirstWetExactlyNowIsAlreadyWet() {
    let onTheHour = date(year: 2026, month: 9, day: 9, hour: 16, minute: 0)
    let times = hourlyTimes(from: 16, count: 6)
    let members = [
      wetAt(0, length: 6),
      wetAt(3, length: 6),
      dry(6),
      dry(6),
    ]
    let verdict = EnsembleAgreement.evaluate(times: times, members: members, now: onTheHour)
    XCTAssertEqual(verdict?.alreadyWet, true)
    XCTAssertEqual(
      EnsembleAgreementCopy.sentence(for: verdict, timeZone: chicago),
      "models disagree — rain may miss or linger through 7pm"
    )
  }

  func testLowFractionCurrentHourIsAlreadyWetAfterHalfPast() {
    let halfPast = date(year: 2026, month: 9, day: 9, hour: 15, minute: 45)
    let times = hourlyTimes(from: 15, count: 6)
    let members = [
      wetAt(0, length: 6),
      dry(6),
      dry(6),
      dry(6),
      dry(6),
      dry(6),
    ]
    let verdict = EnsembleAgreement.evaluate(
      times: times,
      members: members,
      primaryIsWetInWindow: true,
      now: halfPast
    )
    XCTAssertEqual(verdict?.state, .softDisagree)
    XCTAssertEqual(verdict?.alreadyWet, true)
    XCTAssertEqual(verdict?.wetCount, 1)
    XCTAssertEqual(
      EnsembleAgreementCopy.sentence(for: verdict, timeZone: chicago),
      "models differ — rain may miss or linger through 3pm"
    )
  }

  func testSplitSpreadSaysMayMissOrStart() {
    let times = hourlyTimes(from: 15, count: 8)
    let members = [
      wetAt(1, length: 8),
      wetAt(3, length: 8),
      dry(8),
      dry(8),
    ]
    let verdict = EnsembleAgreement.evaluate(times: times, members: members, now: now)
    XCTAssertEqual(verdict?.state, .strongDisagree)
    XCTAssertEqual(verdict?.alreadyWet, false)
    XCTAssertEqual(
      EnsembleAgreementCopy.sentence(for: verdict, timeZone: chicago),
      "models disagree — rain may miss or start 4–6pm"
    )
  }

  func testAlreadyWetSplitSaysMayMissOrLinger() {
    let times = hourlyTimes(from: 15, count: 6)
    let members = [
      wetAt(0, length: 6),
      wetAt(3, length: 6),
      dry(6),
      dry(6),
    ]
    let verdict = EnsembleAgreement.evaluate(times: times, members: members, now: now)
    XCTAssertEqual(verdict?.state, .strongDisagree)
    XCTAssertEqual(verdict?.alreadyWet, true)
    XCTAssertEqual(
      EnsembleAgreementCopy.sentence(for: verdict, timeZone: chicago),
      "models disagree — rain may miss or linger through 6pm"
    )
  }

  func testAlreadyWetUsesThroughNotStart() {
    let times = hourlyTimes(from: 15, count: 6)
    let members = Array(repeating: wetAt(0, length: 6), count: 4).enumerated().map { index, series in
      var copy = series
      if index == 3 { copy = wetAt(3, length: 6) }
      return copy
    }
    let verdict = EnsembleAgreement.evaluate(times: times, members: members, now: now)
    XCTAssertEqual(verdict?.alreadyWet, true)
    XCTAssertEqual(verdict?.state, .strongDisagree)
    XCTAssertEqual(
      EnsembleAgreementCopy.sentence(for: verdict, timeZone: chicago),
      "models disagree — rain timing still spread through 6pm"
    )
  }

  func testCopyNeverUsesFakeClocksOrWEA() {
    let times = hourlyTimes(from: 15, count: 8)
    let verdict = EnsembleAgreement.evaluate(
      times: times,
      members: [wetAt(1, length: 8), wetAt(2, length: 8), wetAt(4, length: 8), wetAt(5, length: 8)],
      now: now
    )
    let sentence = EnsembleAgreementCopy.sentence(for: verdict, timeZone: chicago) ?? ""
    XCTAssertFalse(sentence.contains(":"))
    XCTAssertFalse(sentence.localizedCaseInsensitiveContains("minutecast"))
    XCTAssertFalse(sentence.localizedCaseInsensitiveContains("most accurate"))
    XCTAssertFalse(sentence.localizedCaseInsensitiveContains("WEA"))
    XCTAssertFalse(sentence.localizedCaseInsensitiveContains("5:12"))
    XCTAssertTrue(sentence.contains("–"))
  }

  func testHourRangeSharesPeriod() {
    XCTAssertEqual(
      EnsembleAgreementCopy.hourRange(
        date(year: 2026, month: 9, day: 9, hour: 16),
        date(year: 2026, month: 9, day: 9, hour: 19),
        timeZone: chicago
      ),
      "4–7pm"
    )
    XCTAssertEqual(
      EnsembleAgreementCopy.hourRange(
        date(year: 2026, month: 9, day: 9, hour: 11),
        date(year: 2026, month: 9, day: 9, hour: 14),
        timeZone: chicago
      ),
      "11am–2pm"
    )
  }

  func testDecoderMapsMemberSuffixes() throws {
    let json = """
      {
        "timezone": "America/Chicago",
        "hourly": {
          "time": ["2026-09-09T15:00", "2026-09-09T16:00"],
          "precipitation": [0.0, 0.0],
          "precipitation_member01": [0.0, 0.2],
          "precipitation_member02": [0.0, 0.0],
          "precipitation_member03": [0.0, 0.0],
          "weather_code": [2, 2],
          "weather_code_member01": [2, 95],
          "weather_code_member02": [1, 2],
          "weather_code_member03": [3, 3]
        }
      }
      """.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(OpenMeteoEnsembleResponse.self, from: json)
    XCTAssertEqual(decoded.hourly?.precipSeries.count, 4)
    XCTAssertEqual(decoded.hourly?.weatherSeries.count, 4)
    let snapshot = EnsemblePrecipSnapshot.mapping(decoded, locationID: "loc")
    XCTAssertEqual(snapshot?.members.count, 4)
    XCTAssertEqual(snapshot?.stormByMember[1].last, true)
  }

  func testStaleSnapshotSoftFails() {
    let times = hourlyTimes(from: 15, count: 4)
    let snapshot = EnsemblePrecipSnapshot(
      locationID: "loc",
      fetchedAt: now.addingTimeInterval(-60 * 60),
      timeZoneIdentifier: "America/Chicago",
      times: times,
      members: Array(repeating: wetAt(1, length: 4), count: 4),
      stormByMember: []
    )
    XCTAssertNil(EnsembleAgreement.evaluate(snapshot: snapshot, now: now))
  }

  func testSettingsStillCreditsOpenMeteo() {
    XCTAssertEqual(AppLinks.openMeteo.absoluteString, "https://open-meteo.com/")
  }

  private func hourlyTimes(from hour: Int, count: Int) -> [Date] {
    (0..<count).map { offset in
      date(year: 2026, month: 9, day: 9, hour: hour + offset)
    }
  }

  private func dry(_ length: Int) -> [Double] {
    Array(repeating: 0, count: length)
  }

  private func wetAt(_ index: Int, length: Int) -> [Double] {
    var series = dry(length)
    guard series.indices.contains(index) else { return series }
    series[index] = 0.05
    return series
  }
}

private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "America/Chicago")!
  return calendar.date(
    from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
  )!
}
