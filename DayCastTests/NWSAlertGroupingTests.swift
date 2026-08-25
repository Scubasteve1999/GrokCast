import XCTest

@testable import DayCast

final class NWSAlertGroupingTests: XCTestCase {

  func testTwoAirQualityFeaturesCollapseToOneRepresentative() {
    let expires = Date().addingTimeInterval(6 * 3600)
    let county = aqi(id: "county", expires: expires, instruction: nil)
    let zone = aqi(id: "zone", expires: expires, instruction: "Limit outdoor activity.")
    let groups = NWSAlertGrouping.grouped(from: [county, zone])
    XCTAssertEqual(groups.count, 1)
    XCTAssertEqual(groups[0].members.count, 2)
    XCTAssertEqual(groups[0].representative.id, "zone")
    XCTAssertEqual(NWSAlertGrouping.representatives(from: [county, zone]).count, 1)
    XCTAssertEqual(NWSAlertGrouping.uniqueEvents(from: [county, zone]), ["Air Quality Alert"])
  }

  func testDifferentEventsStaySeparate() {
    let expires = Date().addingTimeInterval(6 * 3600)
    let aqiAlert = aqi(id: "aqi", expires: expires)
    let heat = makeAlert(
      id: "heat",
      event: "Heat Advisory",
      severity: "Moderate",
      expires: expires
    )
    let reps = NWSAlertGrouping.representatives(from: [aqiAlert, heat])
    XCTAssertEqual(reps.map(\.event), ["Air Quality Alert", "Heat Advisory"])
  }

  func testExpiresOnDifferentDaysDoNotCollapse() {
    let calendar = Calendar(identifier: .gregorian)
    let day1 = calendar.startOfDay(for: Date())
    let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!
    let first = aqi(id: "d1", expires: day1.addingTimeInterval(12 * 3600))
    let second = aqi(id: "d2", expires: day2.addingTimeInterval(12 * 3600))
    XCTAssertEqual(NWSAlertGrouping.representatives(from: [first, second]).count, 2)
  }

  func testHigherSeverityWins() {
    let expires = Date().addingTimeInterval(3600)
    let minor = makeAlert(
      id: "minor", event: "Flood Warning", severity: "Minor", expires: expires)
    let extreme = makeAlert(
      id: "extreme", event: "Flood Warning", severity: "Extreme",
      expires: expires, instruction: "Move to higher ground.")
    XCTAssertEqual(
      NWSAlertGrouping.representatives(from: [minor, extreme]).first?.id, "extreme")
  }

  func testNormalizedEventIgnoresCaseAndSpacing() {
    XCTAssertEqual(
      NWSAlertGrouping.normalizedEvent("Air Quality Alert"),
      NWSAlertGrouping.normalizedEvent("AIR  QUALITY\nALERT")
    )
  }

  private func aqi(
    id: String,
    expires: Date,
    instruction: String? = nil
  ) -> NWSAlert {
    makeAlert(
      id: id,
      event: "Air Quality Alert",
      severity: "Moderate",
      expires: expires,
      instruction: instruction
    )
  }

  private func makeAlert(
    id: String,
    event: String,
    severity: String?,
    expires: Date?,
    instruction: String? = nil
  ) -> NWSAlert {
    NWSAlert(
      id: id,
      event: event,
      severity: severity,
      headline: nil,
      description: nil,
      instruction: instruction,
      expires: expires,
      areaDesc: nil,
      latitude: nil,
      longitude: nil
    )
  }
}
