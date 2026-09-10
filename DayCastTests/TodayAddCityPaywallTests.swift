import XCTest

@testable import DayCast

@MainActor
final class TodayAddCityPaywallTests: XCTestCase {
  private let gps = SavedLocation(
    name: "Olive Branch, MS", latitude: 34.9618, longitude: -89.8295, isCurrent: true)
  private let seattle = SavedLocation(
    name: "Seattle, WA", latitude: 47.6062, longitude: -122.3321)
  private let denver = SavedLocation(
    name: "Denver, CO", latitude: 39.7392, longitude: -104.9903)

  override func tearDown() {
    PaywallCoordinator.shared.isPresented = false
    PaywallCoordinator.shared.source = nil
    super.tearDown()
  }

  func testSelectionDecisionIsTheSameGateAsSelection() {
    XCTAssertEqual(
      CitySearch.selectionDecision(candidate: denver, saved: [gps, seattle], canAdd: false),
      CitySearch.selection(candidate: denver, saved: [gps, seattle], canAdd: false)
    )
    XCTAssertEqual(
      CitySearch.selectionDecision(candidate: denver, saved: [gps, seattle], canAdd: false),
      .paywall
    )
  }

  func testTodayPathFreeSecondNamedCityHitsLocationsPaywall() throws {
    let result = try XCTUnwrap(
      CitySearch.result(
        name: "Denver, CO", subtitle: nil, latitude: 39.7392, longitude: -104.9903)
    )
    let (_, selection) = LocationSearchFlow.decision(
      for: result, saved: [gps, seattle], isPro: false)
    XCTAssertFalse(
      EntitlementChecker.canAddLocation(locations: [gps, seattle], isPro: false))
    XCTAssertEqual(selection, .paywall)
  }

  func testTodayPathGPSOnlyStillAddsTheFirstNamedCity() throws {
    let result = try XCTUnwrap(
      CitySearch.result(
        name: "Seattle, WA", subtitle: nil, latitude: 47.6062, longitude: -122.3321)
    )
    let (_, selection) = LocationSearchFlow.decision(
      for: result, saved: [gps], isPro: false)
    XCTAssertTrue(EntitlementChecker.canAddLocation(locations: [gps], isPro: false))
    XCTAssertEqual(selection, .add)
  }

  func testTodayPathSelectsAnAlreadySavedCityWithoutPaywall() throws {
    let result = try XCTUnwrap(
      CitySearch.result(
        name: "Seattle, WA", subtitle: nil, latitude: 47.6062, longitude: -122.3321)
    )
    let (_, selection) = LocationSearchFlow.decision(
      for: result, saved: [gps, seattle], isPro: false)
    XCTAssertEqual(selection, .selectExisting(seattle))
  }

  func testTodayPathNamedOnlyReplacesTheNamedSlot() throws {
    let olive = SavedLocation.oliveBranch
    let result = try XCTUnwrap(
      CitySearch.result(
        name: "Seattle, WA", subtitle: nil, latitude: 47.6062, longitude: -122.3321)
    )
    let (_, selection) = LocationSearchFlow.decision(
      for: result, saved: [olive], isPro: false)
    XCTAssertEqual(selection, .replace(olive))
  }

  func testTodayPathProAddsASecondNamedCity() throws {
    let result = try XCTUnwrap(
      CitySearch.result(
        name: "Denver, CO", subtitle: nil, latitude: 39.7392, longitude: -104.9903)
    )
    let (_, selection) = LocationSearchFlow.decision(
      for: result, saved: [gps, seattle], isPro: true)
    XCTAssertTrue(
      EntitlementChecker.canAddLocation(locations: [gps, seattle], isPro: true))
    XCTAssertEqual(selection, .add)
  }

  func testTodayPathApplyPresentsLocationsPaywallAndDoesNotSave() throws {
    let store = WeatherStore(loadPersistedState: false)
    store.savedLocations = [gps, seattle]
    let result = try XCTUnwrap(
      CitySearch.result(
        name: "Denver, CO", subtitle: nil, latitude: 39.7392, longitude: -104.9903)
    )
    var presented = false
    let selection = LocationSearchFlow.apply(
      result: result,
      store: store,
      isPro: false,
      presentPaywall: { presented = true }
    )
    XCTAssertEqual(selection, .paywall)
    XCTAssertTrue(presented)
    XCTAssertEqual(store.savedLocations.map(\.id), [gps.id, seattle.id])
  }

  func testTodayPathApplySelectsExistingCity() throws {
    let store = WeatherStore(loadPersistedState: false)
    store.savedLocations = [gps, seattle]
    store.currentLocation = gps
    let result = try XCTUnwrap(
      CitySearch.result(
        name: "Seattle, WA", subtitle: nil, latitude: 47.6062, longitude: -122.3321)
    )
    var presented = false
    let selection = LocationSearchFlow.apply(
      result: result,
      store: store,
      isPro: false,
      presentPaywall: { presented = true }
    )
    XCTAssertEqual(selection, .selectExisting(seattle))
    XCTAssertFalse(presented)
    XCTAssertEqual(store.currentLocation?.id, seattle.id)
  }

  func testTodayChipPresentsLocationsPaywallWithTodayChipSource() {
    PaywallCoordinator.shared.present(.locations, source: .todayChip)
    XCTAssertTrue(PaywallCoordinator.shared.isPresented)
    XCTAssertEqual(PaywallCoordinator.shared.feature, .locations)
    XCTAssertEqual(PaywallCoordinator.shared.source, .todayChip)
  }

  func testLocationsTabPresentsLocationsPaywallWithLocationsSource() {
    PaywallCoordinator.shared.present(.locations, source: .locations)
    XCTAssertEqual(PaywallCoordinator.shared.source, .locations)
    XCTAssertEqual(PaywallCoordinator.shared.feature, .locations)
  }

  func testPaywallViewKeepsLocationsFeatureAndAddsSource() {
    XCTAssertEqual(
      PaywallAnalytics.viewParameters(feature: .locations),
      ["feature": "locations"]
    )
    XCTAssertEqual(
      PaywallAnalytics.viewParameters(feature: .locations, source: .todayChip),
      ["feature": "locations", "source": "today_chip"]
    )
    XCTAssertEqual(
      PaywallAnalytics.viewParameters(feature: .locations, source: .locations),
      ["feature": "locations", "source": "locations"]
    )
    XCTAssertEqual(PaywallSource.todayChip.analyticsName, "today_chip")
    XCTAssertEqual(PaywallFeature.locations.analyticsName, "locations")
  }

  func testAddCityTapUsesExistingFeedCardEvent() {
    XCTAssertEqual(LocationChipBar.addCityAnalyticsCard, "today_add_city")
    XCTAssertEqual(LocationChipBar.addCityTapParameters, ["card": "today_add_city"])
    XCTAssertEqual(AnalyticsEvent.feedCardTap.rawValue, "feed_card_tap")
  }

  func testChipBarAddCityStaysOneThumbAndDoesNotAddAPromoRow() {
    XCTAssertTrue(LocationChipBar.usesTrailingAddCityControl)
    XCTAssertFalse(LocationChipBar.usesPermanentPromoRow)
    XCTAssertEqual(LocationChipBar.reservedHeight, 52)
    XCTAssertEqual(LocationChipBar.addCityAccessibilityLabel, "Add city")
    XCTAssertEqual(DayCastAccessibility.Today.addCity, "daycast.today.addCity")
    XCTAssertEqual(DayCastAccessibility.Today.addCitySearch, "daycast.today.addCity.search")
    XCTAssertEqual(
      DayCastAccessibility.Today.addCitySearchField, "daycast.today.addCity.searchField")
  }

  func testTodaySheetReusesLocationsFreeLimitCopy() {
    XCTAssertEqual(LocationsCopy.freeLimitChip, "Free includes Near Me + 1 saved city")
    XCTAssertEqual(LocationsCopy.saveUnlimitedCTA, "Save unlimited places")
    XCTAssertEqual(LocationsCopy.saveUnlimitedCTA, PaywallFeature.locations.headline)
  }
}
