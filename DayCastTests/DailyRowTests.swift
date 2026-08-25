import XCTest

@testable import DayCast

final class DailyRowTests: XCTestCase {
  private var chicago: TimeZone {
    TimeZone(identifier: "America/Chicago")!
  }

  func testDayHeadingKeepsTodayBareAndDatesTheRest() {
    XCTAssertEqual(
      DailyRow.dayHeading(date: Date(), isToday: true, timeZone: chicago),
      "Today")
    XCTAssertNil(DailyRow.dayNumber(date: Date(), isToday: true, timeZone: chicago))

    let wednesday = date(year: 2026, month: 8, day: 26)
    XCTAssertEqual(
      DailyRow.dayHeading(date: wednesday, isToday: false, timeZone: chicago),
      "Wed 26")
    XCTAssertEqual(
      DailyRow.dayNumber(date: wednesday, isToday: false, timeZone: chicago),
      "26")
  }

  func testVoiceOverSpeaksTheDatedWeekday() {
    let label = DailyRow.accessibilityLabel(
      day: DailyRow.dayHeading(
        date: date(year: 2026, month: 8, day: 26), isToday: false, timeZone: chicago),
      condition: "Overcast",
      high: 94,
      low: 71,
      precipChance: 34
    )
    XCTAssertTrue(label.hasPrefix("Wed 26"))
    XCTAssertTrue(label.contains("34 percent"))
  }

  func testPrecipBelowTwentyIsQuietAndFiftyPlusIsHeavy() {
    XCTAssertEqual(DailyPrecipEmphasis.forChance(0), .none)
    XCTAssertEqual(DailyPrecipEmphasis.forChance(1), .quiet)
    XCTAssertEqual(DailyPrecipEmphasis.forChance(19), .quiet)
    XCTAssertEqual(DailyPrecipEmphasis.forChance(20), .notable)
    XCTAssertEqual(DailyPrecipEmphasis.forChance(49), .notable)
    XCTAssertEqual(DailyPrecipEmphasis.forChance(50), .high)
    XCTAssertEqual(DailyPrecipEmphasis.forChance(90), .high)
  }

  func testRangeBarIsFivePointsAndShortSpansAreNotCappedAtEight() {
    XCTAssertEqual(DailyTempRangeBarLayout.barHeight, 5)
    XCTAssertEqual(DailyTempRangeBarLayout.tickWidth, 1)
    let narrow = DailyTempRangeBarLayout.segmentWidth(
      low: 73, high: 75, periodLow: 70, periodHigh: 100, width: 80)
    let wider = DailyTempRangeBarLayout.segmentWidth(
      low: 73, high: 81, periodLow: 70, periodHigh: 100, width: 80)
    XCTAssertEqual(narrow, 80 * 2 / 30, accuracy: 0.05)
    XCTAssertLessThan(narrow, 8)
    XCTAssertGreaterThan(wider, narrow)
  }

  func testTodayTickSitsOnTheTenDayScale() {
    let x = DailyTempRangeBarLayout.x(
      for: 75, periodLow: 71, periodHigh: 94, width: 100)
    XCTAssertEqual(x, 100 * 4 / 23, accuracy: 0.05)
  }

  func testDayColumnWidenedForTheDateNotTheRowHeight() {
    XCTAssertEqual(DailyRow.dayColumnWidth, 72)
  }

  private func date(year: Int, month: Int, day: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = chicago
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
  }
}
