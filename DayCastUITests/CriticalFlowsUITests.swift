import XCTest

/// Highest-value smoke flows for DayCast (post–App Store).
/// Run against a Debug simulator build with network + location available.
final class CriticalFlowsUITests: DayCastUITestCase {

  // MARK: - 1. Cold launch → Today shows weather

  func testLaunchShowsTodayWeather() throws {
    XCTAssertTrue(waitForTabBar(), "Tab bar did not appear after launch")

    // City lives on the chip bar (`daycast.today.location` on the selected chip).
    let locationCandidates = [
      app.buttons.matching(NSPredicate(format: "identifier == %@", "daycast.today.location")),
      app.staticTexts.matching(NSPredicate(format: "identifier == %@", "daycast.today.location")),
      app.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "daycast.locations.chip.")),
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

  // MARK: - 2b. National radar motion tracks, not cone wedges

  func testNationalRadarSelectsNationalComposite() throws {
    XCTAssertTrue(waitForTabBar())
    openTab(.radar)

    let layers = app.buttons["Layers"]
    XCTAssertTrue(layers.waitForExistence(timeout: 15), "Layers missing")
    layers.tap()

    let national = app.buttons["National radar"]
    XCTAssertTrue(national.waitForExistence(timeout: 8), "National radar product missing")
    national.tap()

    let done = app.buttons["Done"]
    if done.waitForExistence(timeout: 4) { done.tap() }

    let nationalHUD = app.staticTexts["National radar"]
    XCTAssertTrue(
      nationalHUD.waitForExistence(timeout: 12),
      "HUD did not switch to National radar"
    )
    XCTAssertFalse(app.staticTexts["Mosaic"].waitForExistence(timeout: 1))

    XCTAssertTrue(layers.waitForExistence(timeout: 6))
    layers.tap()
    let siteDoppler = app.buttons["Site Doppler"]
    XCTAssertTrue(siteDoppler.waitForExistence(timeout: 8), "Site Doppler product missing")
    siteDoppler.tap()
    if done.waitForExistence(timeout: 4) { done.tap() }
    XCTAssertFalse(
      app.staticTexts["Mosaic"].waitForExistence(timeout: 3),
      "Site Doppler HUD still says Mosaic"
    )
  }

  // MARK: - 3. Sky Check entry from More

  func testStormSpotterCTAExistsInBriefingStudio() throws {
    XCTAssertTrue(waitForTabBar())

    // The More hub is the only in-app path into the Grok tab (it has no CompactTabBar item).
    openMoreHubThen(.grok)

    let analyze = app.buttons["Check this sky"]
    let stormHeader = app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS[c] %@", "SKY CHECK")
    ).firstMatch

    let sawCTA = analyze.waitForExistence(timeout: 12)
    let sawHeader = stormHeader.waitForExistence(timeout: 4)

    XCTAssertTrue(
      sawCTA || sawHeader,
      "Sky Check analysis entry point missing from Sky Check"
    )

    // Tap CTA only far enough to confirm it is hittable (system photo picker may appear).
    if sawCTA {
      XCTAssertTrue(analyze.isHittable)
    }
  }

  // MARK: - 3b. Sky Check composer sits above CompactTabBar

  func testSkyCheckComposerIsHittableAboveTabBar() throws {
    XCTAssertTrue(waitForTabBar())
    openMoreHubThen(.grok)

    let field = skyCheckChatField()
    XCTAssertTrue(field.waitForExistence(timeout: 12), "Sky Check chat field missing")
    XCTAssertTrue(waitForHittable(field, timeout: 6), "Chat field is not hittable")

    let radar = app.buttons[Tab.radar.identifier]
    let more = app.buttons[Tab.more.identifier]
    XCTAssertTrue(radar.waitForExistence(timeout: 4), "Radar tab missing")
    XCTAssertTrue(more.exists, "More tab missing")
    XCTAssertTrue(radar.isHittable, "Radar tab should stay hittable with keyboard down")

    XCTAssertLessThanOrEqual(
      field.frame.maxY,
      radar.frame.minY + 4,
      "Composer overlaps the Radar tab (field.maxY \(field.frame.maxY) radar.minY \(radar.frame.minY))"
    )
    XCTAssertLessThanOrEqual(
      field.frame.maxY,
      more.frame.minY + 4,
      "Composer overlaps the More tab"
    )
    saveSkyCheckStill(named: "01-keyboard-down.jpg")

    field.tap()
    XCTAssertTrue(
      app.keyboards.element.waitForExistence(timeout: 6),
      "Keyboard did not appear after focusing the composer"
    )
    XCTAssertTrue(field.isHittable, "Composer should ride the keyboard")
    XCTAssertFalse(
      radar.isHittable,
      "CompactTabBar should hide while the Sky Check field is focused"
    )
    saveSkyCheckStill(named: "02-keyboard-up.jpg")
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

  private func skyCheckChatField() -> XCUIElement {
    app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@", "daycast.grok.chatField")
    ).firstMatch
  }

  private func saveSkyCheckStill(named filename: String) {
    let dir = URL(
      fileURLWithPath:
        "/Users/bigstevedev/Projects/GrokCast/scratch/sky-check-chat-ux-2026-08-24"
    )
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    guard let data = XCUIScreen.main.screenshot().image.jpegData(compressionQuality: 0.8) else {
      return
    }
    try? data.write(to: dir.appendingPathComponent(filename))
  }

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
