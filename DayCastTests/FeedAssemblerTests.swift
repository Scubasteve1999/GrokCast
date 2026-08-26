import XCTest

@testable import DayCast

final class FeedAssemblerTests: XCTestCase {
  func testTodayFeedNeverIncludesTake() {
    XCTAssertFalse(FeedItem.defaultOrder.contains(.aiInsight))
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: false,
      hasAQI: true,
      hasSunriseOrSunset: true,
      showFireCard: true,
      showAIInsight: true
    )
    XCTAssertFalse(FeedAssembler.items(from: snapshot).contains(.aiInsight))
  }

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
        .now, .hourly, .health, .daily, .radar, .nearby,
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
      [.now, .hourly, .health, .daily, .radar, .nearby]
    )
    XCTAssertLessThan(items.firstIndex(of: .hourly)!, items.firstIndex(of: .radar)!)
    XCTAssertFalse(items.contains(.decision))
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
      [.now, .hourly, .health, .radar]
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
      [.now, .hourly, .health, .daily, .radar]
    )
    XCTAssertLessThan(items.firstIndex(of: .hourly)!, items.firstIndex(of: .radar)!)
    XCTAssertLessThan(items.firstIndex(of: .health)!, items.firstIndex(of: .radar)!)
    XCTAssertLessThan(items.firstIndex(of: .daily)!, items.firstIndex(of: .radar)!)
    XCTAssertFalse(items.contains(.aiInsight))
  }

  func testWetNowKeepsRadarAfterHealth() {
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
      [.now, .hourly, .health, .daily, .radar]
    )
  }

  func testWarnedDryPointKeepsRadarAfterHealth() {
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
      [.now, .hourly, .health, .daily, .radar]
    )
  }

  func testPrecipStoryKeepsRadarAfterHealth() {
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
      [.now, .hourly, .health, .daily, .radar]
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
    XCTAssertTrue(snapshot.showAlertsSlot)
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [.now, .health, .radar]
    )
    XCTAssertFalse(FeedAssembler.items(from: snapshot).contains(.alerts))
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
    XCTAssertFalse(items.contains(.alerts))
    XCTAssertEqual(Array(items.prefix(5)), [.now, .hourly, .health, .daily, .radar])
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
    XCTAssertFalse(items.contains(.alerts))
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

  func testBuilderTreatsHRRRRainNowAsWetWhenWMOIsClear() {
    let now = Date()
    let wetSlots: [MinutelyForecast] = (0..<8).map { index in
      MinutelyForecast(
        time: now.addingTimeInterval(Double(index) * 15 * 60),
        precipitation: 0.05,
        precipChance: 80)
    }
    let weather = DayCastWeather(
      location: SavedLocation(name: "Olive Branch", latitude: 34.96, longitude: -89.83),
      currentTemp: 82,
      feelsLike: 83,
      conditionCode: 0,
      conditionText: "Clear",
      humidity: 40,
      windSpeed: 5,
      uvIndex: 7,
      precipitationChance: 10,
      high: 88,
      low: 68,
      symbolName: "sun.max.fill",
      fetchedAt: now,
      timezoneIdentifier: "America/Chicago",
      airQualityIndex: nil,
      pm25: nil,
      pollenLevel: nil,
      hourly: [],
      daily: [],
      minutely15: wetSlots
    )
    let snapshot = FeedSnapshotBuilder.make(weather: weather, alerts: [])
    XCTAssertTrue(snapshot.isNowWet)
    XCTAssertTrue(FeedAssembler.isRadarStory(snapshot))
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
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [.now, .health, .radar, .nearby]
    )
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
      [.now, .health, .radar, .nearby]
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
    XCTAssertEqual(items, [.now, .hourly, .yourNews, .health, .daily, .radar])
    XCTAssertLessThan(items.firstIndex(of: .yourNews)!, items.firstIndex(of: .daily)!)
    XCTAssertLessThan(items.firstIndex(of: .hourly)!, items.firstIndex(of: .yourNews)!)
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

  func testStoryDayKeepsYourNewsAfterHourly() {
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
      [.now, .hourly, .yourNews, .health, .daily, .radar]
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
    XCTAssertFalse(FeedAssembler.items(from: snapshot).contains(.precip))
  }

  func testDryNextEventShowsRadarAfterHealth() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: false,
      hasNextEvent: true,
      hasAQI: false,
      hasSunriseOrSunset: false,
      showFireCard: false,
      showAIInsight: false
    )
    XCTAssertFalse(FeedAssembler.isRadarStory(snapshot))
    let items = FeedAssembler.items(from: snapshot)
    XCTAssertEqual(items, [.now, .hourly, .health, .daily, .radar])
    XCTAssertFalse(items.contains(.precip))
    XCTAssertLessThan(items.firstIndex(of: .hourly)!, items.firstIndex(of: .radar)!)
  }
}
