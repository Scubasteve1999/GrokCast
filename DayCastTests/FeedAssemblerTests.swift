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
    XCTAssertTrue(FeedAssembler.isRadarStory(snapshot))
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [
        .now, .alerts, .precip, .radar, .hourly, .daily, .aiInsight, .nearby,
      ]
    )
  }

  func testDryCityKeepsRadarBuriedBelowDaily() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: false,
      hasAQI: true,
      hasSunriseOrSunset: true,
      showFireCard: true,
      showAIInsight: true,
      isNowWet: false
    )
    XCTAssertFalse(FeedAssembler.isRadarStory(snapshot))
    let items = FeedAssembler.items(from: snapshot)
    XCTAssertEqual(
      items,
      [.now, .hourly, .daily, .aiInsight, .radar, .nearby]
    )
    XCTAssertLessThan(items.firstIndex(of: .daily)!, items.firstIndex(of: .radar)!)
    XCTAssertGreaterThan(items.firstIndex(of: .radar)!, items.firstIndex(of: .hourly)!)
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
      [.now, .hourly, .aiInsight, .radar]
    )
  }

  func testStormSnapshotFirstFiveAreGlanceCards() {
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
    let items = FeedAssembler.items(from: snapshot)
    XCTAssertEqual(
      Array(items.prefix(5)),
      [.now, .alerts, .precip, .radar, .hourly]
    )
    XCTAssertLessThan(items.firstIndex(of: .radar)!, items.firstIndex(of: .hourly)!)
    XCTAssertLessThan(items.firstIndex(of: .radar)!, items.firstIndex(of: .daily)!)
    XCTAssertLessThan(items.firstIndex(of: .daily)!, items.firstIndex(of: .aiInsight)!)
  }

  func testWetNowHoistsRadarBeforeHourlyWithoutAlerts() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: false,
      hasAQI: false,
      hasSunriseOrSunset: false,
      showFireCard: false,
      showAIInsight: false,
      isNowWet: true
    )
    XCTAssertTrue(FeedAssembler.isRadarStory(snapshot))
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [.now, .radar, .hourly, .daily]
    )
  }

  func testWarnedDryPointHoistsRadarAfterAlerts() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 1,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: false,
      hasAQI: false,
      hasSunriseOrSunset: false,
      showFireCard: false,
      showAIInsight: false,
      isNowWet: false
    )
    XCTAssertTrue(FeedAssembler.isRadarStory(snapshot))
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [.now, .alerts, .radar, .hourly, .daily]
    )
  }

  func testNextHourOnlyHoistsRadarBeforeHourly() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: true,
      hasAQI: false,
      hasSunriseOrSunset: false,
      showFireCard: false,
      showAIInsight: false,
      isNowWet: false
    )
    XCTAssertTrue(FeedAssembler.isRadarStory(snapshot))
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [.now, .precip, .radar, .hourly, .daily]
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

  func testAlertsSlotShowsForSevereContextWithoutNWSAlerts() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: true,
      hasAQI: false,
      hasSunriseOrSunset: false,
      showFireCard: false,
      showAIInsight: false,
      hasSevereContext: true
    )
    XCTAssertTrue(snapshot.showAlertsSlot)
    let items = FeedAssembler.items(from: snapshot)
    XCTAssertEqual(items.first, .now)
    XCTAssertEqual(items.dropFirst().first, .alerts)
    XCTAssertEqual(Array(items.prefix(4)), [.now, .alerts, .precip, .radar])
  }

  func testBuilderSevereContextEarnsAlertsSlotWithZeroNWS() {
    let weather = DayCastWeather(
      location: SavedLocation(name: "Tampa", latitude: 27.95, longitude: -82.46),
      currentTemp: 75,
      feelsLike: 76,
      conditionCode: 61,
      conditionText: "Rain",
      humidity: 80,
      windSpeed: 8,
      uvIndex: 2,
      precipitationChance: 70,
      high: 82,
      low: 70,
      symbolName: "cloud.rain.fill",
      fetchedAt: Date(),
      timezoneIdentifier: "America/New_York",
      airQualityIndex: nil,
      pm25: nil,
      pollenLevel: nil,
      hourly: [],
      daily: [],
      minutely15: []
    )
    let snapshot = FeedSnapshotBuilder.make(
      weather: weather,
      alerts: [],
      hasSevereContext: true
    )
    XCTAssertEqual(snapshot.alertCount, 0)
    XCTAssertTrue(snapshot.hasSevereContext)
    XCTAssertTrue(snapshot.showAlertsSlot)
    let items = FeedAssembler.items(from: snapshot)
    XCTAssertEqual(items.first, .now)
    XCTAssertEqual(items.dropFirst().first, .alerts)
    XCTAssertTrue(snapshot.isNowWet)
  }

  func testBuilderMarksDryNow() {
    let weather = DayCastWeather(
      location: SavedLocation(name: "Olive Branch", latitude: 34.96, longitude: -89.83),
      currentTemp: 82,
      feelsLike: 83,
      conditionCode: 0,
      conditionText: "Clear",
      humidity: 40,
      windSpeed: 5,
      uvIndex: 7,
      precipitationChance: 0,
      high: 88,
      low: 68,
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
    let snapshot = FeedSnapshotBuilder.make(weather: weather, alerts: [])
    XCTAssertFalse(snapshot.isNowWet)
    XCTAssertFalse(FeedAssembler.isRadarStory(snapshot))
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
    XCTAssertEqual(FeedAssembler.items(from: snapshot), [.now, .radar, .nearby])
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
      [.now, .radar, .nearby]
    )
  }

  func testYourNewsSitsAfterHourlyWhenBriefingExists() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: false,
      hasAQI: false,
      hasSunriseOrSunset: false,
      showFireCard: false,
      showAIInsight: false,
      hasLocalBriefing: true
    )
    let items = FeedAssembler.items(from: snapshot)
    XCTAssertEqual(items, [.now, .hourly, .yourNews, .daily, .radar])
    XCTAssertEqual(
      items.firstIndex(of: .hourly)! + 1,
      items.firstIndex(of: .yourNews)
    )
    XCTAssertEqual(
      items.firstIndex(of: .yourNews)! + 1,
      items.firstIndex(of: .daily)
    )
  }

  func testYourNewsHiddenWhenBriefingEmpty() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: false,
      hasAQI: false,
      hasSunriseOrSunset: false,
      showFireCard: false,
      showAIInsight: false
    )
    XCTAssertFalse(FeedAssembler.items(from: snapshot).contains(.yourNews))
  }

  func testStoryDayHoistKeepsYourNewsAfterHourly() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 2,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: true,
      hasAQI: false,
      hasSunriseOrSunset: false,
      showFireCard: false,
      showAIInsight: false,
      hasLocalBriefing: true
    )
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [.now, .alerts, .precip, .radar, .hourly, .yourNews, .daily]
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
