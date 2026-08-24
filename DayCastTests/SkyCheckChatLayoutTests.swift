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

  func testThreadTopSafeAreaUsesReportedStatusBarInset() {
    XCTAssertEqual(SkyCheckChatChrome.threadTopSafeArea(safeAreaTop: 59), 59)
    XCTAssertEqual(SkyCheckChatChrome.threadTopSafeArea(safeAreaTop: 47), 47)
    XCTAssertGreaterThan(
      SkyCheckChatChrome.threadTopSafeArea(safeAreaTop: 59),
      DesignTokens.Layout.topPadding
    )
  }

  func testThreadTopSafeAreaDoesNotCollapseToContentPaddingWhenReportedZero() {
    let inset = SkyCheckChatChrome.threadTopSafeArea(safeAreaTop: 0)
    XCTAssertGreaterThan(inset, DesignTokens.Layout.topPadding)
    XCTAssertGreaterThanOrEqual(inset, 47)
  }

  func testAssistantMarkdownInsertsSpaceAfterSentenceBeforeEmphasis() throws {
    let raw = "Olive Branch, MS.**Watch next:** General thunderstorms"
    let display = SkyCheckMessageDisplay.markdown(raw)
    XCTAssertTrue(display.contains("MS. **Watch next:**"))
    XCTAssertFalse(display.contains("MS.**W"))

    let attributed = try AttributedString(markdown: display)
    let rendered = String(attributed.characters)
    XCTAssertTrue(rendered.contains("MS. Watch next:"))
    XCTAssertFalse(rendered.contains("MS.Watch"))
  }

  func testAssistantMarkdownInsertsSpaceWhenEmphasisStartsOnNextParagraph() throws {
    let raw = """
      listed in the current data for Olive Branch, MS.

      **Watch next:** General thunderstorms
      """
    let display = SkyCheckMessageDisplay.markdown(raw)
    XCTAssertTrue(display.contains("MS. **Watch next:**"))
    XCTAssertFalse(display.contains("MS.\n"))

    let attributed = try AttributedString(markdown: display)
    let rendered = String(attributed.characters)
    XCTAssertTrue(rendered.contains("MS. Watch next:"))
    XCTAssertFalse(rendered.contains("MS.Watch"))
  }
}
