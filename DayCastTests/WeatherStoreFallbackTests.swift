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

  func testFormatWindUsesUnitLabel() {
    XCTAssertEqual(TemperatureUnit.fahrenheit.formatWind(12.4), "12 mph")
    XCTAssertEqual(TemperatureUnit.celsius.formatWind(18.6), "19 km/h")
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
