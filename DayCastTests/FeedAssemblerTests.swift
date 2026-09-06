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
      showFireCard: true,
      showHealth: true
    )
    XCTAssertTrue(FeedAssembler.isRadarStory(snapshot))
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [
        .now, .alerts, .hourly, .radar, .health, .daily, .nearby,
      ]
    )
  }

  func testDryCityStillShowsRadarBeforeNews() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: false,
      showFireCard: true,
      isNowWet: false
    )
    XCTAssertFalse(FeedAssembler.isRadarStory(snapshot))
    let items = FeedAssembler.items(from: snapshot)
    XCTAssertEqual(
      items,
      [.now, .hourly, .radar, .daily, .nearby]
    )
    XCTAssertLessThan(items.firstIndex(of: .hourly)!, items.firstIndex(of: .radar)!)
  }

  func testHidesCardsWithoutMeaningfulData() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: true,
      hasDaily: false,
      hasPrecipContent: false,
      showFireCard: false
    )
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [.now, .hourly, .radar]
    )
  }

  func testStormSnapshotFirstFiveAreGlanceCards() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 2,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: true,
      showFireCard: true,
      hasLocalBriefing: true
    )
    let items = FeedAssembler.items(from: snapshot)
    XCTAssertEqual(
      Array(items.prefix(5)),
      [.now, .alerts, .hourly, .radar, .yourNews]
    )
    XCTAssertLessThan(items.firstIndex(of: .hourly)!, items.firstIndex(of: .radar)!)
    XCTAssertLessThan(items.firstIndex(of: .radar)!, items.firstIndex(of: .yourNews)!)
    XCTAssertLessThan(items.firstIndex(of: .yourNews)!, items.firstIndex(of: .daily)!)
  }

  func testWetNowKeepsRadarAfterHourly() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: false,
      showFireCard: false,
      isNowWet: true
    )
    XCTAssertTrue(FeedAssembler.isRadarStory(snapshot))
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [.now, .hourly, .radar, .daily]
    )
  }

  func testWarnedDryPointKeepsRadarAfterAlerts() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 1,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: false,
      showFireCard: false,
      isNowWet: false,
      hasRadarRelevantAlert: true
    )
    XCTAssertTrue(FeedAssembler.isRadarStory(snapshot))
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [.now, .alerts, .hourly, .radar, .daily]
    )
  }

  func testPrecipStoryKeepsRadarAfterHourly() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: true,
      showFireCard: false,
      isNowWet: false
    )
    XCTAssertTrue(FeedAssembler.isRadarStory(snapshot))
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [.now, .hourly, .radar, .daily]
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
      showFireCard: false
    )
    XCTAssertFalse(FeedAssembler.items(from: snapshot).contains(.alerts))
    snapshot.alertCount = 1
    XCTAssertTrue(snapshot.showAlertsSlot)
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [.now, .alerts, .radar]
    )
    XCTAssertTrue(FeedAssembler.items(from: snapshot).contains(.alerts))
  }

  func testBuilderZeroNWSDoesNotEarnAlertsSlot() {
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
    let snapshot = FeedSnapshotBuilder.make(weather: weather, alerts: [])
    XCTAssertEqual(snapshot.alertCount, 0)
    XCTAssertFalse(snapshot.showHealth)
    XCTAssertFalse(snapshot.showAlertsSlot)
    let items = FeedAssembler.items(from: snapshot)
    XCTAssertEqual(items.first, .now)
    XCTAssertFalse(items.contains(.alerts))
    XCTAssertFalse(items.contains(.health))
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
    XCTAssertFalse(snapshot.showHealth)
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
      showFireCard: true
    )
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [.now, .radar, .nearby]
    )
  }

  func testSunDoesNotEarnNearby() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: false,
      hasDaily: false,
      hasPrecipContent: false,
      showFireCard: false
    )
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [.now, .radar]
    )
    XCTAssertFalse(FeedAssembler.items(from: snapshot).contains(.nearby))
  }

  func testElevatedHealthAppearsWhenFlagged() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: false,
      hasDaily: false,
      hasPrecipContent: false,
      showFireCard: false,
      showHealth: true
    )
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [.now, .radar, .health]
    )
  }

  func testCalmDayHidesConditionsAndNearby() {
    XCTAssertFalse(
      ConditionsVisibility.shouldShow(
        aqi: 42, visibilityMeters: 16_000, hasNWSAirQualityAlert: false)
    )
    XCTAssertTrue(
      ConditionsVisibility.shouldShow(
        aqi: 75, visibilityMeters: 16_000, hasNWSAirQualityAlert: false)
    )
    XCTAssertTrue(
      ConditionsVisibility.shouldShow(
        aqi: 40, visibilityMeters: 4_000, hasNWSAirQualityAlert: false)
    )
    XCTAssertTrue(
      ConditionsVisibility.shouldShow(
        aqi: 40, visibilityMeters: 16_000, hasNWSAirQualityAlert: true)
    )
    XCTAssertFalse(ConditionsVisibility.showsPrecipTile(isNowWet: true))
    XCTAssertTrue(ConditionsVisibility.showsPrecipTile(isNowWet: false))
  }

  func testYourNewsSitsAfterRadarWhenBriefingExists() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: false,
      showFireCard: false,
      hasLocalBriefing: true
    )
    let items = FeedAssembler.items(from: snapshot)
    XCTAssertEqual(items, [.now, .hourly, .radar, .yourNews, .daily])
    XCTAssertLessThan(items.firstIndex(of: .radar)!, items.firstIndex(of: .yourNews)!)
    XCTAssertLessThan(items.firstIndex(of: .hourly)!, items.firstIndex(of: .radar)!)
  }

  func testYourNewsHiddenWhenBriefingEmpty() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: false,
      showFireCard: false
    )
    XCTAssertFalse(snapshot.isLocalBriefingPending)
    XCTAssertFalse(FeedAssembler.items(from: snapshot).contains(.yourNews))
  }

  func testYourNewsHeldWhenBriefingPending() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: false,
      showFireCard: false,
      isLocalBriefingPending: true
    )
    let items = FeedAssembler.items(from: snapshot)
    XCTAssertEqual(items, [.now, .hourly, .radar, .yourNews, .daily])
    XCTAssertLessThan(items.firstIndex(of: .yourNews)!, items.firstIndex(of: .daily)!)
  }

  func testStoryDayKeepsYourNewsAfterHourly() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 2,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: true,
      showFireCard: false,
      hasLocalBriefing: true
    )
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [.now, .alerts, .hourly, .radar, .yourNews, .daily]
    )
  }

  func testDryNextEventShowsRadarAfterHourly() {
    let snapshot = FeedSnapshot(
      hasWeather: true,
      alertCount: 0,
      hasHourly: true,
      hasDaily: true,
      hasPrecipContent: false,
      showFireCard: false
    )
    XCTAssertFalse(FeedAssembler.isRadarStory(snapshot))
    let items = FeedAssembler.items(from: snapshot)
    XCTAssertEqual(items, [.now, .hourly, .radar, .daily])
    XCTAssertLessThan(items.firstIndex(of: .hourly)!, items.firstIndex(of: .radar)!)
  }

  func testHeatAdvisoryOnDryAfternoonIsNotRadarStory() {
    let weather = dryOliveBranchWeather()
    let snapshot = FeedSnapshotBuilder.make(
      weather: weather,
      alerts: [makeAlert(event: "Heat Advisory", severity: "Moderate")]
    )
    XCTAssertFalse(snapshot.isNowWet)
    XCTAssertFalse(snapshot.hasPrecipContent)
    XCTAssertFalse(snapshot.hasRadarRelevantAlert)
    XCTAssertFalse(snapshot.showHealth)
    XCTAssertTrue(snapshot.showAlertsSlot)
    XCTAssertFalse(FeedAssembler.isRadarStory(snapshot))
    XCTAssertEqual(
      FeedAssembler.items(from: snapshot),
      [.now, .alerts, .radar]
    )
  }

  func testExtremeHeatWarningOnDryAfternoonIsNotRadarStory() {
    let snapshot = FeedSnapshotBuilder.make(
      weather: dryOliveBranchWeather(),
      alerts: [makeAlert(event: "Extreme Heat Warning", severity: "Extreme")]
    )
    XCTAssertTrue(snapshot.showAlertsSlot)
    XCTAssertFalse(snapshot.hasRadarRelevantAlert)
    XCTAssertFalse(FeedAssembler.isRadarStory(snapshot))
  }

  func testAirQualityAlertOnDryAfternoonIsNotRadarStory() {
    let snapshot = FeedSnapshotBuilder.make(
      weather: dryOliveBranchWeather(),
      alerts: [makeAlert(event: "Air Quality Alert", severity: "Moderate")]
    )
    XCTAssertTrue(snapshot.showAlertsSlot)
    XCTAssertFalse(snapshot.hasRadarRelevantAlert)
    XCTAssertFalse(FeedAssembler.isRadarStory(snapshot))
    XCTAssertTrue(snapshot.showHealth)
    XCTAssertTrue(FeedAssembler.items(from: snapshot).contains(.health))
  }

  func testTornadoWarningOnDryPointIsRadarStory() {
    let snapshot = FeedSnapshotBuilder.make(
      weather: dryOliveBranchWeather(),
      alerts: [makeAlert(event: "Tornado Warning", severity: "Extreme")]
    )
    XCTAssertFalse(snapshot.isNowWet)
    XCTAssertTrue(snapshot.hasRadarRelevantAlert)
    XCTAssertTrue(snapshot.showAlertsSlot)
    XCTAssertTrue(FeedAssembler.isRadarStory(snapshot))
  }

  func testSevereThunderstormWatchOnDryPointIsRadarStory() {
    let snapshot = FeedSnapshotBuilder.make(
      weather: dryOliveBranchWeather(),
      alerts: [makeAlert(event: "Severe Thunderstorm Watch", severity: "Severe")]
    )
    XCTAssertTrue(snapshot.hasRadarRelevantAlert)
    XCTAssertTrue(FeedAssembler.isRadarStory(snapshot))
  }

  private func dryOliveBranchWeather() -> DayCastWeather {
    DayCastWeather(
      location: SavedLocation(name: "Olive Branch", latitude: 34.96, longitude: -89.83),
      currentTemp: 99,
      feelsLike: 104,
      conditionCode: 0,
      conditionText: "Clear",
      humidity: 40,
      windSpeed: 5,
      uvIndex: 9,
      precipitationChance: 4,
      high: 101,
      low: 78,
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

  private func makeAlert(event: String, severity: String? = nil) -> NWSAlert {
    NWSAlert(
      id: event,
      event: event,
      severity: severity,
      headline: nil,
      description: nil,
      instruction: nil,
      expires: Date().addingTimeInterval(3600),
      areaDesc: "DeSoto, MS",
      latitude: 34.96,
      longitude: -89.83
    )
  }
}
