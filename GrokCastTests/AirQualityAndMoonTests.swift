import XCTest
@testable import GrokCast

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
}
