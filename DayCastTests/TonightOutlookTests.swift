import XCTest

@testable import DayCast

final class TonightOutlookTests: XCTestCase {
  private var chicago: TimeZone {
    TimeZone(identifier: "America/Chicago")!
  }

  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = chicago
    return calendar
  }

  /// Monday 24 Aug 2026, 8:02 PM CDT — matches the first-viewport still.
  private var oliveBranchEvening: Date {
    calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 20, minute: 2))!
  }

  func testLateAfternoonAndAfterSunsetAreTonight() {
    let sunset = calendar.date(
      from: DateComponents(year: 2026, month: 8, day: 24, hour: 19, minute: 45))!
    let sunrise = calendar.date(
      from: DateComponents(year: 2026, month: 8, day: 24, hour: 6, minute: 24))!

    XCTAssertEqual(
      TonightOutlook.period(
        now: oliveBranchEvening, calendar: calendar, sunrise: sunrise, sunset: sunset),
      .tonight
    )
    XCTAssertEqual(
      TonightOutlook.period(
        now: calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 17))!,
        calendar: calendar,
        sunrise: sunrise,
        sunset: sunset
      ),
      .tonight
    )
    XCTAssertEqual(
      TonightOutlook.period(
        now: calendar.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 3))!,
        calendar: calendar,
        sunrise: sunrise.addingTimeInterval(86_400),
        sunset: sunset
      ),
      .tonight
    )
  }

  func testMorningAndAfternoonTitles() {
    let sunset = calendar.date(
      from: DateComponents(year: 2026, month: 8, day: 24, hour: 19, minute: 45))!
    let sunrise = calendar.date(
      from: DateComponents(year: 2026, month: 8, day: 24, hour: 6, minute: 24))!

    XCTAssertEqual(
      TonightOutlook.period(
        now: calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 9))!,
        calendar: calendar,
        sunrise: sunrise,
        sunset: sunset
      ),
      .thisMorning
    )
    XCTAssertEqual(
      TonightOutlook.period(
        now: calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 14))!,
        calendar: calendar,
        sunrise: sunrise,
        sunset: sunset
      ),
      .thisAfternoon
    )
  }

  func testOliveBranchEveningLineIsClearTonightAndTuesdayStormsWait() {
    let result = TonightOutlook.make(
      weather: oliveBranchWeather(),
      briefingItems: [megIsolatedTuesday],
      unit: .fahrenheit,
      now: oliveBranchEvening
    )
    XCTAssertEqual(result.title, "Tonight")
    XCTAssertEqual(result.period.outlookTitle, "Tonight's Outlook")
    XCTAssertEqual(
      result.sentence,
      "Clear tonight, cooling to 73°. Isolated storms wait until Tuesday morning."
    )
    XCTAssertFalse(result.sentence.localizedCaseInsensitiveContains("jacket"))
    XCTAssertFalse(result.sentence.localizedCaseInsensitiveContains("dress"))
    XCTAssertFalse(result.sentence.localizedCaseInsensitiveContains("tornado"))
    XCTAssertEqual(
      GrokContentFilter.screen(
        result.sentence, maxCharacterCount: TonightOutlook.maxCharacterCount),
      .allowed
    )
  }

  func testDoesNotInventTornadoesFromASurveyOrClearHours() {
    let result = TonightOutlook.make(
      weather: oliveBranchWeather(),
      briefingItems: [
        megItem("Tornado warning tonight."),
        megItem("The tornado damage survey NWS just posted."),
      ],
      unit: .fahrenheit,
      now: oliveBranchEvening
    )
    XCTAssertEqual(result.title, "Tonight")
    XCTAssertEqual(result.period.outlookTitle, "Tonight's Outlook")
    XCTAssertFalse(result.sentence.localizedCaseInsensitiveContains("tornado"))
    XCTAssertTrue(result.sentence.hasPrefix("Clear tonight"))
  }

  func testWetNowDoesNotSayQuietTonightWhenHourlyLooksDry() {
    let weather = oliveBranchWeather()
    let result = TonightOutlook.make(
      weather: weather,
      briefingItems: [],
      unit: .fahrenheit,
      now: oliveBranchEvening,
      isNowWet: true
    )
    XCTAssertFalse(result.sentence.localizedCaseInsensitiveContains("quiet"))
    XCTAssertFalse(result.sentence.localizedCaseInsensitiveContains("clear tonight"))
    XCTAssertTrue(result.sentence.lowercased().contains("rain"))
  }

  func testOfficialWarningDoesNotSayQuietTonight() {
    let result = TonightOutlook.make(
      weather: oliveBranchWeather(),
      briefingItems: [],
      unit: .fahrenheit,
      now: oliveBranchEvening,
      officialWarningEvent: "Flash Flood Warning"
    )
    XCTAssertFalse(result.sentence.localizedCaseInsensitiveContains("quiet"))
    XCTAssertFalse(result.sentence.localizedCaseInsensitiveContains("clear tonight"))
    XCTAssertTrue(result.sentence.contains("Flash Flood Warning"))
  }

  func testNextHourWetDoesNotSayQuietTonight() {
    let result = TonightOutlook.make(
      weather: oliveBranchWeather(),
      briefingItems: [],
      unit: .fahrenheit,
      now: oliveBranchEvening,
      isNextHourWet: true
    )
    XCTAssertFalse(result.sentence.localizedCaseInsensitiveContains("quiet"))
    XCTAssertFalse(result.sentence.localizedCaseInsensitiveContains("clear tonight"))
    XCTAssertTrue(result.sentence.lowercased().contains("rain"))
  }

  func testWetTonightLeadsWithRainNotTheLaterAFD() {
    let hours = oliveBranchHours(precipChance: 60, weatherCode: 61)
    let weather = oliveBranchWeather(hourly: hours)
    let result = TonightOutlook.make(
      weather: weather,
      briefingItems: [megIsolatedTuesday],
      unit: .fahrenheit,
      now: oliveBranchEvening
    )
    XCTAssertTrue(result.sentence.lowercased().contains("rain"))
    XCTAssertTrue(result.sentence.contains("60%"))
    XCTAssertFalse(result.sentence.localizedCaseInsensitiveContains("tornado"))
  }

  func testThisAfternoonStaysSunnyWithoutRepeatingTonight() {
    let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 14))!
    let hours = (14...18).map { hour -> HourlyForecast in
      let time = calendar.date(
        from: DateComponents(year: 2026, month: 8, day: 24, hour: hour))!
      return HourlyForecast(
        time: time,
        temp: hour == 14 ? 88 : 92,
        precipChance: 5,
        weatherCode: 0,
        symbolName: "sun.max.fill",
        rain: nil,
        showers: nil,
        snowfall: nil,
        isDay: true,
        feelsLike: hour == 14 ? 91 : 95
      )
    }
    let result = TonightOutlook.make(
      weather: oliveBranchWeather(hourly: hours),
      briefingItems: [],
      unit: .fahrenheit,
      now: now
    )
    XCTAssertEqual(result.title, "This afternoon")
    XCTAssertEqual(result.period.outlookTitle, "This Afternoon's Outlook")
    XCTAssertTrue(result.sentence.hasPrefix("Mostly sunny"))
    XCTAssertTrue(result.sentence.contains("88°"))
    XCTAssertTrue(result.sentence.contains("92°"))
    XCTAssertFalse(result.sentence.localizedCaseInsensitiveContains("tonight"))
    XCTAssertFalse(result.sentence.localizedCaseInsensitiveContains("jacket"))
  }

  func testHourlyGraphLabelsAreSparseNotPerHourStickers() {
    XCTAssertEqual(HourlyGraphLayout.labeledIndexes(count: 12), [0, 3, 6, 9])
    XCTAssertEqual(HourlyGraphLayout.labeledIndexes(count: 24).count, 8)
    XCTAssertEqual(
      HourlyGraphLayout.precipLabelIndexes(
        chances: [1, 1, 1, 40, 35, 20, 5],
        hasAmount: [false, false, false, true, false, false, false]
      ),
      [3]
    )
    XCTAssertEqual(
      HourlyGraphLayout.precipLabelIndexes(
        chances: [1, 1, 1, 1],
        hasAmount: [false, false, false, false]
      ),
      []
    )
  }

  func testSunsetTickSitsBetweenHourCenters() {
    let eight = calendar.date(
      from: DateComponents(year: 2026, month: 8, day: 24, hour: 20))!
    let nine = eight.addingTimeInterval(3600)
    let sunset = eight.addingTimeInterval(1800)
    let hours = [
      HourlyForecast(
        time: eight, temp: 85, precipChance: 1, weatherCode: 0, symbolName: "moon.stars.fill",
        rain: nil, showers: nil, snowfall: nil, isDay: false),
      HourlyForecast(
        time: nine, temp: 82, precipChance: 1, weatherCode: 0, symbolName: "moon.stars.fill",
        rain: nil, showers: nil, snowfall: nil, isDay: false),
    ]
    let x = HourlyGraphLayout.xOffset(for: sunset, hours: hours)
    XCTAssertEqual(x, HourlyGraphLayout.columnWidth)
  }

  func testFeelsSeriesIsOffWhenHourlyHasNoApparentTemp() {
    let hours = oliveBranchHours(precipChance: 1, weatherCode: 0, feelsLike: nil)
    XCTAssertEqual(HourlyGraphSeries.available(in: hours), [.temp, .precip])
  }

  func testFeelsSeriesShowsWhenApparentTempIsPresent() {
    let hours = oliveBranchHours(precipChance: 1, weatherCode: 0, feelsLike: 88)
    XCTAssertEqual(HourlyGraphSeries.available(in: hours), [.temp, .feels, .precip])
  }

  private var megIsolatedTuesday: LocalBriefingItem {
    megItem(
      "Isolated shower and thunderstorm chances will increase Tuesday morning for areas along and west of the Mississippi River."
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

  private func oliveBranchWeather(hourly: [HourlyForecast]? = nil) -> DayCastWeather {
    let sunset = calendar.date(
      from: DateComponents(year: 2026, month: 8, day: 24, hour: 19, minute: 45))!
    let sunrise = calendar.date(
      from: DateComponents(year: 2026, month: 8, day: 24, hour: 6, minute: 24))!
    let hours = hourly ?? oliveBranchHours(precipChance: 1, weatherCode: 0)
    return DayCastWeather(
      location: SavedLocation(
        name: "Olive Branch, MS", latitude: 34.9618, longitude: -89.8295),
      currentTemp: 85,
      feelsLike: 89,
      conditionCode: 0,
      conditionText: "Clear",
      humidity: 55,
      windSpeed: 5,
      uvIndex: 0,
      precipitationChance: 1,
      high: 92,
      low: 73,
      symbolName: "moon.stars.fill",
      fetchedAt: oliveBranchEvening,
      timezoneIdentifier: "America/Chicago",
      airQualityIndex: 62,
      pm25: nil,
      pollenLevel: nil,
      hourly: hours,
      daily: [
        DailyForecast(
          date: calendar.startOfDay(for: oliveBranchEvening),
          high: 92,
          low: 73,
          precipChance: 10,
          weatherCode: 0,
          symbolName: "sun.max.fill",
          uvMax: 8,
          rainSum: nil,
          showersSum: nil,
          snowfallSum: nil,
          sunrise: sunrise,
          sunset: sunset
        )
      ],
      minutely15: []
    )
  }

  private func oliveBranchHours(
    precipChance: Int,
    weatherCode: Int,
    feelsLike: Double? = 88
  ) -> [HourlyForecast] {
    let temps: [Double] = [85, 82, 81, 79, 77, 75, 74, 73, 73, 73, 74]
    let start = calendar.date(
      from: DateComponents(year: 2026, month: 8, day: 24, hour: 20))!
    return (0..<temps.count).map { index in
      let time = calendar.date(byAdding: .hour, value: index, to: start)!
      return HourlyForecast(
        time: time,
        temp: temps[index],
        precipChance: precipChance,
        weatherCode: weatherCode,
        symbolName: weatherCode == 0 ? "moon.stars.fill" : "cloud.rain.fill",
        rain: weatherCode == 61 ? 0.15 : nil,
        showers: nil,
        snowfall: nil,
        isDay: false,
        feelsLike: feelsLike
      )
    }
  }
}
