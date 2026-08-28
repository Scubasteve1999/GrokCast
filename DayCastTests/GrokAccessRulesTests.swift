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

  func testMoreHubDoesNotTellProUsersToAddAKey() {
    let allowed = GrokAccessRules.canUseGrokAI(
      isPro: true, proxyConfigured: true, hasDeveloperKey: false)
    XCTAssertTrue(allowed)
    XCTAssertEqual(
      GrokAccessRules.moreHubGrokSubtitle(canUseAI: allowed),
      "Ask about your weather. Photo check when you want.")
    XCTAssertFalse(
      GrokAccessRules.moreHubGrokSubtitle(canUseAI: allowed)
        .localizedCaseInsensitiveContains("key"))
  }

  func testMoreHubLockedCopyPointsAtProNotSettings() {
    let copy = GrokAccessRules.moreHubGrokSubtitle(canUseAI: false)
    XCTAssertEqual(copy, "Included with DayCast Pro")
    XCTAssertFalse(copy.localizedCaseInsensitiveContains("Settings"))
  }

  func testLockedAlertsSummaryCopyIsNotKeyOnly() {
    let copy = GrokAccessRules.lockedAlertsSummaryCopy
    XCTAssertTrue(copy.contains("DayCast Pro"))
    XCTAssertTrue(copy.localizedCaseInsensitiveContains("xAI key"))
  }

  func testMoreTabStaysSelectedOnHubDestinations() {
    XCTAssertTrue(CompactTab.more.isSelected(for: .locations))
    XCTAssertTrue(CompactTab.more.isSelected(for: .settings))
    XCTAssertTrue(CompactTab.more.isSelected(for: .grok))
    XCTAssertFalse(CompactTab.more.isSelected(for: .today))
    XCTAssertNil(CompactTab.more.weatherTab)
  }

  func testCompactPrimaryTabDoesNotCreateASixthPage() {
    XCTAssertEqual(CompactTab.primary(for: .today), .today)
    XCTAssertEqual(CompactTab.primary(for: .forecast), .forecast)
    XCTAssertEqual(CompactTab.primary(for: .radar), .radar)
    XCTAssertEqual(CompactTab.primary(for: .alerts), .alerts)
    XCTAssertEqual(CompactTab.primary(for: .grok), .more)
    XCTAssertEqual(CompactTab.primary(for: .locations), .more)
    XCTAssertEqual(CompactTab.primary(for: .settings), .more)
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

  func testWidgetBriefIsYearlyOrDeveloperKey() {
    // Monthly Pro is not enough. Developer key is full access.
    XCTAssertFalse(
      GrokAccessRules.canUseWidgetGrokBrief(
        isYearly: false, isPro: true, proxyConfigured: true, hasDeveloperKey: false))
    XCTAssertTrue(
      GrokAccessRules.canUseWidgetGrokBrief(
        isYearly: true, isPro: true, proxyConfigured: true, hasDeveloperKey: false))
    XCTAssertTrue(
      GrokAccessRules.canUseWidgetGrokBrief(
        isYearly: false, isPro: false, proxyConfigured: false, hasDeveloperKey: true))
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
