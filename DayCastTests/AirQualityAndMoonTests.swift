import XCTest
@testable import DayCast

final class AirQualityAndMoonTests: XCTestCase {
  func testAirQualityCategories() {
    XCTAssertEqual(AirQualityCategory(usAQI: 22).title, "Good")
    XCTAssertEqual(AirQualityCategory(usAQI: 75).title, "Moderate")
    XCTAssertEqual(AirQualityCategory(usAQI: 120).title, "Unhealthy for Sensitive Groups")
    XCTAssertEqual(AirQualityCategory(usAQI: 175).title, "Unhealthy")
    XCTAssertEqual(AirQualityCategory(usAQI: 250).title, "Very Unhealthy")
    XCTAssertEqual(AirQualityCategory(usAQI: 350).title, "Hazardous")
  }

  func testAirQualityGuidanceIsNonEmpty() {
    for aqi in [10, 80, 130, 180, 220, 400] {
      XCTAssertFalse(AirQualityCategory(usAQI: aqi).guidance.isEmpty)
    }
  }

  func testMoonPhaseReturnsStableFullAroundHalfCycle() {
    // New moon reference + ~14.77 days ≈ full
    let reference = Date(timeIntervalSince1970: 947_182_440)
    let nearFull = reference.addingTimeInterval(14.77 * 86_400)
    let result = MoonPhase.phase(on: nearFull)
    XCTAssertEqual(result.phase, .full)
    XCTAssertGreaterThan(result.illumination, 0.9)
  }

  func testPrecipVisibilityHidesClear() {
    let clear = MinutecastSummary(
      kind: .clear, message: "No precip expected", icon: "sun.max.fill", strip: [])
    XCTAssertFalse(PrecipFeedVisibility.hasContent(summary: clear))
    XCTAssertNil(PrecipFeedVisibility.timingSentence(for: clear))

    let wet = MinutecastSummary(
      kind: .startsSoon, message: "Rain in about 30 min", icon: "cloud.rain.fill", strip: [])
    XCTAssertTrue(PrecipFeedVisibility.hasContent(summary: wet))
    XCTAssertEqual(PrecipFeedVisibility.timingSentence(for: wet), "Rain in about 30 min")
  }

  func testLocalWeatherBriefFindsDriestDaylightWindow() {
    let now = Date(timeIntervalSince1970: 1_767_268_800)  // 2026-01-01 12:00 UTC
    let hourly = [80, 70, 60, 15, 10, 20].enumerated().map { index, chance in
      HourlyForecast(
        time: now.addingTimeInterval(Double(index) * 3_600),
        temp: 72,
        precipChance: chance,
        weatherCode: 2,
        symbolName: "cloud.sun",
        rain: nil,
        showers: nil,
        snowfall: nil,
        isDay: true
      )
    }
    let weather = makeWeather(hourly: hourly)

    let brief = LocalWeatherBrief.make(
      weather: weather,
      unit: .fahrenheit,
      locationName: "Testville",
      activeAlerts: [],
      now: now
    )

    XCTAssertTrue(brief.hasPrefix("Forecast-only take:"))
    XCTAssertTrue(brief.contains("rain odds staying at 20% or lower"))
    XCTAssertTrue(brief.contains("Dress light and bring water."))
    XCTAssertTrue(brief.contains("Add sun protection."))
  }

  func testLocalWeatherBriefPrioritizesActiveAlerts() {
    let weather = makeWeather(hourly: [])

    let brief = LocalWeatherBrief.make(
      weather: weather,
      unit: .fahrenheit,
      locationName: "Testville",
      activeAlerts: ["Tornado Warning", "Flood Watch"]
    )

    XCTAssertTrue(brief.contains("Active alerts include Tornado Warning and Flood Watch"))
    XCTAssertTrue(brief.contains("follow local guidance"))
    XCTAssertFalse(brief.contains("driest outdoor window"))
  }

  private func makeWeather(hourly: [HourlyForecast]) -> DayCastWeather {
    DayCastWeather(
      location: SavedLocation(name: "Testville", latitude: 0, longitude: 0),
      currentTemp: 86,
      feelsLike: 90,
      conditionCode: 1,
      conditionText: "Mainly clear",
      humidity: 50,
      windSpeed: 8,
      uvIndex: 7,
      precipitationChance: 10,
      high: 90,
      low: 68,
      symbolName: "sun.max",
      fetchedAt: Date(),
      timezoneIdentifier: "UTC",
      airQualityIndex: nil,
      pm25: nil,
      pollenLevel: nil,
      hourly: hourly,
      daily: [],
      minutely15: []
    )
  }

  func testClearIconMeaningIsNotSFSymbolBrightnessName() {
    let condition = WeatherCondition.clear
    XCTAssertEqual(condition.symbolName(isDay: true), "sun.max.fill")
    XCTAssertEqual(condition.displayText, "Clear")
    XCTAssertFalse(condition.displayText.localizedCaseInsensitiveContains("Brightness"))
  }

  func testEveryConditionHasANonEmptyWeatherMeaning() {
    let codes = [0, 1, 3, 45, 51, 61, 66, 71, 77, 80, 85, 95, 999]
    for code in codes {
      let text = WeatherCondition(fromWMO: code).displayText
      XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
  }
}
