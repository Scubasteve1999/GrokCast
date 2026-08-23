import XCTest

@testable import DayCast

final class AlertsHonestyTests: XCTestCase {

  func testOutlookOnlyIsNotAWarningCount() {
    let chrome = AlertsHonesty.chrome(nwsAlertCount: 0, hasSevereProducts: true)

    XCTAssertEqual(chrome.screenTitle, "Outlook")
    XCTAssertFalse(chrome.showsActiveNow)
    XCTAssertEqual(chrome.noActiveAlertsCaption, "No active alerts")
    XCTAssertEqual(chrome.tabSymbolName, "bell.fill")
    XCTAssertEqual(chrome.tabAccessibilityLabel, "Alerts")
    XCTAssertEqual(chrome.tabAccessibilityValue, "No active alerts")
    XCTAssertEqual(chrome.screenAccessibilityLabel, "Outlook")

    XCTAssertFalse(chrome.tabSymbolName.contains("badge"))
    XCTAssertFalse(chrome.tabAccessibilityValue?.contains("1") == true)
    XCTAssertNotEqual(chrome.tabAccessibilityValue, AlertsHonesty.nwsCountPhrase(1))
    XCTAssertFalse(chrome.screenAccessibilityLabel.localizedCaseInsensitiveContains("1 active"))
  }

  func testWarningCityKeepsActiveNowAndHonestCount() {
    let one = AlertsHonesty.chrome(nwsAlertCount: 1, hasSevereProducts: true)
    XCTAssertEqual(one.screenTitle, "Alerts")
    XCTAssertTrue(one.showsActiveNow)
    XCTAssertNil(one.noActiveAlertsCaption)
    XCTAssertEqual(one.tabSymbolName, "bell.badge.fill")
    XCTAssertEqual(one.tabAccessibilityValue, "1 active alert")
    XCTAssertEqual(one.screenAccessibilityLabel, "Alerts. 1 active alert")

    let many = AlertsHonesty.chrome(nwsAlertCount: 3, hasSevereProducts: false)
    XCTAssertTrue(many.showsActiveNow)
    XCTAssertEqual(many.tabAccessibilityValue, "3 active alerts")
    XCTAssertEqual(many.screenTitle, "Alerts")
  }

  func testEmptyAlertsTabHasNoBadgeOrCount() {
    let chrome = AlertsHonesty.chrome(nwsAlertCount: 0, hasSevereProducts: false)
    XCTAssertEqual(chrome.screenTitle, "Alerts")
    XCTAssertFalse(chrome.showsActiveNow)
    XCTAssertNil(chrome.noActiveAlertsCaption)
    XCTAssertEqual(chrome.tabSymbolName, "bell.fill")
    XCTAssertNil(chrome.tabAccessibilityValue)
    XCTAssertEqual(chrome.screenAccessibilityLabel, "Alerts")
  }

  func testTabSymbolFollowsNWSCountOnly() {
    XCTAssertEqual(AlertsHonesty.tabSymbolName(nwsAlertCount: 0), "bell.fill")
    XCTAssertEqual(AlertsHonesty.tabSymbolName(nwsAlertCount: 2), "bell.badge.fill")
  }

  func testTodaySlotOutlookOnlyIsNotAWarningList() {
    XCTAssertEqual(AlertsHonesty.todaySlotTitle(nwsAlertCount: 0), "Severe outlook")
    XCTAssertEqual(AlertsHonesty.todaySlotAccessibility(nwsAlertCount: 0), "Severe outlook")
    XCTAssertFalse(
      AlertsHonesty.todaySlotAccessibility(nwsAlertCount: 0)
        .localizedCaseInsensitiveContains("1 active")
    )
  }

  func testTodaySlotWarningCityKeepsActiveAlerts() {
    XCTAssertEqual(AlertsHonesty.todaySlotTitle(nwsAlertCount: 1), "Active Alerts")
    XCTAssertEqual(
      AlertsHonesty.todaySlotAccessibility(nwsAlertCount: 1),
      "Active Alerts. 1 active alert"
    )
    XCTAssertEqual(
      AlertsHonesty.todaySlotAccessibility(nwsAlertCount: 2),
      "Active Alerts. 2 active alerts"
    )
  }

  func testNegativeNWSCountIsTreatedAsZero() {
    let chrome = AlertsHonesty.chrome(nwsAlertCount: -1, hasSevereProducts: true)
    XCTAssertFalse(chrome.showsActiveNow)
    XCTAssertEqual(chrome.screenTitle, "Outlook")
    XCTAssertEqual(chrome.tabSymbolName, "bell.fill")
  }
}
