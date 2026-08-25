import XCTest

@testable import DayCast

final class DailyOutlookTests: XCTestCase {
  private var chicago: TimeZone { TimeZone(identifier: "America/Chicago")! }

  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = chicago
    return calendar
  }

  func testSentenceNamesTheDayAndAvoidsFalseCertainty() {
    let day = DailyForecast(
      date: calendar.date(from: DateComponents(year: 2026, month: 8, day: 25))!,
      high: 94,
      low: 74,
      precipChance: 57,
      weatherCode: 95,
      symbolName: "cloud.bolt.rain.fill",
      uvMax: 8,
      rainSum: nil,
      showersSum: nil,
      snowfallSum: nil,
      sunrise: nil,
      sunset: nil
    )
    let sentence = DailyOutlook.sentence(
      day: day, unit: .fahrenheit, calendar: calendar, timeZone: chicago)
    XCTAssertTrue(sentence.contains("57%"))
    XCTAssertTrue(sentence.localizedCaseInsensitiveContains("thunderstorm"))
    XCTAssertFalse(sentence.localizedCaseInsensitiveContains("will definitely"))
    XCTAssertFalse(sentence.localizedCaseInsensitiveContains("minutecast"))
  }

  func testLowPrecipOmitsChanceClause() {
    let day = DailyForecast(
      date: calendar.date(from: DateComponents(year: 2026, month: 8, day: 26))!,
      high: 90,
      low: 71,
      precipChance: 5,
      weatherCode: 1,
      symbolName: "sun.max.fill",
      uvMax: 7,
      rainSum: nil,
      showersSum: nil,
      snowfallSum: nil,
      sunrise: nil,
      sunset: nil
    )
    let sentence = DailyOutlook.sentence(
      day: day, unit: .fahrenheit, calendar: calendar, timeZone: chicago)
    XCTAssertFalse(sentence.contains("%"))
    XCTAssertTrue(sentence.contains("High 90°"))
  }
}
