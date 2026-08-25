import SwiftUI
import XCTest

@testable import DayCast

final class AccessibilityChromeTests: XCTestCase {
  func testMinimumHitTargetIsFortyFour() {
    XCTAssertEqual(DesignTokens.Layout.minHitTarget, 44)
    XCTAssertGreaterThanOrEqual(
      TodayGlanceLayout.alertChipMinHeight, DesignTokens.Layout.minHitTarget)
  }

  func testWeatherModulesUseMaterialOnTheStage() {
    XCTAssertTrue(WeatherModuleChrome.usesMaterialFill)
    XCTAssertEqual(WeatherModuleChrome.strokeOpacity, 0.18, accuracy: 0.001)
    XCTAssertEqual(WeatherModuleChrome.backingOpacity, 0.55, accuracy: 0.001)
    XCTAssertEqual(WeatherModuleChrome.cornerRadius, DesignTokens.Card.cornerRadius)
  }

  func testTabBarChromeHeightStaysCompact() {
    XCTAssertEqual(CompactTabBar.chromeHeight, 69)
    XCTAssertEqual(WeatherStageSheet.tabBarClearance, CompactTabBar.chromeHeight)
  }

  func testMoreHubOpensAtMediumDetentAndCanExpand() {
    XCTAssertEqual(MoreHubPresentation.defaultDetent, PresentationDetent.medium)
    XCTAssertTrue(MoreHubPresentation.availableDetents.contains(.medium))
    XCTAssertTrue(MoreHubPresentation.availableDetents.contains(.large))
    XCTAssertEqual(MoreHubPresentation.availableDetents.count, 2)
  }

  func testPublicPrecipCopyIsNotMinuteCast() {
    XCTAssertEqual(PrecipOutlookCopy.title, "Next 2 Hours")
    XCTAssertFalse(PrecipOutlookCopy.title.localizedCaseInsensitiveContains("minutecast"))
    XCTAssertFalse(
      PrecipOutlookCopy.heroLine(
        summary: MinutecastSummary(
          kind: .clear, message: "Dry for the next 2 hours", icon: "sun.max.fill",
          strip: []),
        rainChance: 0
      ).localizedCaseInsensitiveContains("minutecast"))
  }

  func testLocationChipBarReservedHeightFitsFortyFourPointChips() {
    XCTAssertEqual(LocationChipBar.reservedHeight, 52)
    XCTAssertGreaterThanOrEqual(
      LocationChipBar.reservedHeight,
      DesignTokens.Layout.minHitTarget
    )
  }

  func testLocationAlertDotUsesWarningColorUnlessTheAlertIsAWarning() {
    let advisory = LocationRowWeather.make(
      temperature: 72,
      symbolName: "sun.max.fill",
      hasAlert: true,
      alertIsWarning: false,
      unit: .fahrenheit
    )
    XCTAssertTrue(advisory.hasAlert)
    XCTAssertFalse(advisory.alertIsWarning)

    let warning = LocationRowWeather.make(
      temperature: 72,
      symbolName: "cloud.bolt.fill",
      hasAlert: true,
      alertIsWarning: true,
      unit: .fahrenheit
    )
    XCTAssertTrue(warning.hasAlert)
    XCTAssertTrue(warning.alertIsWarning)

    let clear = LocationRowWeather.make(
      temperature: 72,
      symbolName: "sun.max.fill",
      hasAlert: false,
      alertIsWarning: true,
      unit: .fahrenheit
    )
    XCTAssertFalse(clear.hasAlert)
    XCTAssertFalse(clear.alertIsWarning)
  }

  func testSettingsSectionOrderIsDense() {
    XCTAssertEqual(
      SettingsChrome.sectionTitles,
      [
        "DayCast Pro",
        "Weather",
        "Notifications",
        "Features",
        "Privacy & support",
        "App",
        "Developer",
      ]
    )
    XCTAssertEqual(SettingsChrome.sectionTitles.count, 7)
    XCTAssertEqual(SettingsChrome.sectionTitles.first, "DayCast Pro")
    XCTAssertEqual(SettingsChrome.sectionTitles.last, "Developer")
  }
}
