import XCTest

@testable import DayCast

final class DayCastScoreCalculatorTests: XCTestCase {

  // MARK: - Helpers

  private static let location = SavedLocation(
    name: "Test City", latitude: 35.0, longitude: -90.0)

  private func makeWeather(
    feelsLike: Double = 70,
    windSpeed: Double = 5,
    uvIndex: Double = 3,
    precipitationChance: Int = 5,
    airQualityIndex: Int? = nil
  ) -> DayCastWeather {
    DayCastWeather(
      location: Self.location,
      currentTemp: feelsLike,
      feelsLike: feelsLike,
      conditionCode: 0,
      conditionText: "Clear",
      humidity: 50,
      windSpeed: windSpeed,
      uvIndex: uvIndex,
      precipitationChance: precipitationChance,
      high: feelsLike + 5,
      low: feelsLike - 5,
      symbolName: "sun.max.fill",
      fetchedAt: Date(),
      timezoneIdentifier: "America/Chicago",
      airQualityIndex: airQualityIndex,
      pm25: nil,
      pollenLevel: nil,
      hourly: [],
      daily: [],
      minutely15: []
    )
  }

  private func makeAlert(severity: String, event: String = "Severe Thunderstorm Warning") -> NWSAlert {
    NWSAlert(
      id: UUID().uuidString,
      event: event,
      severity: severity,
      headline: nil,
      description: nil,
      instruction: nil,
      expires: Date(timeIntervalSinceNow: 3600),
      areaDesc: nil,
      latitude: nil,
      longitude: nil
    )
  }

  // MARK: - Label thresholds

  func testPerfectWeatherScoresGoOutside() {
    // 72 base + 14 (ideal temp 62-78°F) + 10 (precip <15%) = 96 → "Go Outside"
    let score = DayCastScoreCalculator.score(for: makeWeather(), alerts: [])
    XCTAssertGreaterThanOrEqual(score.value, 80)
    XCTAssertEqual(score.label, "Go Outside")
    XCTAssertEqual(score.icon, "figure.walk")
  }

  func testPrettyGoodRangeLabel() {
    // 72 base + 6 (temp 50-85, not ideal) + 10 (low precip) - 16 (wind >25) = 72 → "Pretty Good"
    let score = DayCastScoreCalculator.score(
      for: makeWeather(feelsLike: 55, windSpeed: 30), alerts: [])
    XCTAssertGreaterThanOrEqual(score.value, 60)
    XCTAssertLessThan(score.value, 80)
    XCTAssertEqual(score.label, "Pretty Good")
    XCTAssertEqual(score.icon, "sun.max.fill")
  }

  func testStayCozyLabelUnderFortyPoints() {
    // 72 - 22 (extreme cold <32°F) - 26 (heavy rain >60%) - 16 (high wind >25mph) = 8 → "Stay Cozy"
    let score = DayCastScoreCalculator.score(
      for: makeWeather(feelsLike: 15, windSpeed: 30, precipitationChance: 80), alerts: [])
    XCTAssertLessThan(score.value, 40)
    XCTAssertEqual(score.label, "Stay Cozy")
    XCTAssertEqual(score.icon, "house.fill")
  }

  // MARK: - Score is always clamped

  func testScoreNeverExceedsOneHundred() {
    let score = DayCastScoreCalculator.score(for: makeWeather(), alerts: [])
    XCTAssertLessThanOrEqual(score.value, 100)
  }

  func testScoreNeverGoesNegative() {
    // Pile on every penalty: extreme cold, gale-force wind, certainty of rain, bad AQI.
    let score = DayCastScoreCalculator.score(
      for: makeWeather(
        feelsLike: -20,
        windSpeed: 60,
        uvIndex: 10,
        precipitationChance: 100,
        airQualityIndex: 200
      ),
      alerts: [
        makeAlert(severity: "Extreme"),
        makeAlert(severity: "Extreme"),
        makeAlert(severity: "Extreme"),
      ]
    )
    XCTAssertGreaterThanOrEqual(score.value, 0)
  }

  // MARK: - Temperature branch (Fahrenheit)

  func testIdealTemperatureAddsPoints() {
    let ideal = DayCastScoreCalculator.score(for: makeWeather(feelsLike: 70), alerts: [])
    let uncomfortable = DayCastScoreCalculator.score(for: makeWeather(feelsLike: 90), alerts: [])
    XCTAssertGreaterThan(ideal.value, uncomfortable.value)
  }

  func testExtremeHeatPenalizesMoreThanMildWarmth() {
    let hot = DayCastScoreCalculator.score(for: makeWeather(feelsLike: 100), alerts: [])
    let warm = DayCastScoreCalculator.score(for: makeWeather(feelsLike: 88), alerts: [])
    XCTAssertLessThan(hot.value, warm.value)
  }

  func testExtremeColdPenalizesMoreThanMildCold() {
    let freezing = DayCastScoreCalculator.score(for: makeWeather(feelsLike: 20), alerts: [])
    let chilly = DayCastScoreCalculator.score(for: makeWeather(feelsLike: 45), alerts: [])
    XCTAssertLessThan(freezing.value, chilly.value)
  }

  // MARK: - Precipitation

  func testHighPrecipChancePenalizesScore() {
    let dry = DayCastScoreCalculator.score(for: makeWeather(precipitationChance: 5), alerts: [])
    let rainy = DayCastScoreCalculator.score(for: makeWeather(precipitationChance: 80), alerts: [])
    XCTAssertGreaterThan(dry.value, rainy.value)
  }

  // MARK: - Wind

  func testHighWindPenalizesScore() {
    let calm = DayCastScoreCalculator.score(for: makeWeather(windSpeed: 5), alerts: [])
    let gusty = DayCastScoreCalculator.score(for: makeWeather(windSpeed: 30), alerts: [])
    XCTAssertGreaterThan(calm.value, gusty.value)
  }

  // MARK: - AQI

  func testBadAQIPenalizesScore() {
    let clean = DayCastScoreCalculator.score(for: makeWeather(airQualityIndex: 30), alerts: [])
    let unhealthy = DayCastScoreCalculator.score(for: makeWeather(airQualityIndex: 160), alerts: [])
    XCTAssertGreaterThan(clean.value, unhealthy.value)
  }

  // MARK: - Alerts

  func testActiveAlertsPenalizeScore() {
    let noAlerts = DayCastScoreCalculator.score(for: makeWeather(), alerts: [])
    let withAlert = DayCastScoreCalculator.score(
      for: makeWeather(), alerts: [makeAlert(severity: "Severe")])
    XCTAssertGreaterThan(noAlerts.value, withAlert.value)
  }

  func testExpiredAlertsDoNotPenalizeScore() {
    let expiredAlert = NWSAlert(
      id: "expired",
      event: "Severe Thunderstorm Warning",
      severity: "Severe",
      headline: nil,
      description: nil,
      instruction: nil,
      expires: Date(timeIntervalSinceNow: -3600),
      areaDesc: nil,
      latitude: nil,
      longitude: nil
    )
    let noAlerts = DayCastScoreCalculator.score(for: makeWeather(), alerts: [])
    let withExpired = DayCastScoreCalculator.score(for: makeWeather(), alerts: [expiredAlert])
    XCTAssertEqual(noAlerts.value, withExpired.value)
  }

  // MARK: - accentTier

  func testAccentTierGreatAtOrAbove75() {
    let score = DayCastScore(value: 75, label: "", subtitle: "", icon: "")
    XCTAssertEqual(score.accentTier, .great)
  }

  func testAccentTierOkayBetween50And74() {
    let score = DayCastScore(value: 60, label: "", subtitle: "", icon: "")
    XCTAssertEqual(score.accentTier, .okay)
  }

  func testAccentTierPoorBelow50() {
    let score = DayCastScore(value: 49, label: "", subtitle: "", icon: "")
    XCTAssertEqual(score.accentTier, .poor)
  }
}
