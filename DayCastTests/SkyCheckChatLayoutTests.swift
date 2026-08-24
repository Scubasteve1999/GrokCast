import XCTest

@testable import DayCast

final class SkyCheckChatLayoutTests: XCTestCase {
  func testComposerClearsCompactTabBarWhenUnfocused() {
    XCTAssertEqual(
      SkyCheckChatChrome.tabBarClearance(isCompact: true, isInputFocused: false),
      CompactTabBar.chromeHeight
    )
    XCTAssertGreaterThan(CompactTabBar.chromeHeight, 48)
    XCTAssertLessThan(CompactTabBar.chromeHeight, 96)
  }

  func testComposerDropsTabBarClearanceWhenKeyboardFocused() {
    XCTAssertEqual(
      SkyCheckChatChrome.tabBarClearance(isCompact: true, isInputFocused: true),
      0
    )
  }

  func testRegularWidthNeverAddsCompactTabBarClearance() {
    XCTAssertEqual(
      SkyCheckChatChrome.tabBarClearance(isCompact: false, isInputFocused: false),
      0
    )
    XCTAssertEqual(
      SkyCheckChatChrome.tabBarClearance(isCompact: false, isInputFocused: true),
      0
    )
  }
}
