import XCTest

@testable import DayCast

final class AlertsActiveCopyTests: XCTestCase {
  private var chicago: TimeZone {
    TimeZone(identifier: "America/Chicago")!
  }

  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = chicago
    return calendar
  }

  func testGrokFollowsOfficialAlerts() {
    XCTAssertTrue(AlertsActiveCopy.grokFollowsOfficialAlerts)
  }

  func testStateLineLeadsWithPlaceThenCountThenFreshness() {
    let now = date(year: 2026, month: 8, day: 25, hour: 12)
    let checked = now.addingTimeInterval(-120)
    XCTAssertEqual(
      AlertsActiveCopy.stateLine(
        locationName: "Olive Branch, MS",
        nwsCount: 1,
        checkedAt: checked,
        now: now
      ),
      "Olive Branch, MS · 1 active · checked 2m ago"
    )
    XCTAssertEqual(
      AlertsActiveCopy.stateLine(
        locationName: "Olive Branch, MS",
        nwsCount: 2,
        checkedAt: now,
        now: now
      ),
      "Olive Branch, MS · 2 active · checked just now"
    )
    XCTAssertEqual(
      AlertsActiveCopy.stateLine(
        locationName: "Olive Branch, MS",
        nwsCount: 0,
        checkedAt: checked,
        now: now
      ),
      "Olive Branch, MS · checked 2m ago"
    )
    XCTAssertNil(
      AlertsActiveCopy.stateLine(locationName: "  ", nwsCount: 1, checkedAt: now, now: now)
    )
  }

  func testAuthorityLineAlwaysNamesNWSAndTheSafetyState() {
    let now = date(year: 2026, month: 8, day: 25, hour: 12)
    let checked = now.addingTimeInterval(-120)
    XCTAssertEqual(
      AlertsActiveCopy.authorityLine(
        locationName: "Olive Branch, MS",
        nwsCount: 2,
        checkedAt: checked,
        loadState: .loaded,
        hasCachedAlerts: true,
        now: now
      ),
      "NWS · Olive Branch, MS · 2 active · checked 2m ago"
    )
    XCTAssertEqual(
      AlertsActiveCopy.authorityLine(
        locationName: "Olive Branch, MS",
        nwsCount: 0,
        checkedAt: checked,
        loadState: .loaded,
        hasCachedAlerts: false,
        now: now
      ),
      "NWS · Olive Branch, MS · No active alerts · checked 2m ago"
    )
    XCTAssertEqual(
      AlertsActiveCopy.authorityLine(
        locationName: "Olive Branch, MS",
        nwsCount: 1,
        checkedAt: checked,
        loadState: .failed,
        hasCachedAlerts: true,
        now: now
      ),
      "NWS · Olive Branch, MS · Showing cached alerts · last check 2m ago"
    )
    XCTAssertEqual(
      AlertsActiveCopy.authorityLine(
        locationName: nil,
        nwsCount: 0,
        checkedAt: nil,
        loadState: .failed,
        hasCachedAlerts: false,
        now: now
      ),
      "NWS · Unable to refresh"
    )
    XCTAssertEqual(
      AlertsActiveCopy.authorityLine(
        locationName: "Olive Branch, MS",
        nwsCount: 0,
        checkedAt: checked,
        loadState: .failed,
        hasCachedAlerts: false,
        now: now
      ),
      "NWS · Olive Branch, MS · Unable to refresh · last check 2m ago"
    )
    XCTAssertTrue(
      AlertsActiveCopy.authorityLine(
        locationName: "Olive Branch, MS",
        nwsCount: 0,
        checkedAt: nil,
        loadState: .pending,
        hasCachedAlerts: false,
        now: now
      ).contains("Checking alerts")
    )
  }

  func testUntilLineAddsWeekdayWhenExpiryIsNotToday() {
    let now = date(year: 2026, month: 8, day: 25, hour: 12)
    let tonight = date(year: 2026, month: 8, day: 25, hour: 17, minute: 30)
    let tomorrow = date(year: 2026, month: 8, day: 26, hour: 17, minute: 30)
    XCTAssertEqual(
      AlertsActiveCopy.untilLine(
        expires: tonight, areaDesc: "Crittenden, AR", now: now, calendar: calendar,
        timeZone: chicago),
      "Until 5:30 PM · Crittenden, AR"
    )
    XCTAssertEqual(
      AlertsActiveCopy.untilLine(
        expires: tomorrow, areaDesc: "Crittenden, AR; Shelby, TN", now: now,
        calendar: calendar, timeZone: chicago),
      "Until Wed 5:30 PM · Crittenden, AR"
    )
  }

  func testCardBodyPrefersInstructionAndDropsARestatedHeadline() {
    XCTAssertEqual(
      AlertsActiveCopy.cardBody(
        event: "Air Quality Alert",
        headline: "Air Quality Alert issued August 24 at 8:00PM CDT by NWS Memphis TN",
        instruction: "Limit outdoor activity this afternoon.\nMore after that.",
        description: "Ozone will remain elevated."
      ),
      "Limit outdoor activity this afternoon."
    )
    XCTAssertEqual(
      AlertsActiveCopy.cardBody(
        event: "Air Quality Alert",
        headline: "Air Quality Alert issued August 24 at 8:00PM CDT by NWS Memphis TN",
        instruction: nil,
        description: "Ozone will remain elevated."
      ),
      "Ozone will remain elevated."
    )
    XCTAssertNil(
      AlertsActiveCopy.cardBody(
        event: "Air Quality Alert",
        headline: "Air Quality Alert issued August 24 at 8:00PM CDT by NWS Memphis TN",
        instruction: nil,
        description: nil
      )
    )
    XCTAssertEqual(
      AlertsActiveCopy.cardBody(
        event: "Tornado Warning",
        headline: "Tornado Warning for northern DeSoto County",
        instruction: nil,
        description: nil
      ),
      "Tornado Warning for northern DeSoto County"
    )
  }

  func testActiveRowOrderIsActionThenExpiry() {
    XCTAssertEqual(
      AlertsActiveCopy.cardBody(
        event: "Air Quality Alert",
        headline: "Air Quality Alert issued August 24 at 8:00PM CDT by NWS Memphis TN",
        instruction: "Limit outdoor activity this afternoon.",
        description: "Ozone will remain elevated."
      ),
      "Limit outdoor activity this afternoon."
    )
    let now = date(year: 2026, month: 8, day: 25, hour: 12)
    XCTAssertEqual(
      AlertsActiveCopy.untilLine(
        expires: date(year: 2026, month: 8, day: 25, hour: 17, minute: 30),
        areaDesc: "DeSoto, MS",
        now: now,
        calendar: calendar,
        timeZone: chicago
      ),
      "Until 5:30 PM · DeSoto, MS"
    )
  }

  func testHonestyConstantsAreUnchanged() {
    XCTAssertEqual(AlertsHonesty.activeNow, "ACTIVE NOW")
    XCTAssertEqual(AlertsHonesty.tabTitle, "Alerts")
    XCTAssertEqual(AlertsHonesty.noActiveAlerts, "No active NWS alerts")
  }

  func testGrokSummaryErrorDoesNotUseSkyCheckCopy() {
    XCTAssertFalse(
      AlertsActiveCopy.grokSummaryTimedOut.localizedCaseInsensitiveContains("Sky Check"))
    XCTAssertFalse(AlertsActiveCopy.grokSummaryTimedOut.localizedCaseInsensitiveContains("image"))
    XCTAssertFalse(
      AlertsActiveCopy.grokSummaryFailed.localizedCaseInsensitiveContains("Sky Check"))
    XCTAssertEqual(
      AlertsActiveCopy.grokSummaryError(for: URLError(.timedOut), isOffline: false),
      AlertsActiveCopy.grokSummaryTimedOut)
    XCTAssertEqual(
      AlertsActiveCopy.grokSummaryError(for: URLError(.timedOut), isOffline: true),
      AlertsActiveCopy.grokSummaryOffline)

    let raw = NSError(
      domain: "xAI", code: 42,
      userInfo: [NSLocalizedDescriptionKey: "internal token dump xyz"])
    let copy = AlertsActiveCopy.grokSummaryError(for: raw, isOffline: false)
    XCTAssertEqual(copy, AlertsActiveCopy.grokSummaryFailed)
    XCTAssertFalse(copy.contains("token dump"))
    XCTAssertFalse(copy.contains("xyz"))
    XCTAssertFalse(copy.localizedCaseInsensitiveContains("Sky Check"))
  }

  private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
    calendar.date(
      from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
  }
}
