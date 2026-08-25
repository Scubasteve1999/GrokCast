import XCTest

@testable import DayCast

final class HourlyGraphTests: XCTestCase {
  private var chicago: TimeZone {
    TimeZone(identifier: "America/Chicago")!
  }

  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = chicago
    return calendar
  }

  private var start: Date {
    calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 20))!
  }

  func testCompactHeightIsUnchangedForTheGlanceBudget() {
    XCTAssertEqual(HourlyGraphLayout.height, 74)
    XCTAssertEqual(HourlyGraphLayout.height, HourlyGraphMetrics.compact.plotStackHeight)
    XCTAssertEqual(HourlyGraphLayout.height(for: .compact), HourlyGraphLayout.height)
    XCTAssertEqual(TodayGlanceLayout.hourlyGraphHeight, HourlyGraphLayout.height)
    XCTAssertLessThanOrEqual(TodayGlanceLayout.hourlyCardHeight, 168)
    XCTAssertEqual(HourlyGraphHours.compactLimit, 24)
  }

  func testFullLayoutIsTallerAndFortyEightHours() {
    XCTAssertEqual(HourlyGraphHours.fullLimit, 48)
    XCTAssertEqual(HourlyGraphLayout.height(for: .full), HourlyGraphMetrics.full.height)
    XCTAssertEqual(HourlyGraphMetrics.full.height, 186)
    XCTAssertGreaterThan(HourlyGraphLayout.height(for: .full), 170)
    XCTAssertLessThan(HourlyGraphLayout.height(for: .full), 200)
    XCTAssertGreaterThan(
      HourlyGraphLayout.height(for: .full), HourlyGraphLayout.height(for: .compact))
    XCTAssertEqual(HourlyGraphMetrics.full.precipBarHeight, 36)
  }

  func testUpcomingHonorsTheFortyEightHourLimit() {
    let weather = weather(hourCount: 60, from: Date())
    XCTAssertEqual(HourlyGraphHours.upcoming(from: weather).count, 24)
    XCTAssertEqual(
      HourlyGraphHours.upcoming(from: weather, limit: HourlyGraphHours.fullLimit).count, 48)
  }

  func testValueBoundsPadASixDegreeNightByFifteenPercent() {
    let values = [72.0, 73, 74, 75, 76, 77, 78]
    let bounds = HourlyGraphLayout.valueBounds(values: values, series: .temp)
    XCTAssertEqual(bounds.min, 71.1, accuracy: 0.001)
    XCTAssertEqual(bounds.max, 78.9, accuracy: 0.001)
    let span = bounds.max - bounds.min
    XCTAssertEqual(span, 7.8, accuracy: 0.001)
    let usable = 6.0 / span
    XCTAssertGreaterThan(usable, 0.75)
    XCTAssertLessThan(usable, 0.8)
  }

  func testPrecipBoundsStayZeroToOneHundred() {
    let bounds = HourlyGraphLayout.valueBounds(
      values: [1, 40, 90], series: .precip)
    XCTAssertEqual(bounds.min, 0)
    XCTAssertEqual(bounds.max, 100)
  }

  func testMidnightIndexesMarkTheDayDivider() {
    let hours = hours(from: start, count: 12)
    let midnights = HourlyGraphLayout.midnightIndexes(hours: hours, calendar: calendar)
    XCTAssertEqual(midnights, [4])
    XCTAssertEqual(calendar.component(.hour, from: hours[4].time), 0)
    XCTAssertEqual(calendar.component(.weekday, from: hours[4].time), 3)
  }

  func testScrubOffsetMapsToHourIndex() {
    XCTAssertEqual(HourlyGraphLayout.selectedIndex(offset: 0, hourCount: 48), 0)
    XCTAssertEqual(
      HourlyGraphLayout.selectedIndex(offset: HourlyGraphLayout.columnWidth, hourCount: 48), 1)
    XCTAssertEqual(
      HourlyGraphLayout.selectedIndex(
        offset: HourlyGraphLayout.columnWidth * 10, hourCount: 48), 10)
    XCTAssertEqual(HourlyGraphLayout.selectedIndex(offset: 0, hourCount: 0), 0)
    XCTAssertEqual(
      HourlyGraphLayout.selectedIndex(offset: 10_000, hourCount: 48), 47)
  }

  func testReadoutAndScrubVoiceOverStayOnTheSelectedHour() {
    let now = hour(at: start, temp: 82, precipChance: 1)
    let later = hour(
      at: start.addingTimeInterval(5 * 3600), temp: 73, precipChance: 40, rain: 0.2)
    XCTAssertEqual(
      HourlyGraphLayout.readoutText(
        hour: now, index: 0, series: .temp, timeZone: chicago),
      "Now  ·  82°  ·  1%")
    let laterText = HourlyGraphLayout.readoutText(
      hour: later, index: 5, series: .temp, timeZone: chicago)
    XCTAssertTrue(laterText.hasPrefix("Tue"), laterText)
    XCTAssertTrue(laterText.contains("73°"), laterText)
    XCTAssertTrue(laterText.contains("0.2\""), laterText)

    let label = HourlyGraphLayout.accessibilityLabel(
      hour: now, index: 0, hourCount: 48, series: .temp, timeZone: chicago)
    XCTAssertTrue(label.contains("Now"))
    XCTAssertTrue(label.contains("82 degrees"))
    XCTAssertTrue(label.contains("48-hour forecast"))
    XCTAssertFalse(label.contains("Opens full forecast"))
  }

  func testSunEventsIncludeTheSecondSunriseInAFortyEightHourWindow() {
    let hours = hours(from: start, count: 48)
    let firstSunset = calendar.date(
      from: DateComponents(year: 2026, month: 8, day: 24, hour: 19, minute: 45))!
    let firstSunrise = calendar.date(
      from: DateComponents(year: 2026, month: 8, day: 25, hour: 6, minute: 24))!
    let secondSunset = calendar.date(
      from: DateComponents(year: 2026, month: 8, day: 25, hour: 19, minute: 44))!
    let days = [
      DailyForecast(
        date: calendar.startOfDay(for: start),
        high: 92, low: 73, precipChance: 10, weatherCode: 0, symbolName: "sun.max.fill",
        uvMax: 8, rainSum: nil, showersSum: nil, snowfallSum: nil,
        sunrise: calendar.date(
          from: DateComponents(year: 2026, month: 8, day: 24, hour: 6, minute: 24)),
        sunset: firstSunset),
      DailyForecast(
        date: calendar.startOfDay(for: start.addingTimeInterval(86_400)),
        high: 94, low: 74, precipChance: 20, weatherCode: 0, symbolName: "sun.max.fill",
        uvMax: 8, rainSum: nil, showersSum: nil, snowfallSum: nil,
        sunrise: firstSunrise, sunset: secondSunset),
    ]
    let events = HourlyGraphSunEvent.inWindow(days: days, hours: hours)
    XCTAssertEqual(events.map(\.title), ["Sunrise", "Sunset"])
    XCTAssertEqual(events.map(\.date), [firstSunrise, secondSunset])
  }

  private func weather(hourCount: Int, from start: Date? = nil) -> DayCastWeather {
    let origin = start ?? self.start
    return DayCastWeather(
      location: SavedLocation(
        name: "Olive Branch, MS", latitude: 34.9618, longitude: -89.8295),
      currentTemp: 82,
      feelsLike: 86,
      conditionCode: 0,
      conditionText: "Clear",
      humidity: 55,
      windSpeed: 5,
      uvIndex: 0,
      precipitationChance: 1,
      high: 92,
      low: 73,
      symbolName: "moon.stars.fill",
      fetchedAt: origin,
      timezoneIdentifier: "America/Chicago",
      airQualityIndex: 45,
      pm25: nil,
      pollenLevel: nil,
      hourly: hours(from: origin, count: hourCount),
      daily: [],
      minutely15: []
    )
  }

  private func hours(from start: Date, count: Int) -> [HourlyForecast] {
    (0..<count).map { index in
      hour(at: start.addingTimeInterval(TimeInterval(index * 3600)), temp: 80 - Double(index % 8))
    }
  }

  private func hour(
    at time: Date, temp: Double, precipChance: Int = 1, rain: Double? = nil
  ) -> HourlyForecast {
    HourlyForecast(
      time: time,
      temp: temp,
      precipChance: precipChance,
      weatherCode: 0,
      symbolName: "moon.stars.fill",
      rain: rain,
      showers: nil,
      snowfall: nil,
      isDay: false,
      feelsLike: temp + 2
    )
  }
}
