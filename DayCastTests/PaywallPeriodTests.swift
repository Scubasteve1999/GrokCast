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
      "AI, locations, widgets, Live Activity. Billed monthly."
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
    XCTAssertTrue(monthly.contains("widgets"))
    XCTAssertTrue(monthly.contains("Live Activity"))
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

  func testLiveActivityCopyNamesProNotYearly() {
    XCTAssertEqual(PaywallPeriodCopy.liveActivityRequiresPro, "Requires Pro")
    XCTAssertFalse(
      PaywallPeriodCopy.liveActivityRequiresPro.localizedCaseInsensitiveContains("Yearly"))
    XCTAssertTrue(PaywallFeature.liveActivity.subheadline.hasPrefix("DayCast Pro shows"))
    XCTAssertFalse(PaywallFeature.liveActivity.subheadline.contains("Yearly"))
  }

  func testPlanCopyKeepsOnlyFutureRadarYearlyExclusive() {
    let pitch = PaywallPeriodCopy.generalProPitch
    XCTAssertEqual(
      pitch,
      "Monthly and Yearly include AI, unlimited locations, widgets, and Live Activity. Yearly adds 12-hr Future radar."
    )
    let severe = PaywallFeature.severeAlerts.subheadline
    XCTAssertTrue(severe.contains("DayCast Pro adds AI, extra locations, widgets, and Live Activity."))
    XCTAssertTrue(severe.hasSuffix("Yearly adds Future radar."))
    for copy in [pitch, severe] {
      XCTAssertFalse(copy.contains("Yearly adds Future radar, widgets"), copy)
    }
    XCTAssertTrue(PaywallFeature.radarFuture.subheadline.hasPrefix("Yearly unlocks 12-hr"))
  }

  func testLocationsPaywallCopyNamesFreeLimitAndProUnlimited() {
    XCTAssertEqual(PaywallFeature.locations.headline, "Save unlimited places")
    let copy = PaywallFeature.locations.subheadline
    XCTAssertEqual(
      copy,
      "Free includes Near Me + 1 saved city. DayCast Pro unlocks unlimited places so you can switch between home, work, and the next storm. Weather, radar, and NWS stay free."
    )
    XCTAssertFalse(copy.localizedCaseInsensitiveContains("widget"))
    XCTAssertFalse(copy.localizedCaseInsensitiveContains("Yearly"))
    XCTAssertTrue(copy.contains("DayCast Pro"))
    XCTAssertTrue(copy.contains("Near Me"))
    XCTAssertTrue(copy.contains("1 saved city"))
  }

  func testSettingsEntryUsesGeneralProPaywallNotLocations() {
    XCTAssertEqual(PaywallFeature.settingsEntry, .dayCastPro)
    XCTAssertNotEqual(PaywallFeature.settingsEntry, .locations)
    XCTAssertEqual(PaywallFeature.dayCastPro.headline, "DayCast Pro")
    XCTAssertEqual(PaywallFeature.dayCastPro.analyticsName, "daycast_pro")

    let copy = PaywallFeature.dayCastPro.subheadline
    XCTAssertTrue(copy.contains(PaywallPeriodCopy.generalProPitch))
    XCTAssertTrue(copy.contains(PaywallPeriodCopy.officialWeatherStaysFree))
    XCTAssertTrue(copy.contains("Monthly"))
    XCTAssertTrue(copy.contains("Yearly"))
    XCTAssertTrue(copy.contains("Future radar"))
    XCTAssertFalse(copy.contains("Save unlimited places"))
    XCTAssertFalse(copy.hasPrefix("Free includes Near Me"))
  }

  func testActivePlanUnlockCopyMatchesMonthlyAndYearlyTiers() {
    XCTAssertEqual(PaywallPeriodCopy.activePlanTitle(isYearly: false), "Monthly")
    XCTAssertEqual(PaywallPeriodCopy.activePlanTitle(isYearly: true), "Yearly")
    XCTAssertEqual(
      PaywallPeriodCopy.activePlanUnlocks(isYearly: false),
      PaywallPeriodCopy.monthlyUnlocks
    )
    XCTAssertEqual(
      PaywallPeriodCopy.activePlanUnlocks(isYearly: true),
      PaywallPeriodCopy.yearlyUnlocks
    )
    XCTAssertEqual(PaywallPeriodCopy.monthlyUnlocks, "AI, locations, widgets, Live Activity")
    XCTAssertEqual(
      PaywallPeriodCopy.yearlyUnlocks,
      "AI, locations, Future radar, widgets, Live Activity"
    )
    XCTAssertFalse(PaywallPeriodCopy.monthlyUnlocks.localizedCaseInsensitiveContains("Future"))
    XCTAssertTrue(PaywallPeriodCopy.monthlyUnlocks.contains("widgets"))
    XCTAssertTrue(PaywallPeriodCopy.monthlyUnlocks.contains("Live Activity"))
    XCTAssertTrue(PaywallPeriodCopy.yearlyUnlocks.contains("Future radar"))
    XCTAssertTrue(PaywallPeriodCopy.yearlyUnlocks.contains("widgets"))
    XCTAssertTrue(PaywallPeriodCopy.yearlyUnlocks.contains("Live Activity"))
  }
}
