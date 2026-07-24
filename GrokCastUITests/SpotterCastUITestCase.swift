import XCTest

/// Shared launch helpers for SpotterCast UI tests.
/// Prefer accessibility identifiers (`spottercast.*`) over brittle coordinates.
class SpotterCastUITestCase: XCTestCase {
  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments += [
      "-UITesting",
      "-AppleLanguages", "(en)",
      "-AppleLocale", "en_US",
    ]
    // Skip first-run friction when possible; system alerts still need springboard handling.
    app.launch()
    dismissSystemAlertsIfNeeded()
  }

  override func tearDownWithError() throws {
    app = nil
  }

  /// Dismiss iOS permission sheets that can block the first screen.
  func dismissSystemAlertsIfNeeded() {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let buttons = ["Allow While Using App", "Allow", "OK", "Don’t Allow", "Don't Allow"]
    for title in buttons {
      let button = springboard.buttons[title]
      if button.waitForExistence(timeout: 1.5) {
        button.tap()
        return
      }
    }
  }

  @discardableResult
  func waitForTabBar(timeout: TimeInterval = 12) -> Bool {
    app.buttons["Today"].waitForExistence(timeout: timeout)
  }

  func openTab(_ title: String) {
    let tab = app.buttons[title]
    XCTAssertTrue(tab.waitForExistence(timeout: 8), "Missing tab: \(title)")
    tab.tap()
  }

  func openMoreHubThen(_ destination: String) {
    openTab("More")
    let row = app.buttons[destination]
    if row.waitForExistence(timeout: 3) {
      row.tap()
      return
    }
    // Fallback: static text row inside SettingsNavigationRow
    let text = app.staticTexts[destination]
    XCTAssertTrue(text.waitForExistence(timeout: 5), "Missing More hub row: \(destination)")
    text.tap()
  }
}
