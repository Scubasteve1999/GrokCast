import XCTest

@testable import DayCast

final class RadarUnavailableTests: XCTestCase {
  func testControlsLookDisabledWhenTilesAreMissing() {
    XCTAssertFalse(
      RadarChromeCopy.controlsInteractive(hasContent: false, isLoading: false))
    XCTAssertTrue(
      RadarChromeCopy.controlsInteractive(hasContent: false, isLoading: true))
    XCTAssertTrue(
      RadarChromeCopy.controlsInteractive(hasContent: true, isLoading: false))
    XCTAssertTrue(
      RadarChromeCopy.controlsInteractive(
        hasContent: false, isLoading: false, hasCompletedLoadAttempt: false))
  }

  func testUnavailableOverlayWaitsForAFinishedLoad() {
    XCTAssertFalse(
      RadarChromeCopy.showsUnavailableOverlay(
        hasContent: false, isLoading: false, hasCompletedLoadAttempt: false))
    XCTAssertFalse(
      RadarChromeCopy.showsUnavailableOverlay(
        hasContent: false, isLoading: true, hasCompletedLoadAttempt: false))
    XCTAssertFalse(
      RadarChromeCopy.showsUnavailableOverlay(
        hasContent: false, isLoading: true, hasCompletedLoadAttempt: true))
    XCTAssertTrue(
      RadarChromeCopy.showsUnavailableOverlay(
        hasContent: false, isLoading: false, hasCompletedLoadAttempt: true))
    XCTAssertFalse(
      RadarChromeCopy.showsUnavailableOverlay(
        hasContent: true, isLoading: false, hasCompletedLoadAttempt: true))
  }

  func testDockTabBarClearanceMatchesCompactChromeNotScrollClearance() {
    XCTAssertEqual(WeatherStageSheet.tabBarClearance, CompactTabBar.chromeHeight)
    XCTAssertEqual(WeatherStageSheet.tabBarClearance, 69)
    XCTAssertLessThan(
      WeatherStageSheet.tabBarClearance, DesignTokens.Layout.tabBarScrollClearance)
    XCTAssertEqual(DesignTokens.Layout.tabBarScrollClearance, 96)
    XCTAssertEqual(WeatherStageSheet.topRadius, DesignTokens.Radius.xLarge)
  }

  func testUnavailableCopyNamesRetryWithoutBuryingTheState() {
    XCTAssertEqual(RadarChromeCopy.unavailableTitle, "Radar unavailable")
    XCTAssertFalse(RadarChromeCopy.unavailableHint.isEmpty)
    XCTAssertEqual(RadarChromeCopy.unavailableRetry, "Retry")
    XCTAssertEqual(DayCastAccessibility.Radar.unavailableCard, "daycast.radar.unavailable")
    XCTAssertEqual(
      DayCastAccessibility.Radar.unavailableRetry, "daycast.radar.unavailableRetry")
  }
}
