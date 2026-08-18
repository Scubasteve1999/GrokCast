import XCTest

@testable import DayCast

final class NWSAlertTests: XCTestCase {

  private func makeAlert(
    event: String = "Special Weather Statement",
    severity: String? = nil,
    expires: Date? = nil
  ) -> NWSAlert {
    NWSAlert(
      id: "test",
      event: event,
      severity: severity,
      headline: nil,
      description: nil,
      instruction: nil,
      expires: expires,
      areaDesc: nil,
      latitude: nil,
      longitude: nil
    )
  }

  // MARK: - severityLevel

  func testSeverityLevelExtremeIsFour() {
    XCTAssertEqual(makeAlert(severity: "Extreme").severityLevel, 4)
  }

  func testSeverityLevelSevereIsThree() {
    XCTAssertEqual(makeAlert(severity: "Severe").severityLevel, 3)
  }

  func testSeverityLevelModerateIsTwo() {
    XCTAssertEqual(makeAlert(severity: "Moderate").severityLevel, 2)
  }

  func testSeverityLevelMinorIsOne() {
    XCTAssertEqual(makeAlert(severity: "Minor").severityLevel, 1)
  }

  func testSeverityLevelUnknownIsZero() {
    XCTAssertEqual(makeAlert(severity: nil).severityLevel, 0)
    XCTAssertEqual(makeAlert(severity: "Unknown").severityLevel, 0)
  }

  func testSeverityLevelIsCaseInsensitive() {
    XCTAssertEqual(makeAlert(severity: "EXTREME").severityLevel, 4)
    XCTAssertEqual(makeAlert(severity: "severe").severityLevel, 3)
  }

  // MARK: - isWarning / isWatch

  func testIsWarningTrueForWarningEvent() {
    XCTAssertTrue(makeAlert(event: "Tornado Warning").isWarning)
    XCTAssertTrue(makeAlert(event: "Flash Flood Warning").isWarning)
    XCTAssertTrue(makeAlert(event: "Winter Storm Warning").isWarning)
  }

  func testIsWarningFalseForNonWarning() {
    XCTAssertFalse(makeAlert(event: "Dense Fog Advisory").isWarning)
    XCTAssertFalse(makeAlert(event: "Tornado Watch").isWarning)
  }

  func testIsWatchTrueForWatchEvent() {
    XCTAssertTrue(makeAlert(event: "Tornado Watch").isWatch)
    XCTAssertTrue(makeAlert(event: "Severe Thunderstorm Watch").isWatch)
  }

  func testIsWatchFalseWhenEventIsAlsoAWarning() {
    // An event containing both "watch" and "warning" must not be classified as a watch.
    XCTAssertFalse(makeAlert(event: "Tornado Warning Watch").isWatch)
  }

  func testIsWatchFalseForAdvisory() {
    XCTAssertFalse(makeAlert(event: "Wind Advisory").isWatch)
  }

  func testIsWarningIsCaseInsensitive() {
    XCTAssertTrue(makeAlert(event: "TORNADO WARNING").isWarning)
  }

  // MARK: - isSevereEvent

  func testIsSevereEventTrueForWarning() {
    XCTAssertTrue(makeAlert(event: "Winter Storm Warning").isSevereEvent)
  }

  func testIsSevereEventTrueForWatch() {
    XCTAssertTrue(makeAlert(event: "Winter Storm Watch").isSevereEvent)
  }

  func testIsSevereEventFalseForAdvisory() {
    XCTAssertFalse(makeAlert(event: "Freeze Advisory").isSevereEvent)
  }

  func testIsSevereEventFalseForStatement() {
    XCTAssertFalse(makeAlert(event: "Special Weather Statement").isSevereEvent)
  }

  // MARK: - isLifeThreatening

  func testTornadoWarningIsLifeThreatening() {
    XCTAssertTrue(makeAlert(event: "Tornado Warning").isLifeThreatening)
  }

  func testHurricaneWarningIsLifeThreatening() {
    XCTAssertTrue(makeAlert(event: "Hurricane Warning").isLifeThreatening)
  }

  func testExtremeWindWarningIsLifeThreatening() {
    XCTAssertTrue(makeAlert(event: "Extreme Wind Warning").isLifeThreatening)
  }

  func testFlashFloodEmergencyIsLifeThreatening() {
    XCTAssertTrue(makeAlert(event: "Flash Flood Emergency").isLifeThreatening)
  }

  func testExtremeSeverityIsLifeThreatening() {
    XCTAssertTrue(makeAlert(event: "Blizzard Warning", severity: "Extreme").isLifeThreatening)
  }

  func testSevereThunderstormWarningIsNotLifeThreatening() {
    XCTAssertFalse(makeAlert(event: "Severe Thunderstorm Warning", severity: "Severe").isLifeThreatening)
  }

  // MARK: - isExpired

  func testIsExpiredFalseWhenNoExpiresDate() {
    XCTAssertFalse(makeAlert().isExpired)
  }

  func testIsExpiredTrueForPastExpiry() {
    let past = Date(timeIntervalSinceNow: -3600)
    XCTAssertTrue(makeAlert(expires: past).isExpired)
  }

  func testIsExpiredFalseForFutureExpiry() {
    let future = Date(timeIntervalSinceNow: 3600)
    XCTAssertFalse(makeAlert(expires: future).isExpired)
  }

  // MARK: - AlertsLoadState

  func testAlertsLoadStatePendingUntilThisCityIsAttempted() {
    let seattle = UUID()
    XCTAssertEqual(
      AlertsLoadState.resolve(
        currentLocationID: seattle, attemptedLocationID: nil, lastSucceeded: false),
      .pending)
    XCTAssertEqual(
      AlertsLoadState.resolve(
        currentLocationID: seattle, attemptedLocationID: UUID(), lastSucceeded: true),
      .pending)
  }

  func testAlertsLoadStateLoadedOnlyAfterSuccessForThisCity() {
    let seattle = UUID()
    XCTAssertEqual(
      AlertsLoadState.resolve(
        currentLocationID: seattle, attemptedLocationID: seattle, lastSucceeded: true),
      .loaded)
  }

  func testAlertsLoadStateFailedDoesNotLookLikeAllClear() {
    let seattle = UUID()
    XCTAssertEqual(
      AlertsLoadState.resolve(
        currentLocationID: seattle, attemptedLocationID: seattle, lastSucceeded: false),
      .failed)
  }
}
