import XCTest

@testable import DayCast

final class TodayFirstRunTests: XCTestCase {
  private let olive = SavedLocation.oliveBranch
  private let seattle = SavedLocation(
    name: "Seattle, WA", latitude: 47.6062, longitude: -122.3321)

  func testWelcomeCopyIsStormTrustNotAIMarketing() {
    XCTAssertEqual(TodayCopy.welcomeTitle, "Welcome to DayCast")
    let body = TodayCopy.welcomeBody.lowercased()
    XCTAssertFalse(body.contains("ai-powered"))
    XCTAssertFalse(body.contains("ai powered"))
    XCTAssertTrue(body.contains("now"))
    XCTAssertTrue(body.contains("alert"))
    XCTAssertTrue(body.contains("rain"))
  }

  func testEmptyGateCopyIsNotASecondWelcome() {
    XCTAssertNotEqual(TodayCopy.emptyTitle, TodayCopy.welcomeTitle)
    XCTAssertFalse(TodayCopy.emptyTitle.localizedCaseInsensitiveContains("welcome"))
    XCTAssertTrue(TodayCopy.emptyBody.localizedCaseInsensitiveContains("use my position"))
    XCTAssertEqual(TodayCopy.gettingLocation, "Getting your location…")
  }

  func testSkeletonSlotsMatchStormFirstGlance() {
    XCTAssertEqual(
      TodaySkeletonSlot.feedOrder.map(\.feedItem),
      [.now, .alerts, .precip, .hourly])
    let glance = FeedItem.defaultOrder.filter {
      TodaySkeletonSlot.feedOrder.map(\.feedItem).contains($0)
    }
    XCTAssertEqual(Array(glance.prefix(4)), [.now, .alerts, .precip, .hourly])
  }

  func testDefaultOliveBranchIsNotANearMeChip() {
    XCTAssertFalse(olive.isCurrent)
    XCTAssertEqual(LocationChipBar.chipTitle(for: olive), "Olive Branch, MS")
    XCTAssertNotEqual(LocationChipBar.chipTitle(for: olive), "Near Me")
  }

  func testFallbackClearsIsCurrentOnOliveBranch() {
    let gpsOlive = SavedLocation(
      id: olive.id,
      name: olive.name,
      latitude: olive.latitude,
      longitude: olive.longitude,
      isCurrent: true)
    let applied = WeatherStore.applyingDefaultOliveBranchFallback(to: [gpsOlive])
    XCTAssertFalse(applied.location.isCurrent)
    XCTAssertEqual(applied.saved.count, 1)
    XCTAssertFalse(applied.saved[0].isCurrent)
    XCTAssertEqual(LocationChipBar.chipTitle(for: applied.location), "Olive Branch, MS")
  }

  func testFallbackInsertsOliveBranchWhenMissing() {
    let applied = WeatherStore.applyingDefaultOliveBranchFallback(to: [seattle])
    XCTAssertTrue(WeatherStore.isDefaultOliveBranch(applied.location))
    XCTAssertFalse(applied.location.isCurrent)
    XCTAssertEqual(applied.saved.count, 2)
    XCTAssertEqual(applied.saved[0].id, seattle.id)
    XCTAssertFalse(applied.saved[0].isCurrent)
  }

  func testFallbackDoesNotImpersonateCurrentOnEmptySaves() {
    let applied = WeatherStore.applyingDefaultOliveBranchFallback(to: [])
    XCTAssertTrue(WeatherStore.isDefaultOliveBranch(applied.location))
    XCTAssertFalse(applied.location.isCurrent)
    XCTAssertEqual(LocationChipBar.chipTitle(for: applied.location), "Olive Branch, MS")
  }

  func testGpsFallbackMessageNamesOliveBranchNotNearMe() {
    let message = WeatherStore.gpsFallbackHonestyMessage.lowercased()
    XCTAssertTrue(message.contains("olive branch"))
    XCTAssertFalse(message.contains("near me"))
    XCTAssertTrue(message.contains("gps") || message.contains("position"))
  }

  func testAutoAcquireOnFirstAllowWithDefaultOliveBranch() {
    XCTAssertTrue(
      WeatherStore.shouldAutoAcquireDeviceLocation(
        hasAttempted: false,
        isAuthorized: true,
        savedLocations: [olive]))
  }

  func testAutoAcquireSkippedAfterAttemptOrGPSPin() {
    XCTAssertFalse(
      WeatherStore.shouldAutoAcquireDeviceLocation(
        hasAttempted: true,
        isAuthorized: true,
        savedLocations: [olive]))
    let gps = SavedLocation(
      name: olive.name, latitude: olive.latitude, longitude: olive.longitude, isCurrent: true)
    XCTAssertFalse(
      WeatherStore.shouldAutoAcquireDeviceLocation(
        hasAttempted: false,
        isAuthorized: true,
        savedLocations: [gps]))
    XCTAssertFalse(
      WeatherStore.shouldAutoAcquireDeviceLocation(
        hasAttempted: false,
        isAuthorized: false,
        savedLocations: [olive]))
  }

  func testAutoAcquireSkippedForChosenCity() {
    XCTAssertFalse(
      WeatherStore.shouldAutoAcquireDeviceLocation(
        hasAttempted: false,
        isAuthorized: true,
        savedLocations: [seattle]))
    XCTAssertFalse(
      WeatherStore.shouldAutoAcquireDeviceLocation(
        hasAttempted: false,
        isAuthorized: true,
        savedLocations: [olive, seattle]))
  }

  func testSkipPlaceholderWeatherOnFirstRunDefault() {
    XCTAssertTrue(
      WeatherStore.shouldSkipPlaceholderWeather(
        hasAttemptedDeviceLocation: false,
        savedLocations: [olive]))
    XCTAssertFalse(
      WeatherStore.shouldSkipPlaceholderWeather(
        hasAttemptedDeviceLocation: true,
        savedLocations: [olive]))
    XCTAssertFalse(
      WeatherStore.shouldSkipPlaceholderWeather(
        hasAttemptedDeviceLocation: false,
        savedLocations: [seattle]))
  }

  func testIsDefaultOliveBranchUsesCoordsNotId() {
    let copy = SavedLocation(
      name: "Olive Branch, MS", latitude: 34.9618, longitude: -89.8295)
    XCTAssertTrue(WeatherStore.isDefaultOliveBranch(copy))
    XCTAssertFalse(WeatherStore.isDefaultOliveBranch(seattle))
  }
}
