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

  func testAppGroupIdentifierStaysDayCast() {
    XCTAssertEqual(WidgetAppGroup.identifier, "group.com.scubasteve1999.DayCast")
  }

  func testSnapshotStillWritesLegacyGrokWireKeys() throws {
    let data = try JSONEncoder().encode(WidgetWeatherSnapshot.preview)
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    XCTAssertEqual(object["grokCastScore"] as? Int, 82)
    XCTAssertEqual(object["grokCastScoreLabel"] as? String, "Go Outside")
    XCTAssertEqual(
      object["grokBriefOneLiner"] as? String,
      "Light jacket this morning; great afternoon for a walk.")

    let decoded = try JSONDecoder().decode(WidgetWeatherSnapshot.self, from: data)
    XCTAssertEqual(decoded.grokCastScore, 82)
    XCTAssertEqual(decoded.grokCastScoreLabel, "Go Outside")
    XCTAssertEqual(
      decoded.grokBriefOneLiner,
      "Light jacket this morning; great afternoon for a walk.")
  }

  func testCircularGaugeRangeKeepsLowBelowHigh() {
    XCTAssertEqual(WidgetWeatherSnapshot.preview.circularGaugeRange, 62...78)
    XCTAssertTrue(
      WidgetWeatherSnapshot.preview.circularGaugeRange.lowerBound
        < WidgetWeatherSnapshot.preview.circularGaugeRange.upperBound)
  }

  func testCircularGaugeRangeOrdersInvertedHighLow() {
    let snapshot = glanceSnapshot(low: 80, high: 60)
    XCTAssertEqual(snapshot.circularGaugeRange, 60...80)
  }

  func testCircularGaugeRangeWidensEqualHighLow() {
    let snapshot = glanceSnapshot(low: 70, high: 70)
    XCTAssertTrue(snapshot.circularGaugeRange.lowerBound < snapshot.circularGaugeRange.upperBound)
    XCTAssertEqual(snapshot.circularGaugeRange, 70...71)
  }

  func testLiveActivityStandardChromePrefersConditionAndTemp() {
    let state = liveState(variant: .standard)
    XCTAssertEqual(WeatherLiveActivityChrome.compactTrailingText(for: state), "72°")
    XCTAssertEqual(WeatherLiveActivityChrome.lockScreenPrimary(for: state), "Mainly Clear")
    XCTAssertEqual(
      WeatherLiveActivityChrome.lockScreenSecondary(for: state), "Dry for the next 2 hours")
    XCTAssertEqual(WeatherLiveActivityChrome.expandedPrimary(for: state), "Mainly Clear")
    XCTAssertEqual(
      WeatherLiveActivityChrome.expandedSecondary(for: state), "Dry for the next 2 hours")
    assertGlanceChromeOmitsScore(state)
  }

  func testLiveActivityRadarChromeDropsScoreLine() {
    let state = liveState(
      variant: .radarEvent,
      headline: "Rain Starting Soon",
      detail: "Rain within 20 minutes")
    XCTAssertEqual(WeatherLiveActivityChrome.compactTrailingText(for: state), "72°")
    XCTAssertEqual(WeatherLiveActivityChrome.lockScreenPrimary(for: state), "Rain Starting Soon")
    XCTAssertEqual(WeatherLiveActivityChrome.lockScreenSecondary(for: state), "Rain within 20 minutes")
    XCTAssertEqual(WeatherLiveActivityChrome.expandedPrimary(for: state), "Rain within 20 minutes")
    XCTAssertNil(WeatherLiveActivityChrome.expandedSecondary(for: state))
    assertGlanceChromeOmitsScore(state)
  }

  func testLiveActivitySevereChromeFallsBackToDetailNotScore() {
    let state = liveState(
      variant: .severeAlert,
      headline: "Tornado Warning",
      detail: "Until 8 PM")
    XCTAssertEqual(WeatherLiveActivityChrome.compactTrailingText(for: state), "!")
    XCTAssertEqual(WeatherLiveActivityChrome.lockScreenPrimary(for: state), "Tornado Warning")
    XCTAssertEqual(WeatherLiveActivityChrome.lockScreenSecondary(for: state), "Until 8 PM")
    XCTAssertEqual(WeatherLiveActivityChrome.expandedPrimary(for: state), "Tornado Warning")
    XCTAssertEqual(WeatherLiveActivityChrome.expandedSecondary(for: state), "Until 8 PM")
    assertGlanceChromeOmitsScore(state)
  }

  func testLiveActivitySevereMissingDetailUsesMinutecastNotScore() {
    let state = liveState(variant: .severeAlert, headline: "Severe Thunderstorm Warning")
    XCTAssertEqual(
      WeatherLiveActivityChrome.expandedSecondary(for: state), "Dry for the next 2 hours")
    assertGlanceChromeOmitsScore(state)
  }

  private func assertGlanceChromeOmitsScore(
    _ state: WeatherLiveActivityAttributes.ContentState
  ) {
    let lines = [
      WeatherLiveActivityChrome.compactTrailingText(for: state),
      WeatherLiveActivityChrome.lockScreenPrimary(for: state),
      WeatherLiveActivityChrome.lockScreenSecondary(for: state),
      WeatherLiveActivityChrome.expandedPrimary(for: state),
      WeatherLiveActivityChrome.expandedSecondary(for: state),
    ].compactMap { $0 }
    for line in lines {
      XCTAssertFalse(line.localizedCaseInsensitiveContains("score"), line)
      XCTAssertFalse(line.localizedCaseInsensitiveContains("sparkles"), line)
    }
  }

  private func glanceSnapshot(low: Double, high: Double) -> WidgetWeatherSnapshot {
    WidgetWeatherSnapshot(
      location: .oliveBranch,
      currentTemp: 70,
      conditionText: "Clear",
      symbolName: "sun.max.fill",
      high: high,
      low: low,
      hourly: [],
      fetchedAt: Date(timeIntervalSince1970: 0)
    )
  }

  private func liveState(
    variant: WeatherLiveActivityAttributes.Variant,
    headline: String? = nil,
    detail: String? = nil
  ) -> WeatherLiveActivityAttributes.ContentState {
    WeatherLiveActivityAttributes.ContentState(
      locationName: "Olive Branch",
      temperatureText: "72°",
      conditionText: "Mainly Clear",
      score: 82,
      scoreLabel: "Go Outside",
      minutecastMessage: "Dry for the next 2 hours",
      symbolName: "cloud.sun.fill",
      variant: variant,
      headline: headline,
      detail: detail
    )
  }
}
