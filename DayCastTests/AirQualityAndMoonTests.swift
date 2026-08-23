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

    XCTAssertFalse(brief.localizedCaseInsensitiveContains("Forecast-only take"))
    XCTAssertTrue(brief.hasPrefix("Testville is"))
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

  func testDailyRowVoiceOverIsOneControlWithWeatherMeaning() {
    let label = DailyRow.accessibilityLabel(
      day: "Today",
      condition: WeatherCondition.mainlyClear.displayText,
      high: 96,
      low: 76,
      precipChance: 26
    )
    XCTAssertTrue(label.contains("Today"))
    XCTAssertTrue(label.contains("Mainly Clear"))
    XCTAssertTrue(label.contains("High 96 degrees"))
    XCTAssertTrue(label.contains("low 76 degrees"))
    XCTAssertTrue(label.contains("26 percent"))
    XCTAssertFalse(label.localizedCaseInsensitiveContains("Brightness"))
  }

  func testDailyRowVoiceOverOmitsZeroPrecip() {
    let label = DailyRow.accessibilityLabel(
      day: "Tue",
      condition: "Overcast",
      high: 81,
      low: 57,
      precipChance: 0
    )
    XCTAssertEqual(label, "Tue, Overcast. High 81 degrees, low 57 degrees")
    XCTAssertFalse(label.contains("percent"))
  }

  func testFireFeedCardVoiceOverIsOneLabeledControl() {
    let label = FireFeedCard.accessibilityLabel(
      title: "Active fire nearby",
      subtitle: "2 mi away · 3 nearby"
    )
    XCTAssertEqual(label, "Fire. Active fire nearby. 2 mi away · 3 nearby Opens details.")
  }

  func testAirQualityFeedCardVoiceOverIsOneLabeledControl() {
    let category = AirQualityCategory(usAQI: 42)
    let label = AirQualityFeedCard.accessibilityLabel(
      aqi: 42,
      title: category.title,
      guidance: category.guidance
    )
    XCTAssertTrue(label.hasPrefix("Air quality 42, \(category.title)."))
    XCTAssertTrue(label.contains(category.guidance))
    XCTAssertTrue(label.hasSuffix("Opens details."))
  }

  func testSettingsUnitsRowVoiceOverHasAName() {
    XCTAssertEqual(
      TemperatureUnit.fahrenheit.settingsRowAccessibilityLabel,
      "Temperature, Fahrenheit (°F)"
    )
    XCTAssertEqual(
      TemperatureUnit.celsius.settingsRowAccessibilityLabel,
      "Temperature, Celsius (°C)"
    )
  }

  func testHourlyFeedCardVoiceOverIsOneLabeledControl() {
    let label = HourlyFeedCard.accessibilityLabel(
      hourLabel: "Now",
      temp: 66,
      precipChance: 0
    )
    XCTAssertEqual(
      label,
      "Hourly forecast. Now 66 degrees, 0 percent chance of precipitation. Opens full forecast."
    )
  }

  func testRadarFeedCardVoiceOverIsOneLabeledControl() {
    XCTAssertEqual(
      RadarFeedCard.accessibilityLabel(conditionCode: 61),
      "Rain now. National radar. Opens the Radar tab."
    )
    XCTAssertEqual(
      RadarFeedCard.accessibilityLabel(conditionCode: 0),
      "Local is clear. National radar. Opens the Radar tab."
    )
  }

  func testSunMoonFeedCardVoiceOverIsOneLabeledControl() {
    let label = SunMoonFeedCard.accessibilityLabel(
      sunrise: "6:08 AM",
      sunset: "8:18 PM",
      phase: "Waxing Crescent",
      litPercent: 25
    )
    XCTAssertEqual(
      label,
      "Sun and moon. Sunrise 6:08 AM, sunset 8:18 PM. Waxing Crescent, 25 percent illuminated. Opens details."
    )
  }

  func testSettingsBriefTimeRowVoiceOverHasAName() {
    XCTAssertEqual(SettingsView.briefTimeAccessibilityLabel(hour: 7), "Brief time, 7:00 AM")
    XCTAssertEqual(SettingsView.briefTimeAccessibilityLabel(hour: 11), "Brief time, 11:00 AM")
  }
}
