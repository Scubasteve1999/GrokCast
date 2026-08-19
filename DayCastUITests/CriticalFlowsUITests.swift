import XCTest

/// Highest-value smoke flows for DayCast (post–App Store).
/// Run against a Debug simulator build with network + location available.
final class CriticalFlowsUITests: DayCastUITestCase {

  // MARK: - 1. Cold launch → Today shows weather

  func testLaunchShowsTodayWeather() throws {
    XCTAssertTrue(waitForTabBar(), "Tab bar did not appear after launch")

    // Hero location or temperature should be visible once weather loads.
    let locationCandidates = [
      app.staticTexts.matching(NSPredicate(format: "identifier == %@", "daycast.today.location")),
      app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", ".+, [A-Z]{2}")),
    ]

    var sawLocation = false
    for query in locationCandidates {
      if query.firstMatch.waitForExistence(timeout: 15) {
        sawLocation = true
        break
      }
    }

    // Temperature-like label (digits + degree) as secondary signal.
    let temp = app.staticTexts.matching(
      NSPredicate(format: "label MATCHES %@", "[0-9]{1,3}°")
    ).firstMatch
    let sawTemp = temp.waitForExistence(timeout: sawLocation ? 2 : 15)

    XCTAssertTrue(
      sawLocation || sawTemp,
      "Today did not show a location or temperature after launch"
    )
  }

  // MARK: - 2. Radar tab opens with chrome

  func testRadarTabShowsLiveControls() throws {
    XCTAssertTrue(waitForTabBar())
    openTab(.radar)

    let live = app.buttons["Live radar"]
    let rain = app.staticTexts["Live"]
    let recenter = app.buttons["Recenter to selected location"]

    let sawLive = live.waitForExistence(timeout: 15)
    let sawRain = rain.waitForExistence(timeout: 8)
    let sawRecenter = recenter.waitForExistence(timeout: 8)

    XCTAssertTrue(
      sawLive || sawRain || sawRecenter,
      "Radar chrome missing (Live / Recenter)"
    )
  }

  // MARK: - 3. Storm Spotter entry from Briefing Studio

  func testStormSpotterCTAExistsInBriefingStudio() throws {
    XCTAssertTrue(waitForTabBar())

    // The More hub is the only in-app path into the Grok tab (it has no CompactTabBar item).
    openMoreHubThen(.grok)

    let analyze = app.buttons["Analyze Storm Photo"]
    let stormHeader = app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS[c] %@", "STORM SPOTTER")
    ).firstMatch

    let sawCTA = analyze.waitForExistence(timeout: 12)
    let sawHeader = stormHeader.waitForExistence(timeout: 4)

    XCTAssertTrue(
      sawCTA || sawHeader,
      "Storm Spotter analysis entry point missing from Briefing Studio"
    )

    // Tap CTA only far enough to confirm it is hittable (system photo picker may appear).
    if sawCTA {
      XCTAssertTrue(analyze.isHittable)
    }
  }

  // MARK: - 4. Deep links switch tabs

  func testDeepLinkOpensForecastAndAlerts() throws {
    XCTAssertTrue(waitForTabBar())

    // Open via Safari-style URL using XCUIApplication.open — iOS 16+.
    openDeepLink("daycast://forecast")
    XCTAssertTrue(
      app.staticTexts["FORECAST"].waitForExistence(timeout: 8)
        || app.staticTexts["Forecast"].waitForExistence(timeout: 2)
        || app.buttons[Tab.forecast.identifier].isSelected,
      "Forecast deep link did not land on Forecast"
    )

    openDeepLink("daycast://alerts")
    XCTAssertTrue(
      app.staticTexts["Alerts"].waitForExistence(timeout: 8)
        || app.buttons[Tab.alerts.identifier].isSelected
        || app.staticTexts["No Alerts"].waitForExistence(timeout: 4),
      "Alerts deep link did not land on Alerts"
    )
  }

  // MARK: - 5. Paywall presents from Settings

  func testPaywallCanPresentFromSettings() throws {
    XCTAssertTrue(waitForTabBar())
    openMoreHubThen(.settings)

    // Prefer the stable identifier; fall back to the label for older builds.
    let candidates = [
      app.buttons["daycast.settings.pro"],
      app.buttons["View DayCast Pro"],
      app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "DayCast Pro"))
        .firstMatch,
    ]

    var opened = false
    for element in candidates where element.waitForExistence(timeout: 4) {
      if !element.isHittable {
        app.scrollViews.firstMatch.swipeUp()
      }
      element.tap()
      opened = true
      break
    }

    XCTAssertTrue(opened, "Could not find DayCast Pro entry in Settings")

    let paywallSignal =
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Forecast radar")).firstMatch
      .waitForExistence(timeout: 6)
      || app.buttons["Restore Purchases"].waitForExistence(timeout: 4)
      || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Unlimited saved")).firstMatch
      .waitForExistence(timeout: 4)

    XCTAssertTrue(paywallSignal, "Paywall sheet did not present expected content")
  }

  // MARK: - Helpers

  private func openDeepLink(_ urlString: String) {
    guard let url = URL(string: urlString) else {
      XCTFail("Bad URL \(urlString)")
      return
    }
    app.open(url)
    if !app.wait(for: .runningForeground, timeout: 3) {
      app.activate()
    }
  }
}
