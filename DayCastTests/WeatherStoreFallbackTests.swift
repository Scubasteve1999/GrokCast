import XCTest

@testable import DayCast

final class WeatherStoreFallbackTests: XCTestCase {
  private let olive = SavedLocation.oliveBranch
  private let seattle = SavedLocation(
    name: "Seattle, WA", latitude: 47.6062, longitude: -122.3321)

  func testKeepsLastGoodWhenItBelongsToThisLocation() {
    let weather = makeWeather(location: olive)
    let kept = WeatherStore.lastGoodOpenMeteo(weather, for: olive)
    XCTAssertEqual(kept?.location.id, olive.id)
    XCTAssertEqual(kept?.currentTemp, weather.currentTemp)
  }

  func testDoesNotReuseAnotherCityAsLastGood() {
    let weather = makeWeather(location: olive)
    XCTAssertNil(WeatherStore.lastGoodOpenMeteo(weather, for: seattle))
  }

  func testNilWeatherIsNotLastGood() {
    XCTAssertNil(WeatherStore.lastGoodOpenMeteo(nil, for: olive))
  }

  func testDisplayedWeatherHidesOtherCityNumbers() {
    let weather = makeWeather(location: olive)
    XCTAssertNil(WeatherStore.weatherMatchingSelection(weather, location: seattle))
    XCTAssertEqual(
      WeatherStore.weatherMatchingSelection(weather, location: olive)?.currentTemp, 72)
    XCTAssertEqual(
      WeatherStore.weatherMatchingSelection(weather, location: nil)?.location.id, olive.id)
    XCTAssertNil(WeatherStore.weatherMatchingSelection(nil, location: olive))
  }

  func testFormatWindUsesUnitLabel() {
    XCTAssertEqual(TemperatureUnit.fahrenheit.formatWind(12.4), "12 mph")
    XCTAssertEqual(TemperatureUnit.celsius.formatWind(18.6), "19 km/h")
  }

  func testFormatFromFahrenheitConvertsInCelsius() {
    XCTAssertEqual(TemperatureUnit.fahrenheit.formatFromFahrenheit(68), "68°F")
    XCTAssertEqual(TemperatureUnit.celsius.formatFromFahrenheit(68), "20°C")
  }

  func testFormatWindFromMphConvertsInCelsius() {
    XCTAssertEqual(TemperatureUnit.fahrenheit.formatWindFromMph(10), "10 mph")
    XCTAssertEqual(TemperatureUnit.celsius.formatWindFromMph(10), "16 km/h")
  }

  func testOWMPlaceholderKeyIsNotConfigured() {
    XCTAssertFalse(OpenWeatherMapRadarService.isUsableAPIKey(""))
    XCTAssertFalse(OpenWeatherMapRadarService.isUsableAPIKey("YOUR_OPENWEATHERMAP_API_KEY"))
    XCTAssertFalse(OpenWeatherMapRadarService.isUsableAPIKey("  YOUR_KEY  "))
    XCTAssertTrue(OpenWeatherMapRadarService.isUsableAPIKey("abc123realkey"))
  }

  func testNearestHourPrefersCurrentHourNotMidnight() {
    let midnight = Date(timeIntervalSince1970: 1_767_225_600)  // 2026-01-01 00:00 UTC
    let times: [Date?] = [
      midnight,
      midnight.addingTimeInterval(12 * 3600),
      midnight.addingTimeInterval(13 * 3600),
    ]
    let noon = midnight.addingTimeInterval(12 * 3600 + 10 * 60)
    XCTAssertEqual(OpenMeteoHourIndex.nearest(in: times, to: noon), 1)
  }

  private func makeWeather(location: SavedLocation) -> DayCastWeather {
    DayCastWeather(
      location: location,
      currentTemp: 72,
      feelsLike: 70,
      conditionCode: 0,
      conditionText: "Clear",
      humidity: 40,
      windSpeed: 8,
      uvIndex: 4,
      precipitationChance: 5,
      high: 78,
      low: 61,
      symbolName: "sun.max.fill",
      fetchedAt: Date(),
      timezoneIdentifier: "America/Chicago",
      airQualityIndex: nil,
      pm25: nil,
      pollenLevel: nil,
      hourly: [],
      daily: [],
      minutely15: []
    )
  }
}
