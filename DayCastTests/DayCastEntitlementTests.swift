import XCTest

@testable import DayCast

final class DayCastEntitlementTests: XCTestCase {

  func testMonthlyProductIsProButNotYearly() {
    let resolved = DayCastProProducts.resolvedEntitlement(productIDs: [
      DayCastProProducts.monthly
    ])
    XCTAssertTrue(resolved.isPro)
    XCTAssertFalse(resolved.isYearly)
  }

  func testYearlyProductIsProAndYearly() {
    let resolved = DayCastProProducts.resolvedEntitlement(productIDs: [
      DayCastProProducts.yearly
    ])
    XCTAssertTrue(resolved.isPro)
    XCTAssertTrue(resolved.isYearly)
  }

  func testBothProductsPreferYearly() {
    let resolved = DayCastProProducts.resolvedEntitlement(productIDs: [
      DayCastProProducts.monthly, DayCastProProducts.yearly,
    ])
    XCTAssertTrue(resolved.isPro)
    XCTAssertTrue(resolved.isYearly)
  }

  func testUnknownProductIDsAreIgnored() {
    let resolved = DayCastProProducts.resolvedEntitlement(productIDs: [
      "com.example.other"
    ])
    XCTAssertFalse(resolved.isPro)
    XCTAssertFalse(resolved.isYearly)
  }

  func testEmptySetIsFree() {
    let resolved = DayCastProProducts.resolvedEntitlement(productIDs: [])
    XCTAssertFalse(resolved.isPro)
    XCTAssertFalse(resolved.isYearly)
  }

  func testMonthlyDoesNotUnlockYearlyExtras() {
    XCTAssertFalse(
      DayCastEntitlements.canUseYearlyExtras(isYearly: false, hasDeveloperKey: false))
  }

  func testYearlyUnlocksYearlyExtras() {
    XCTAssertTrue(
      DayCastEntitlements.canUseYearlyExtras(isYearly: true, hasDeveloperKey: false))
  }

  func testDeveloperKeyUnlocksYearlyExtrasWithoutAPaidProduct() {
    XCTAssertTrue(
      DayCastEntitlements.canUseYearlyExtras(isYearly: false, hasDeveloperKey: true))
  }

  func testMonthlyUnlocksAIButNotWidgetBrief() {
    XCTAssertTrue(
      GrokAccessRules.canUseGrokAI(
        isPro: true, proxyConfigured: true, hasDeveloperKey: false))
    XCTAssertTrue(
      GrokAccessRules.canUseMorningBrief(
        isPro: true, proxyConfigured: true, hasDeveloperKey: false))
    XCTAssertFalse(
      GrokAccessRules.canUseWidgetGrokBrief(
        isYearly: false,
        isPro: true,
        proxyConfigured: true,
        hasDeveloperKey: false
      ))
  }

  func testYearlyUnlocksAIAndWidgetBrief() {
    XCTAssertTrue(
      GrokAccessRules.canUseWidgetGrokBrief(
        isYearly: true,
        isPro: true,
        proxyConfigured: true,
        hasDeveloperKey: false
      ))
  }

  func testDeveloperKeyUnlocksAIAndWidgetBrief() {
    XCTAssertTrue(
      GrokAccessRules.canUseGrokAI(
        isPro: false, proxyConfigured: false, hasDeveloperKey: true))
    XCTAssertTrue(
      GrokAccessRules.canUseWidgetGrokBrief(
        isYearly: false,
        isPro: false,
        proxyConfigured: false,
        hasDeveloperKey: true
      ))
  }

  func testHomeScreenWidgetsRequireYearlyFlag() {
    XCTAssertFalse(
      WidgetDataStore.canRenderWeather(isYearlySubscriber: false))
    XCTAssertTrue(
      WidgetDataStore.canRenderWeather(isYearlySubscriber: true))
    XCTAssertEqual(WidgetEmptyReason.requiresYearly.title, "Yearly unlocks widgets")
    XCTAssertEqual(WidgetEmptyReason.requiresYearly.message, "Tap to open DayCast.")
  }

  func testMonthlyResolvedEntitlementDoesNotUnlockWidgetSurface() {
    let monthly = DayCastProProducts.resolvedEntitlement(productIDs: [
      DayCastProProducts.monthly
    ])
    XCTAssertTrue(monthly.isPro)
    XCTAssertFalse(monthly.isYearly)
    XCTAssertFalse(
      WidgetDataStore.canRenderWeather(isYearlySubscriber: monthly.isYearly))
  }

  func testYearlyResolvedEntitlementUnlocksWidgetSurface() {
    let yearly = DayCastProProducts.resolvedEntitlement(productIDs: [
      DayCastProProducts.yearly
    ])
    XCTAssertTrue(yearly.isYearly)
    XCTAssertTrue(
      WidgetDataStore.canRenderWeather(isYearlySubscriber: yearly.isYearly))
  }

  func testNamedSavedCountIgnoresGPSPins() {
    let gps = SavedLocation(
      name: "Olive Branch, MS", latitude: 34.9618, longitude: -89.8295, isCurrent: true)
    let seattle = SavedLocation(name: "Seattle, WA", latitude: 47.6062, longitude: -122.3321)
    let denver = SavedLocation(name: "Denver, CO", latitude: 39.7392, longitude: -104.9903)

    XCTAssertEqual(EntitlementChecker.namedSavedCount(in: []), 0)
    XCTAssertEqual(EntitlementChecker.namedSavedCount(in: [gps]), 0)
    XCTAssertEqual(EntitlementChecker.namedSavedCount(in: [seattle]), 1)
    XCTAssertEqual(EntitlementChecker.namedSavedCount(in: [gps, seattle]), 1)
    XCTAssertEqual(EntitlementChecker.namedSavedCount(in: [seattle, denver]), 2)
    XCTAssertEqual(EntitlementChecker.countTowardFreeLocationLimit([gps, seattle]), 1)
    XCTAssertEqual(EntitlementChecker.freeSavedLocationLimit, 1)
  }

  func testFreeGPSOnlyCanAddOneNamedCity() {
    let gps = SavedLocation(
      name: "Olive Branch, MS", latitude: 34.9618, longitude: -89.8295, isCurrent: true)
    XCTAssertTrue(EntitlementChecker.canAddLocation(namedCount: 0, isPro: false))
    XCTAssertTrue(EntitlementChecker.canAddLocation(locations: [gps], isPro: false))
    XCTAssertTrue(EntitlementChecker.canAddLocation(locations: [], isPro: false))
  }

  func testFreeGPSPlusOneNamedCannotAddSecondNamed() {
    let gps = SavedLocation(
      name: "Olive Branch, MS", latitude: 34.9618, longitude: -89.8295, isCurrent: true)
    let seattle = SavedLocation(name: "Seattle, WA", latitude: 47.6062, longitude: -122.3321)
    XCTAssertFalse(EntitlementChecker.canAddLocation(namedCount: 1, isPro: false))
    XCTAssertFalse(EntitlementChecker.canAddLocation(locations: [gps, seattle], isPro: false))
    XCTAssertFalse(EntitlementChecker.canAddLocation(locations: [seattle], isPro: false))
  }

  func testFreeTwoNamedCitiesCannotAddAnother() {
    let seattle = SavedLocation(name: "Seattle, WA", latitude: 47.6062, longitude: -122.3321)
    let denver = SavedLocation(name: "Denver, CO", latitude: 39.7392, longitude: -104.9903)
    XCTAssertFalse(EntitlementChecker.canAddLocation(locations: [seattle, denver], isPro: false))
  }

  func testProUnlimitedLocationsUnchanged() {
    let gps = SavedLocation(
      name: "Olive Branch, MS", latitude: 34.9618, longitude: -89.8295, isCurrent: true)
    let seattle = SavedLocation(name: "Seattle, WA", latitude: 47.6062, longitude: -122.3321)
    let denver = SavedLocation(name: "Denver, CO", latitude: 39.7392, longitude: -104.9903)
    XCTAssertTrue(EntitlementChecker.canAddLocation(namedCount: 0, isPro: true))
    XCTAssertTrue(EntitlementChecker.canAddLocation(namedCount: 1, isPro: true))
    XCTAssertTrue(EntitlementChecker.canAddLocation(namedCount: 12, isPro: true))
    XCTAssertTrue(
      EntitlementChecker.canAddLocation(locations: [gps, seattle, denver], isPro: true))
  }

  func testFreeGPSOnlySearchAddsNamedCity() {
    let gps = SavedLocation(
      name: "Olive Branch, MS", latitude: 34.9618, longitude: -89.8295, isCurrent: true)
    let seattle = SavedLocation(name: "Seattle, WA", latitude: 47.6062, longitude: -122.3321)
    let saved = [gps]
    let canAdd = EntitlementChecker.canAddLocation(locations: saved, isPro: false)
    XCTAssertTrue(canAdd)
    XCTAssertEqual(
      CitySearch.selection(candidate: seattle, saved: saved, canAdd: canAdd),
      .add
    )
  }

  func testFreeNamedOnlySearchReplacesTheNamedSlot() {
    let olive = SavedLocation.oliveBranch
    let seattle = SavedLocation(name: "Seattle, WA", latitude: 47.6062, longitude: -122.3321)
    let saved = [olive]
    let canAdd = EntitlementChecker.canAddLocation(locations: saved, isPro: false)
    XCTAssertFalse(canAdd)
    XCTAssertEqual(
      CitySearch.selection(candidate: seattle, saved: saved, canAdd: canAdd),
      .replace(olive)
    )
  }

  func testFreeGPSPlusOneNamedSearchHitsLocationsPaywall() {
    let gps = SavedLocation(
      name: "Olive Branch, MS", latitude: 34.9618, longitude: -89.8295, isCurrent: true)
    let seattle = SavedLocation(name: "Seattle, WA", latitude: 47.6062, longitude: -122.3321)
    let denver = SavedLocation(name: "Denver, CO", latitude: 39.7392, longitude: -104.9903)
    let saved = [gps, seattle]
    let canAdd = EntitlementChecker.canAddLocation(locations: saved, isPro: false)
    XCTAssertFalse(canAdd)
    XCTAssertEqual(
      CitySearch.selection(candidate: denver, saved: saved, canAdd: canAdd),
      .paywall
    )
  }

  func testLocationsCopyNamesNearMePlusOneSavedCity() {
    XCTAssertEqual(LocationsCopy.freeLimitChip, "Free includes Near Me + 1 saved city")
    XCTAssertTrue(LocationsCopy.freeLimitChip.contains("Near Me"))
    XCTAssertTrue(LocationsCopy.freeLimitChip.contains("1 saved city"))
    XCTAssertEqual(LocationsCopy.saveUnlimitedCTA, PaywallFeature.locations.headline)
    XCTAssertEqual(DayCastAccessibility.Locations.freeLimitChip, "daycast.locations.freeLimit")
    XCTAssertEqual(
      DayCastAccessibility.Locations.deleteSaved("Seattle, WA"),
      "daycast.locations.delete.Seattle, WA")
  }

  func testFreeUserGetsNeitherAINorYearlyExtras() {
    XCTAssertFalse(
      GrokAccessRules.canUseGrokAI(
        isPro: false, proxyConfigured: true, hasDeveloperKey: false))
    XCTAssertFalse(
      DayCastEntitlements.canUseYearlyExtras(isYearly: false, hasDeveloperKey: false))
    XCTAssertFalse(
      GrokAccessRules.canUseWidgetGrokBrief(
        isYearly: false,
        isPro: false,
        proxyConfigured: true,
        hasDeveloperKey: false
      ))
  }
}
