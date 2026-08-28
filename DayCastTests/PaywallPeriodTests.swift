import XCTest

@testable import DayCast

final class PaywallPeriodTests: XCTestCase {
  private let sharedBlurb = "AI, forecast radar, Live Activity, unlimited locations"

  func testProductIDsAreUnchanged() {
    XCTAssertEqual(
      DayCastProProducts.monthly, "com.scubasteve1999.DayCast.pro.monthly")
    XCTAssertEqual(
      DayCastProProducts.yearly, "com.scubasteve1999.DayCast.pro.yearly")
  }

  func testMonthlyTitleAndBilledLineComeFromTheProductID() {
    let id = DayCastProProducts.monthly
    XCTAssertEqual(PaywallPeriodCopy.period(forProductID: id), .monthly)
    XCTAssertEqual(PaywallPeriodCopy.title(forProductID: id), "Monthly")
    XCTAssertEqual(PaywallPeriodCopy.billedLine(forProductID: id), "Billed monthly")
    XCTAssertEqual(
      PaywallPeriodCopy.subtitle(description: sharedBlurb, productID: id),
      "AI, forecast radar, Live Activity, unlimited locations. Billed monthly."
    )
    XCTAssertEqual(
      PaywallPeriodCopy.subscribeTitle(productID: id, displayPrice: "$2.99"),
      "Subscribe monthly — $2.99"
    )
  }

  func testYearlyTitleAndBilledLineComeFromTheProductID() {
    let id = DayCastProProducts.yearly
    XCTAssertEqual(PaywallPeriodCopy.period(forProductID: id), .yearly)
    XCTAssertEqual(PaywallPeriodCopy.title(forProductID: id), "Yearly")
    XCTAssertEqual(PaywallPeriodCopy.billedLine(forProductID: id), "Billed yearly")
    XCTAssertEqual(
      PaywallPeriodCopy.subtitle(description: sharedBlurb, productID: id),
      "AI, forecast radar, Live Activity, unlimited locations. Billed yearly."
    )
    XCTAssertEqual(
      PaywallPeriodCopy.subscribeTitle(productID: id, displayPrice: "$29.99"),
      "Subscribe yearly — $29.99"
    )
  }

  func testMonthlyAndYearlyTitlesAreDifferentWithTheSameBlurb() {
    XCTAssertNotEqual(
      PaywallPeriodCopy.title(forProductID: DayCastProProducts.monthly),
      PaywallPeriodCopy.title(forProductID: DayCastProProducts.yearly)
    )
    let monthly = PaywallPeriodCopy.subtitle(
      description: sharedBlurb, productID: DayCastProProducts.monthly)
    let yearly = PaywallPeriodCopy.subtitle(
      description: sharedBlurb, productID: DayCastProProducts.yearly)
    XCTAssertTrue(monthly.contains("Billed monthly"))
    XCTAssertTrue(yearly.contains("Billed yearly"))
    XCTAssertTrue(monthly.contains(sharedBlurb))
    XCTAssertTrue(yearly.contains(sharedBlurb))
  }

  func testUnknownIDFallsBackWithoutInventingAPeriod() {
    XCTAssertNil(PaywallPeriodCopy.title(forProductID: "com.example.other"))
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
}
