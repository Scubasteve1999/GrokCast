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
      DayCastEntitlements.canRenderHomeScreenWidgets(isYearlySubscriber: false))
    XCTAssertFalse(
      WidgetDataStore.canRenderWeather(isYearlySubscriber: false))
    XCTAssertTrue(
      DayCastEntitlements.canRenderHomeScreenWidgets(isYearlySubscriber: true))
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
      DayCastEntitlements.canRenderHomeScreenWidgets(isYearlySubscriber: monthly.isYearly))
  }

  func testYearlyResolvedEntitlementUnlocksWidgetSurface() {
    let yearly = DayCastProProducts.resolvedEntitlement(productIDs: [
      DayCastProProducts.yearly
    ])
    XCTAssertTrue(yearly.isYearly)
    XCTAssertTrue(
      DayCastEntitlements.canRenderHomeScreenWidgets(isYearlySubscriber: yearly.isYearly))
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
