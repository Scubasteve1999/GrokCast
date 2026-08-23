import XCTest

/// Shared launch helpers for DayCast UI tests.
/// Prefer accessibility identifiers (`daycast.*`) over brittle coordinates.
class DayCastUITestCase: XCTestCase {
  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments += [
      "-UITesting",
      "-AppleLanguages", "(en)",
      "-AppleLocale", "en_US",
    ]
    app.launch()
    grantLocationPermissionIfPrompted()
    completeOnboardingIfNeeded()
  }

  override func tearDownWithError() throws {
    app = nil
  }

  // MARK: - First run

  /// Grant the iOS location prompt. Never taps a "Don't Allow" variant — a denial
  /// leaves `TodayView` on `LocationPermissionView` for the rest of the run.
  func grantLocationPermissionIfPrompted(timeout: TimeInterval = 3) {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    for title in ["Allow While Using App", "Allow Once", "Allow", "OK"] {
      let button = springboard.buttons[title]
      if button.waitForExistence(timeout: timeout) {
        button.tap()
        return
      }
    }
  }

  /// Walk the first-launch welcome card → pre-permission sheet → system prompt so
  /// Today can reach real content. After Allow the store auto-calls
  /// `useCurrentDeviceLocation()` once (sim GPS is Olive Branch). Denied stays
  /// on LocationPermissionView — never a silent default city.
  func completeOnboardingIfNeeded() {
    let getStarted = app.buttons["Get Started"]
    if getStarted.waitForExistence(timeout: 5) {
      getStarted.tap()

      let cont = app.buttons["Continue"]
      if cont.waitForExistence(timeout: 5) {
        cont.tap()
        grantLocationPermissionIfPrompted(timeout: 5)
      }
    }

    // Reached when the welcome card was already dismissed but permission is still
    // .notDetermined (e.g. a previous test in the same run tapped through).
    let enable = firstExistingButton(
      [
        "daycast.today.enableLocation",
        "Enable location",
        "ENABLE LOCATION",
      ], timeout: 2)
    if let enable {
      enable.tap()
      grantLocationPermissionIfPrompted(timeout: 5)
    }
  }

  // MARK: - Tab bar

  /// Mirrors `DayCastAccessibility.Tabs` / `.MoreHub` in the app target.
  /// The app hides the system tab bar (`.toolbar(.hidden, for: .tabBar)`) but it
  /// stays in the accessibility tree, so plain label queries such as
  /// `app.buttons["Radar"]` match both it and our `CompactTabBar` and fail to tap.
  enum Tab: String {
    case today, forecast, radar, alerts, more

    var identifier: String { "daycast.tab.\(rawValue)" }
  }

  /// Raw values are `WeatherStore.Tab.rawValue` — note Storm Spotter's is "AI".
  enum MoreHubDestination: String {
    case grok = "AI"
    case locations = "Locations"
    case settings = "Settings"

    var identifier: String { "daycast.moreHub.\(rawValue)" }
  }

  @discardableResult
  func waitForTabBar(timeout: TimeInterval = 12) -> Bool {
    app.buttons[Tab.today.identifier].waitForExistence(timeout: timeout)
  }

  func openTab(_ tab: Tab) {
    let element = app.buttons[tab.identifier]
    XCTAssertTrue(element.waitForExistence(timeout: 8), "Missing tab: \(tab.rawValue)")
    element.tap()
  }

  func openMoreHubThen(_ destination: MoreHubDestination) {
    openTab(.more)
    let row = app.buttons[destination.identifier]
    XCTAssertTrue(
      row.waitForExistence(timeout: 5),
      "Missing More hub row: \(destination.rawValue)"
    )

    // The hub is a `.medium` detent sheet. A tap issued while it is still
    // animating in resolves against stale coordinates and silently misses,
    // leaving the hub open — so wait for the row to settle and retry.
    for _ in 0..<3 {
      guard waitForHittable(row) else { break }
      row.tap()
      if waitForDisappearance(row) { return }
    }

    XCTFail("More hub row \(destination.rawValue) did not dismiss the hub")
  }

  // MARK: - Waiting

  private func firstExistingButton(_ titles: [String], timeout: TimeInterval) -> XCUIElement? {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      for title in titles {
        let button = app.buttons[title]
        if button.exists { return button }
      }
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    return nil
  }

  func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
    XCTWaiter.wait(
      for: [
        XCTNSPredicateExpectation(
          predicate: NSPredicate(format: "isHittable == true"), object: element)
      ],
      timeout: timeout
    ) == .completed
  }

  func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
    XCTWaiter.wait(
      for: [
        XCTNSPredicateExpectation(
          predicate: NSPredicate(format: "exists == false"), object: element)
      ],
      timeout: timeout
    ) == .completed
  }
}
