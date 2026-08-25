import XCTest

@testable import DayCast

final class WeatherDecisionTests: XCTestCase {

  func testHotAndHumidRecommendsWaterAndSun() {
    let weather = makeWeather(feelsLike: 94, humidity: 70, uvIndex: 7)
    let sentence = WeatherDecision.make(
      weather: weather, unit: .fahrenheit, alerts: []
    ).sentence
    XCTAssertTrue(sentence.hasPrefix("Hot and humid"))
    XCTAssertTrue(sentence.localizedCaseInsensitiveContains("water"))
    XCTAssertTrue(sentence.localizedCaseInsensitiveContains("sun"))
    XCTAssertEqual(GrokContentFilter.screen(sentence), .allowed)
  }

  func testWarningLeadsWithEventAndInstruction() {
    let weather = makeWeather(feelsLike: 70, humidity: 40, uvIndex: 3)
    let alert = NWSAlert(
      id: "tor",
      event: "Tornado Warning",
      severity: "Extreme",
      headline: "Tornado Warning issued for DeSoto County",
      description: nil,
      instruction: "Take shelter now in a basement or interior room.",
      expires: Date().addingTimeInterval(1800),
      areaDesc: "DeSoto",
      latitude: nil,
      longitude: nil
    )
    let sentence = WeatherDecision.make(
      weather: weather, unit: .fahrenheit, alerts: [alert, alert]
    ).sentence
    XCTAssertTrue(sentence.hasPrefix("Tornado Warning"))
    XCTAssertTrue(sentence.localizedCaseInsensitiveContains("shelter"))
    XCTAssertFalse(sentence.contains("Tornado Warning — Tornado Warning"))
  }

  func testRainSoonAddsALayer() {
    let weather = makeWeather(feelsLike: 72, humidity: 50, uvIndex: 4)
    let summary = MinutecastSummary(
      kind: .startsSoon,
      message: "Rain likely in ~30 min",
      icon: "cloud.rain.fill",
      strip: []
    )
    let sentence = WeatherDecision.make(
      weather: weather, unit: .fahrenheit, alerts: [], minutecast: summary
    ).sentence
    XCTAssertTrue(sentence.hasPrefix("Rain likely"))
    XCTAssertTrue(sentence.localizedCaseInsensitiveContains("rain layer"))
    XCTAssertTrue(sentence.localizedCaseInsensitiveContains("consider"))
  }

  func testUnhealthyAQILeadsBeforeComfort() {
    let weather = makeWeather(
      feelsLike: 72, humidity: 40, uvIndex: 3, aqi: 165, windSpeed: 6)
    let sentence = WeatherDecision.make(
      weather: weather, unit: .fahrenheit, alerts: []
    ).sentence
    XCTAssertTrue(sentence.localizedCaseInsensitiveContains("air quality"))
    XCTAssertTrue(sentence.localizedCaseInsensitiveContains("unhealthy"))
    XCTAssertTrue(sentence.localizedCaseInsensitiveContains("consider"))
  }

  func testHighUVUsesHedgedGuidance() {
    let weather = makeWeather(feelsLike: 70, humidity: 40, uvIndex: 9)
    let sentence = WeatherDecision.make(
      weather: weather, unit: .fahrenheit, alerts: []
    ).sentence
    XCTAssertTrue(sentence.localizedCaseInsensitiveContains("uv"))
    XCTAssertTrue(sentence.localizedCaseInsensitiveContains("consider"))
    XCTAssertFalse(sentence.localizedCaseInsensitiveContains("will burn"))
  }

  func testGustyWindIsCalledOutOnMildDays() {
    let weather = makeWeather(
      feelsLike: 68, humidity: 40, uvIndex: 3, windSpeed: 28)
    let sentence = WeatherDecision.make(
      weather: weather, unit: .fahrenheit, alerts: []
    ).sentence
    XCTAssertTrue(sentence.localizedCaseInsensitiveContains("gusty wind"))
  }

  func testMetricLightBreezeIsNotGusty() {
    let weather = makeWeather(
      feelsLike: 20, humidity: 40, uvIndex: 3, windSpeed: 12)
    let sentence = WeatherDecision.make(
      weather: weather, unit: .celsius, alerts: []
    ).sentence
    XCTAssertFalse(sentence.localizedCaseInsensitiveContains("gusty"))
  }

  func testMetricStrongWindIsGusty() {
    let weather = makeWeather(
      feelsLike: 20, humidity: 40, uvIndex: 3, windSpeed: 40)
    let sentence = WeatherDecision.make(
      weather: weather, unit: .celsius, alerts: []
    ).sentence
    XCTAssertTrue(sentence.localizedCaseInsensitiveContains("gusty wind"))
  }

  func testHighPollenIsHedgedWithoutCertainty() {
    let weather = makeWeather(
      feelsLike: 70, humidity: 40, uvIndex: 3, pollenLevel: "High")
    let sentence = WeatherDecision.make(
      weather: weather, unit: .fahrenheit, alerts: []
    ).sentence
    XCTAssertTrue(sentence.localizedCaseInsensitiveContains("pollen"))
    XCTAssertTrue(sentence.localizedCaseInsensitiveContains("may want"))
    XCTAssertFalse(sentence.localizedCaseInsensitiveContains("will"))
  }

  func testNoPollenStaysOnComfort() {
    let weather = makeWeather(feelsLike: 70, humidity: 40, uvIndex: 3)
    let sentence = WeatherDecision.make(
      weather: weather, unit: .fahrenheit, alerts: []
    ).sentence
    XCTAssertTrue(sentence.hasPrefix("Mild"))
    XCTAssertFalse(sentence.localizedCaseInsensitiveContains("pollen"))
  }

  func testLongNWSInstructionDoesNotFallBackToComfort() {
    let weather = makeWeather(feelsLike: 70, humidity: 40, uvIndex: 3)
    let instruction = String(
      repeating: "Take shelter now in a basement or an interior room away from windows ",
      count: 4
    )
    XCTAssertGreaterThan(instruction.count, WeatherDecision.maxCharacterCount)
    let alert = NWSAlert(
      id: "tor-long",
      event: "Tornado Warning",
      severity: "Extreme",
      headline: "Tornado Warning issued for DeSoto County",
      description: nil,
      instruction: instruction,
      expires: Date().addingTimeInterval(1800),
      areaDesc: "DeSoto",
      latitude: nil,
      longitude: nil
    )
    let sentence = WeatherDecision.make(
      weather: weather, unit: .fahrenheit, alerts: [alert]
    ).sentence
    XCTAssertTrue(sentence.hasPrefix("Tornado Warning"))
    XCTAssertFalse(sentence.localizedCaseInsensitiveContains("feels like"))
    XCTAssertFalse(sentence.hasPrefix("Mild"))
  }

  func testBenignConditionsStayHedged() {
    let weather = makeWeather(feelsLike: 70, humidity: 40, uvIndex: 3)
    let sentence = WeatherDecision.make(
      weather: weather, unit: .fahrenheit, alerts: []
    ).sentence
    XCTAssertTrue(sentence.hasPrefix("Mild"))
    XCTAssertTrue(sentence.localizedCaseInsensitiveContains("comfortable"))
    XCTAssertFalse(sentence.localizedCaseInsensitiveContains("will"))
  }

  private func makeWeather(
    feelsLike: Double,
    humidity: Int,
    uvIndex: Double,
    aqi: Int? = nil,
    windSpeed: Double = 6,
    pollenLevel: String? = nil
  ) -> DayCastWeather {
    DayCastWeather(
      location: SavedLocation(name: "Olive Branch", latitude: 34.96, longitude: -89.83),
      currentTemp: feelsLike - 2,
      feelsLike: feelsLike,
      conditionCode: 0,
      conditionText: "Clear",
      humidity: humidity,
      windSpeed: windSpeed,
      uvIndex: uvIndex,
      precipitationChance: 5,
      high: 96,
      low: 74,
      symbolName: "sun.max.fill",
      fetchedAt: Date(),
      timezoneIdentifier: "America/Chicago",
      airQualityIndex: aqi,
      pm25: nil,
      pollenLevel: pollenLevel,
      hourly: [
        HourlyForecast(
          time: Date(),
          temp: feelsLike - 2,
          precipChance: 5,
          weatherCode: 0,
          symbolName: "sun.max.fill",
          rain: nil,
          showers: nil,
          snowfall: nil,
          uvIndex: uvIndex
        )
      ],
      daily: [],
      minutely15: [],
      pollen: PollenConditions.from(
        grass: pollenLevel == "High" ? 80 : nil,
        birch: nil,
        alder: nil,
        ragweed: nil
      )
    )
  }
}
