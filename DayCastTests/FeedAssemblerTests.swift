import XCTest
@testable import DayCast

final class FeedAssemblerTests: XCTestCase {
  func testDefaultOrderPreservedForFullSnapshot() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 2,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: true,
      hasAQI: true,
      hasSunriseOrSunset: true,
      showFireCard: true,
      showAIInsight: true
    )
    XCTAssertEqual(FeedAssembler.items(from: snapshot), FeedItem.defaultOrder)
  }

  func testHidesCardsWithoutMeaningfulData() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: true,
      hasDaily: false,
      hasPrecipContent: false,
      hasAQI: false,
      hasSunriseOrSunset: false,
      showFireCard: false,
      showAIInsight: true
    )
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [.now, .aiInsight, .hourly, .radar]
    )
  }

  func testEmptyWeatherHidesEverything() {
    XCTAssertTrue(FeedAssembler.items(from: .empty).isEmpty)
  }

  func testAlertsAppearOnlyWhenPresent() {
    var snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: false,
      hasDaily: false,
      hasPrecipContent: false,
      hasAQI: false,
      hasSunriseOrSunset: false,
      showFireCard: false,
      showAIInsight: false
    )
    XCTAssertFalse(FeedAssembler.items(from: snapshot).contains(.alerts))
    snapshot.alertCount = 1
    XCTAssertEqual(FeedAssembler.items(from: snapshot), [.now, .alerts, .radar])
  }

  func testFireCardIndependentOfWeatherExtras() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: false,
      hasDaily: false,
      hasPrecipContent: false,
      hasAQI: false,
      hasSunriseOrSunset: false,
      showFireCard: true,
      showAIInsight: false
    )
    XCTAssertEqual(FeedAssembler.items(from: snapshot), [.now, .radar, .fire])
  }

  func testAQIAndSunMoonAppearWhenFlagged() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: false,
      hasDaily: false,
      hasPrecipContent: false,
      hasAQI: true,
      hasSunriseOrSunset: true,
      showFireCard: false,
      showAIInsight: false
    )
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [.now, .radar, .airQuality, .sunMoon]
    )
  }

  func testPrecipHiddenWhenNoContent() {
    var snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: false,
      hasDaily: false,
      hasPrecipContent: false,
      hasAQI: false,
      hasSunriseOrSunset: false,
      showFireCard: false,
      showAIInsight: false
    )
    XCTAssertFalse(FeedAssembler.items(from: snapshot).contains(.precip))
    snapshot.hasPrecipContent = true
    XCTAssertTrue(FeedAssembler.items(from: snapshot).contains(.precip))
  }
}

