import XCTest

@testable import DayCast

/// The gate contract from `docs/1.0.5-AI-GATE-SCOPE.md`, as a truth table.
///
/// These rules decide whether a call is billed to us, so they get exhaustive
/// coverage rather than spot checks.
final class GrokAccessRulesTests: XCTestCase {

  // MARK: - canUseGrokAI

  func testFreeUserCannotUseAI() {
    XCTAssertFalse(
      GrokAccessRules.canUseGrokAI(isPro: false, proxyConfigured: true, hasDeveloperKey: false))
  }

  func testProWithDeployedProxyCanUseAI() {
    XCTAssertTrue(
      GrokAccessRules.canUseGrokAI(isPro: true, proxyConfigured: true, hasDeveloperKey: false))
  }

  func testProWithoutDeployedProxyCannotUseAI() {
    // Claiming access with nowhere to send the request would fail every call.
    XCTAssertFalse(
      GrokAccessRules.canUseGrokAI(isPro: true, proxyConfigured: false, hasDeveloperKey: false))
  }

  func testOwnKeyWorksWithoutProOrProxy() {
    // The user pays for their own key, so nothing needs to gate it.
    XCTAssertTrue(
      GrokAccessRules.canUseGrokAI(isPro: false, proxyConfigured: false, hasDeveloperKey: true))
  }

  // MARK: - Tier resolution

  func testProRoutesThroughTheProxyEvenWithAnOwnKey() {
    // Otherwise the daily counter would stop reflecting the people we meter.
    XCTAssertEqual(
      GrokAccessRules.tier(isPro: true, proxyConfigured: true, hasDeveloperKey: true), .pro)
  }

  func testProFallsBackToOwnKeyWhenTheProxyIsNotDeployed() {
    XCTAssertEqual(
      GrokAccessRules.tier(isPro: true, proxyConfigured: false, hasDeveloperKey: true),
      .developerKey)
  }

  func testFreeUserWithNoKeyHasNoTier() {
    XCTAssertNil(GrokAccessRules.tier(isPro: false, proxyConfigured: true, hasDeveloperKey: false))
  }

  func testTierAgreesWithCanUseGrokAIAcrossEveryCombination() {
    for isPro in [true, false] {
      for proxyConfigured in [true, false] {
        for hasDeveloperKey in [true, false] {
          let allowed = GrokAccessRules.canUseGrokAI(
            isPro: isPro, proxyConfigured: proxyConfigured, hasDeveloperKey: hasDeveloperKey)
          let tier = GrokAccessRules.tier(
            isPro: isPro, proxyConfigured: proxyConfigured, hasDeveloperKey: hasDeveloperKey)

          XCTAssertEqual(
            allowed, tier != nil,
            "isPro=\(isPro) proxy=\(proxyConfigured) key=\(hasDeveloperKey): access and routing disagree"
          )
        }
      }
    }
  }

  // MARK: - Widget + morning brief

  func testWidgetBriefRequiresProEvenWithAnOwnKey() {
    // The widget surface is itself a Pro feature.
    XCTAssertFalse(
      GrokAccessRules.canUseWidgetGrokBrief(
        isPro: false, proxyConfigured: false, hasDeveloperKey: true))
    XCTAssertTrue(
      GrokAccessRules.canUseWidgetGrokBrief(
        isPro: true, proxyConfigured: true, hasDeveloperKey: false))
  }

  func testMorningBriefFollowsTheChatRule() {
    XCTAssertFalse(
      GrokAccessRules.canUseMorningBrief(
        isPro: false, proxyConfigured: true, hasDeveloperKey: false))
    XCTAssertTrue(
      GrokAccessRules.canUseMorningBrief(
        isPro: false, proxyConfigured: false, hasDeveloperKey: true))
  }
}
