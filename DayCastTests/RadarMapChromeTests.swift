import XCTest

@testable import DayCast

final class RadarMapChromeTests: XCTestCase {
  func testMapDoesNotImposeFourHundredPointFloor() {
    XCTAssertFalse(RadarMapChromeLayout.imposesMinimumMapSize)
  }

  func testFieldOverlaysShareMeasuredPanelInset() {
    let panelHeight: CGFloat = 188
    let inset = RadarMapChromeLayout.fieldOverlayBottomInset(controlPanelHeight: panelHeight)
    XCTAssertEqual(
      inset,
      WeatherStageSheet.tabBarClearance + panelHeight + RadarMapChromeLayout.overlayGap
    )
    XCTAssertEqual(WeatherStageSheet.tabBarClearance, CompactTabBar.chromeHeight)
    XCTAssertNotEqual(inset, 72, "layer rail must not use the old hardcoded 72pt inset")
  }

  func testLiveSourceToggleIsSiteAndNationalOnly() {
    XCTAssertTrue(RadarLiveSourceChrome.showsToggle(showsFuture: false))
    XCTAssertFalse(RadarLiveSourceChrome.showsToggle(showsFuture: true))
    XCTAssertEqual(
      RadarLiveSourceChrome.liveProducts,
      [.superResReflectivity, .reflectivity]
    )
    XCTAssertFalse(RadarLiveSourceChrome.liveProducts.contains(.stormRelativeVelocity))
    XCTAssertTrue(
      RadarLiveSourceChrome.isSelected(
        .superResReflectivity, current: .superResReflectivity))
    XCTAssertTrue(
      RadarLiveSourceChrome.isSelected(
        .superResReflectivity, current: .stormRelativeVelocity),
      "Storm winds is still a site scan — Site chip stays selected"
    )
    XCTAssertFalse(
      RadarLiveSourceChrome.isSelected(.reflectivity, current: .stormRelativeVelocity))
    XCTAssertTrue(
      RadarLiveSourceChrome.isSelected(.reflectivity, current: .reflectivity))
    XCTAssertTrue(
      RadarLiveSourceChrome.isDisabled(.superResReflectivity, siteAvailable: false))
    XCTAssertFalse(
      RadarLiveSourceChrome.isDisabled(.superResReflectivity, siteAvailable: true))
    XCTAssertFalse(RadarLiveSourceChrome.isDisabled(.reflectivity, siteAvailable: false))
  }
}
