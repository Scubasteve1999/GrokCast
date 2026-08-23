import XCTest

@testable import DayCast

final class AlertsHonestyTests: XCTestCase {

  func testOutlookOnlyIsNotAWarningCount() {
    let chrome = AlertsHonesty.chrome(nwsAlertCount: 0, hasSevereProducts: true)

    XCTAssertEqual(chrome.screenTitle, "Severe Outlook")
    XCTAssertFalse(chrome.showsActiveNow)
    XCTAssertNil(chrome.riskCaption)
    XCTAssertEqual(chrome.noActiveAlertsCaption, "No active NWS alerts")
    XCTAssertEqual(chrome.tabSymbolName, "bell.fill")
    XCTAssertEqual(chrome.tabAccessibilityLabel, "Alerts")
    XCTAssertEqual(chrome.tabAccessibilityValue, "No active NWS alerts")
    XCTAssertEqual(chrome.screenAccessibilityLabel, "Severe Outlook. No active NWS alerts")

    XCTAssertFalse(chrome.tabSymbolName.contains("badge"))
    XCTAssertNotEqual(chrome.tabAccessibilityValue, AlertsHonesty.nwsCountPhrase(1))
    XCTAssertFalse(chrome.tabAccessibilityValue?.localizedCaseInsensitiveContains("1 active") == true)
    XCTAssertFalse(chrome.screenAccessibilityLabel.localizedCaseInsensitiveContains("1 active"))
  }

  func testOutlookOnlyLeadsWithDay1RiskCaption() {
    let slight = AlertsHonesty.chrome(
      nwsAlertCount: 0,
      hasSevereProducts: true,
      outlookSummary: "Day 1 Slight · HAIL 15% · WIND 15%"
    )
    XCTAssertEqual(slight.screenTitle, "Severe Outlook")
    XCTAssertEqual(slight.riskCaption, "Day 1 Slight · HAIL 15% · WIND 15%")
    XCTAssertEqual(slight.noActiveAlertsCaption, "No active NWS alerts")
    XCTAssertFalse(slight.showsActiveNow)
    XCTAssertEqual(slight.tabSymbolName, "bell.fill")
    XCTAssertEqual(
      slight.tabAccessibilityValue,
      "Day 1 Slight · HAIL 15% · WIND 15%. No active NWS alerts"
    )
    XCTAssertEqual(
      slight.screenAccessibilityLabel,
      "Severe Outlook. Day 1 Slight · HAIL 15% · WIND 15%. No active NWS alerts"
    )
    XCTAssertFalse(slight.screenAccessibilityLabel.localizedCaseInsensitiveContains("1 active"))
    XCTAssertNotEqual(slight.tabAccessibilityValue, AlertsHonesty.nwsCountPhrase(1))

    let tstm = AlertsHonesty.chrome(
      nwsAlertCount: 0,
      hasSevereProducts: true,
      outlookSummary: "Day 1 Thunderstorm"
    )
    XCTAssertEqual(tstm.riskCaption, "Day 1 Thunderstorm")
    XCTAssertEqual(
      tstm.screenAccessibilityLabel,
      "Severe Outlook. Day 1 Thunderstorm. No active NWS alerts"
    )
    XCTAssertFalse(tstm.screenAccessibilityLabel.localizedCaseInsensitiveContains("1 active"))
  }

  func testWarningCityKeepsActiveNowAndHonestCount() {
    let one = AlertsHonesty.chrome(
      nwsAlertCount: 1,
      hasSevereProducts: true,
      outlookSummary: "Day 1 Slight · HAIL 15% · WIND 15%"
    )
    XCTAssertEqual(one.screenTitle, "Alerts")
    XCTAssertTrue(one.showsActiveNow)
    XCTAssertNil(one.riskCaption)
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
    XCTAssertNil(chrome.riskCaption)
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
    XCTAssertEqual(AlertsHonesty.todayOutlookCardHeading, "Severe Outlook")
    XCTAssertEqual(AlertsHonesty.todaySlotAccessibility(nwsAlertCount: 0), "Severe outlook")
    XCTAssertEqual(
      AlertsHonesty.todaySlotAccessibility(
        nwsAlertCount: 0,
        outlookSummary: "Day 1 Slight · HAIL 15% · WIND 15%"
      ),
      "Severe outlook. Day 1 Slight · HAIL 15% · WIND 15%"
    )
    XCTAssertFalse(
      AlertsHonesty.todaySlotAccessibility(
        nwsAlertCount: 0,
        outlookSummary: "Day 1 Slight · HAIL 15% · WIND 15%"
      )
      .localizedCaseInsensitiveContains("1 active")
    )
  }

  func testTodaySlotWarningCityKeepsActiveAlerts() {
    XCTAssertEqual(AlertsHonesty.todaySlotTitle(nwsAlertCount: 1), "Active Alerts")
    XCTAssertEqual(
      AlertsHonesty.todaySlotAccessibility(
        nwsAlertCount: 1,
        outlookSummary: "Day 1 Slight"
      ),
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
    XCTAssertEqual(chrome.screenTitle, "Severe Outlook")
    XCTAssertEqual(chrome.tabSymbolName, "bell.fill")
  }
}
