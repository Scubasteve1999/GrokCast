import XCTest

@testable import DayCast

final class PaywallPeriodTests: XCTestCase {
  private let ascBlurb = "AI, forecast radar, Live Activity, unlimited locations"

  func testProductIDsAreUnchanged() {
    XCTAssertEqual(
      DayCastProProducts.monthly, "com.scubasteve1999.DayCast.pro.monthly")
    XCTAssertEqual(
      DayCastProProducts.yearly, "com.scubasteve1999.DayCast.pro.yearly")
  }

  func testMonthlyTitleAndInclusionComeFromTheProductID() {
    let id = DayCastProProducts.monthly
    XCTAssertEqual(PaywallPeriodCopy.period(forProductID: id), .monthly)
    XCTAssertEqual(PaywallPeriodCopy.title(forProductID: id), "Monthly")
    XCTAssertEqual(PaywallPeriodCopy.billedLine(forProductID: id), "Billed monthly")
    XCTAssertEqual(PaywallPeriodCopy.subtitle(productID: id), PaywallPeriodCopy.monthlyInclusion)
    XCTAssertEqual(
      PaywallPeriodCopy.monthlyInclusion,
      "AI and unlimited locations. Billed monthly."
    )
    XCTAssertEqual(
      PaywallPeriodCopy.subscribeTitle(productID: id, displayPrice: "$2.99"),
      "Subscribe monthly — $2.99"
    )
  }

  func testYearlyTitleAndInclusionComeFromTheProductID() {
    let id = DayCastProProducts.yearly
    XCTAssertEqual(PaywallPeriodCopy.period(forProductID: id), .yearly)
    XCTAssertEqual(PaywallPeriodCopy.title(forProductID: id), "Yearly")
    XCTAssertEqual(PaywallPeriodCopy.billedLine(forProductID: id), "Billed yearly")
    XCTAssertEqual(PaywallPeriodCopy.subtitle(productID: id), PaywallPeriodCopy.yearlyInclusion)
    XCTAssertEqual(
      PaywallPeriodCopy.yearlyInclusion,
      "AI, locations, Future radar, widgets, Live Activity. Billed yearly."
    )
    XCTAssertEqual(
      PaywallPeriodCopy.subscribeTitle(productID: id, displayPrice: "$29.99"),
      "Subscribe yearly — $29.99"
    )
  }

  func testInclusionLinesDifferAndAreNotTheASCBlurb() {
    let monthly = PaywallPeriodCopy.subtitle(productID: DayCastProProducts.monthly)
    let yearly = PaywallPeriodCopy.subtitle(productID: DayCastProProducts.yearly)
    XCTAssertNotEqual(monthly, yearly)
    XCTAssertFalse(monthly.contains(ascBlurb))
    XCTAssertFalse(yearly.contains(ascBlurb))
    XCTAssertFalse(monthly.localizedCaseInsensitiveContains("Future"))
    XCTAssertFalse(monthly.localizedCaseInsensitiveContains("widget"))
    XCTAssertFalse(monthly.localizedCaseInsensitiveContains("Live Activity"))
    XCTAssertTrue(yearly.contains("Future radar"))
    XCTAssertTrue(yearly.contains("widgets"))
    XCTAssertTrue(yearly.contains("Live Activity"))
  }

  func testUnknownIDFallsBackWithoutInventingAPeriod() {
    XCTAssertNil(PaywallPeriodCopy.title(forProductID: "com.example.other"))
    XCTAssertEqual(PaywallPeriodCopy.subtitle(productID: "com.example.other"), "")
    XCTAssertEqual(
      PaywallPeriodCopy.subscribeTitle(productID: "com.example.other", displayPrice: "$1.00"),
      "Subscribe — $1.00"
    )
  }

  func testSavingsLineIsHonestAndSilentWhenYearlyIsNotCheaper() {
    XCTAssertEqual(
      PaywallPeriodCopy.savingsLine(
        monthlyPrice: Decimal(string: "2.99")!,
        yearlyPrice: Decimal(string: "29.99")!,
        formattedSavings: "$5.89"
      ),
      "Save $5.89 vs 12 months"
    )
    XCTAssertNil(
      PaywallPeriodCopy.savingsLine(
        monthlyPrice: Decimal(string: "2.99")!,
        yearlyPrice: Decimal(string: "35.88")!,
        formattedSavings: "$0.00"
      )
    )
  }

  func testLiveActivityCopyNamesYearlyNotPro() {
    XCTAssertEqual(PaywallPeriodCopy.liveActivityRequiresYearly, "Requires Yearly")
    XCTAssertFalse(
      PaywallPeriodCopy.liveActivityRequiresYearly.localizedCaseInsensitiveContains("Pro"))
  }

  func testLocationsSubheadlineDoesNotPromiseWidgetsOnMonthly() {
    let copy = PaywallFeature.locations.subheadline
    XCTAssertFalse(copy.localizedCaseInsensitiveContains("widget"))
    XCTAssertTrue(copy.contains("Today and Radar"))
    XCTAssertTrue(copy.contains("Monthly or Yearly"))
  }
}
