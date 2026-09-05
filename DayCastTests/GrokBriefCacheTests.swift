import XCTest

@testable import DayCast

@MainActor
final class GrokBriefCacheTests: XCTestCase {
  private var suiteName: String!
  private var defaults: UserDefaults!
  private let locationID = UUID()
  private let now = Date(timeIntervalSince1970: 1_767_268_800)  // 2026-01-01 12:00 UTC

  override func setUp() {
    super.setUp()
    suiteName = "GrokBriefCacheTests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)
    defaults.removePersistentDomain(forName: suiteName)
    GrokBriefCache.defaults = defaults
  }

  override func tearDown() {
    GrokBriefCache.defaults = .standard
    defaults.removePersistentDomain(forName: suiteName)
    super.tearDown()
  }

  func testMatchingWeatherReturnsBriefAndOneLiner() {
    let weather = makeWeather(temp: 72, conditionCode: 0)
    let brief =
      "The driest outdoor window is late morning. A light layer should be comfortable."
    GrokBriefCache.save(brief, locationID: locationID, weather: weather, now: now)

    XCTAssertEqual(
      GrokBriefCache.loadValidBrief(locationID: locationID, weather: weather, now: now),
      brief)
    XCTAssertEqual(
      GrokBriefCache.loadValidOneLiner(locationID: locationID, weather: weather, now: now),
      brief)
  }

  func testTempBandMismatchStalesBriefAndOneLiner() {
    let saved = makeWeather(temp: 72, conditionCode: 0)
    let brief = "Clear and mild — good window before the front."
    GrokBriefCache.save(brief, locationID: locationID, weather: saved, now: now)

    let afterFront = makeWeather(temp: 54, conditionCode: 0)
    XCTAssertNotEqual(
      GrokBriefCache.refreshToken(for: saved),
      GrokBriefCache.refreshToken(for: afterFront))

    let cacheKey = GrokBriefCache.key(locationID: locationID, now: now)
    XCTAssertEqual(defaults.string(forKey: cacheKey), brief)

    XCTAssertNil(
      GrokBriefCache.loadValidBrief(locationID: locationID, weather: afterFront, now: now))
    XCTAssertNil(
      GrokBriefCache.loadValidOneLiner(locationID: locationID, weather: afterFront, now: now))
  }

  func testConditionMismatchStalesBriefAndOneLiner() {
    let saved = makeWeather(temp: 72, conditionCode: 0)
    GrokBriefCache.save(
      "Sunshine this morning.", locationID: locationID, weather: saved, now: now)

    let rain = makeWeather(temp: 72, conditionCode: 61)
    XCTAssertNil(GrokBriefCache.loadValidBrief(locationID: locationID, weather: rain, now: now))
    XCTAssertNil(GrokBriefCache.loadValidOneLiner(locationID: locationID, weather: rain, now: now))
  }

  func testSameTempBandKeepsCache() {
    let saved = makeWeather(temp: 70, conditionCode: 0)
    GrokBriefCache.save("Still the same take.", locationID: locationID, weather: saved, now: now)

    let nearby = makeWeather(temp: 73, conditionCode: 0)
    XCTAssertEqual(
      GrokBriefCache.refreshToken(for: saved),
      GrokBriefCache.refreshToken(for: nearby))
    XCTAssertEqual(
      GrokBriefCache.loadValidOneLiner(locationID: locationID, weather: nearby, now: now),
      "Still the same take.")
  }

  func testLegacyEntryWithoutWeatherTokenIsStale() {
    let weather = makeWeather(temp: 72, conditionCode: 0)
    let cacheKey = GrokBriefCache.key(locationID: locationID, now: now)
    defaults.set("Old take with no weather token.", forKey: cacheKey)

    XCTAssertNil(GrokBriefCache.loadValidBrief(locationID: locationID, weather: weather, now: now))
    XCTAssertNil(
      GrokBriefCache.loadValidOneLiner(locationID: locationID, weather: weather, now: now))
  }

  func testOneLinerUsesSameInvalidationAsFullBrief() {
    let saved = makeWeather(temp: 80, conditionCode: 1)
    let longBrief = String(repeating: "a", count: GrokBriefCache.oneLinerMaxCharacters + 40)
    GrokBriefCache.save(longBrief, locationID: locationID, weather: saved, now: now)

    let hit = GrokBriefCache.loadValidOneLiner(
      locationID: locationID, weather: saved, now: now)
    XCTAssertEqual(hit?.count, GrokBriefCache.oneLinerMaxCharacters)
    XCTAssertEqual(
      GrokBriefCache.loadValidBrief(locationID: locationID, weather: saved, now: now),
      longBrief)

    let mismatch = makeWeather(temp: 50, conditionCode: 1)
    XCTAssertNil(GrokBriefCache.loadValidBrief(locationID: locationID, weather: mismatch, now: now))
    XCTAssertNil(
      GrokBriefCache.loadValidOneLiner(locationID: locationID, weather: mismatch, now: now))
  }

  private func makeWeather(temp: Double, conditionCode: Int) -> DayCastWeather {
    DayCastWeather(
      location: SavedLocation(
        id: locationID, name: "Test City", latitude: 35, longitude: -90),
      currentTemp: temp,
      feelsLike: temp,
      conditionCode: conditionCode,
      conditionText: "Test",
      humidity: 40,
      windSpeed: 5,
      uvIndex: 3,
      precipitationChance: 5,
      high: 78,
      low: 62,
      symbolName: "sun.max.fill",
      fetchedAt: now,
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
