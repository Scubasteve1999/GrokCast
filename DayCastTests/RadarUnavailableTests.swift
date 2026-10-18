import CoreLocation
import XCTest

@testable import DayCast

final class RadarUnavailableTests: XCTestCase {
  func testControlsLookDisabledWhenTilesAreMissing() {
    XCTAssertFalse(
      RadarChromeCopy.controlsInteractive(hasContent: false, isLoading: false))
    XCTAssertTrue(
      RadarChromeCopy.controlsInteractive(hasContent: false, isLoading: true))
    XCTAssertTrue(
      RadarChromeCopy.controlsInteractive(hasContent: true, isLoading: false))
    XCTAssertTrue(
      RadarChromeCopy.controlsInteractive(
        hasContent: false, isLoading: false, hasCompletedLoadAttempt: false))
  }

  func testUnavailableOverlayWaitsForAFinishedLoad() {
    XCTAssertFalse(
      RadarChromeCopy.showsUnavailableOverlay(
        hasContent: false, isLoading: false, hasCompletedLoadAttempt: false))
    XCTAssertFalse(
      RadarChromeCopy.showsUnavailableOverlay(
        hasContent: false, isLoading: true, hasCompletedLoadAttempt: false))
    XCTAssertFalse(
      RadarChromeCopy.showsUnavailableOverlay(
        hasContent: false, isLoading: true, hasCompletedLoadAttempt: true))
    XCTAssertTrue(
      RadarChromeCopy.showsUnavailableOverlay(
        hasContent: false, isLoading: false, hasCompletedLoadAttempt: true))
    XCTAssertFalse(
      RadarChromeCopy.showsUnavailableOverlay(
        hasContent: true, isLoading: false, hasCompletedLoadAttempt: true))
  }

  func testDockTabBarClearanceMatchesCompactChromeNotScrollClearance() {
    XCTAssertEqual(WeatherStageSheet.tabBarClearance, CompactTabBar.chromeHeight)
    XCTAssertEqual(WeatherStageSheet.tabBarClearance, 69)
    XCTAssertLessThan(
      WeatherStageSheet.tabBarClearance, DesignTokens.Layout.tabBarScrollClearance)
    XCTAssertEqual(DesignTokens.Layout.tabBarScrollClearance, 96)
    XCTAssertEqual(WeatherStageSheet.topRadius, DesignTokens.Radius.xLarge)
  }

  func testUnavailableCopyNamesRetryWithoutBuryingTheState() {
    XCTAssertEqual(RadarChromeCopy.unavailableTitle, "Radar unavailable")
    XCTAssertFalse(RadarChromeCopy.unavailableHint.isEmpty)
    XCTAssertEqual(RadarChromeCopy.unavailableRetry, "Retry")
    XCTAssertEqual(DayCastAccessibility.Radar.unavailableCard, "daycast.radar.unavailable")
    XCTAssertEqual(
      DayCastAccessibility.Radar.unavailableRetry, "daycast.radar.unavailableRetry")
  }

  // MARK: - Xweather outage handling

  private func resetXweatherProbes() {
    XweatherRadarService.invalidateProbeCache()
  }

  private func key(_ layer: XweatherRadarLayer, _ offset: String) -> String {
    XweatherRadarService.probeCacheKey(layer: layer, offset: offset, retina: true)
  }

  func testMapsAreAssumedHealthyUntilProbed() {
    resetXweatherProbes()
    defer { resetXweatherProbes() }
    XCTAssertTrue(XweatherRadarService.mapsHealthy(future: false))
    XCTAssertTrue(XweatherRadarService.mapsHealthy(future: true))
  }

  func testLiveIsDownOnlyWhenBothLiveLayersFailed() {
    resetXweatherProbes()
    defer { resetXweatherProbes() }
    XweatherRadarService.storeProbe(false, for: key(.radarGlobal, "current"))
    XCTAssertTrue(
      XweatherRadarService.mapsHealthy(future: false), "radar was never probed")
    XweatherRadarService.storeProbe(false, for: key(.radar, "current"))
    XCTAssertFalse(XweatherRadarService.mapsHealthy(future: false))
    XCTAssertTrue(
      XweatherRadarService.mapsHealthy(future: true), "a Live outage is not a 12-hr outage")

    XweatherRadarService.storeProbe(true, for: key(.radarGlobal, "current"))
    XCTAssertTrue(XweatherRadarService.mapsHealthy(future: false))
  }

  func testFutureIsDownWhenTheForecastProbeFailed() {
    resetXweatherProbes()
    defer { resetXweatherProbes() }
    XweatherRadarService.storeProbe(false, for: key(.fradar, "+1hour"))
    XCTAssertFalse(XweatherRadarService.mapsHealthy(future: true))
    XCTAssertTrue(XweatherRadarService.mapsHealthy(future: false))
  }

  func testTwelveHourMapsGLStaysOffWhenHRRROwnsTheTimeline() {
    resetXweatherProbes()
    defer { resetXweatherProbes() }
    // Unprobed (or a failure aged out of its cache) counts as healthy, which is exactly
    // when MapsGL used to cover the HRRR frames with an empty Xweather layer.
    XCTAssertTrue(XweatherRadarService.mapsHealthy(future: true))
    XCTAssertFalse(MapsGLRadarHost.isUsable(future: true, forecastProvider: .hrrr))
    XCTAssertFalse(MapsGLRadarHost.isUsable(future: true, forecastProvider: nil))
    XCTAssertEqual(
      MapsGLRadarHost.isUsable(future: true, forecastProvider: .xweather),
      MapsGLRadarHost.isUsable(future: true))
    XCTAssertEqual(
      MapsGLRadarHost.isUsable(future: false, forecastProvider: .hrrr),
      MapsGLRadarHost.isUsable(future: false), "Live is not affected by the forecast source")
  }

  func testMapsGLIsNotUsableWhileTheProbeIsFailing() {
    resetXweatherProbes()
    defer { resetXweatherProbes() }
    XweatherRadarService.storeProbe(false, for: key(.radarGlobal, "current"))
    XweatherRadarService.storeProbe(false, for: key(.radar, "current"))
    XweatherRadarService.storeProbe(false, for: key(.fradar, "+1hour"))
    XCTAssertFalse(MapsGLRadarHost.isUsable(future: false))
    XCTAssertFalse(MapsGLRadarHost.isUsable(future: true))
    // The PNG path (MRMS / IEM / RainViewer) takes over instead of staying hidden.
    XCTAssertFalse(
      MapsGLRadarPalette.shouldUseMapsGL(
        overlayOn: true, isSiteProduct: false,
        keysPresent: MapsGLRadarHost.isUsable(future: false)))
    XCTAssertEqual(
      RadarPreviewPaint.resolve(
        hoisted: false, hasDrawableSweep: false, mapboxPresent: true,
        mapsGLKeysPresent: MapsGLRadarHost.isUsable(future: false)),
      .nationalTiles)
  }

  func testOutageCopyNamesNoProviderKeyOrQuota() {
    for copy in [
      RadarChromeCopy.futureTemporarilyUnavailable,
      RadarChromeCopy.radarTemporarilyUnavailable,
      RadarChromeCopy.lightningTemporarilyUnavailable,
    ] {
      XCTAssertTrue(copy.localizedCaseInsensitiveContains("temporarily"), copy)
      for forbidden in ["xweather", "key", "quota", "http", "developer"] {
        XCTAssertFalse(copy.localizedCaseInsensitiveContains(forbidden), copy)
      }
    }
  }

  @MainActor
  func testChipNoteExplainsAGreyedOutTwelveHour() {
    let state = RadarState()
    state.setForecastAvailabilityForTesting(
      .unavailable(message: RadarChromeCopy.futureTemporarilyUnavailable))
    XCTAssertTrue(state.forecastIsTemporarilyUnavailable)
    XCTAssertFalse(state.hasFutureFrames)
    let footer = state.statusFooterContent
    XCTAssertEqual(footer.text, RadarChromeCopy.futureTemporarilyUnavailable)
    XCTAssertEqual(footer.style, .warning)
  }

  @MainActor
  func testChipNoteSaysTwelveHourIsUSOnlyOutsideCoverage() {
    let state = RadarState()
    state.setForecastAvailabilityForTesting(.unavailable(message: RadarChromeCopy.futureUSOnly))
    XCTAssertFalse(state.forecastIsTemporarilyUnavailable, "a coverage gap is not an outage")
    XCTAssertEqual(state.statusFooterContent.text, RadarChromeCopy.futureUSOnly)
    XCTAssertEqual(state.statusFooterContent.style, .warning)
  }

  func testUSOnlyMessageOnlyAppliesOutsideCONUS() {
    let memphis = CLLocationCoordinate2D(latitude: 35.15, longitude: -90.05)
    let london = CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12)
    XCTAssertNil(RadarLoader.forecastOutsideCoverageMessage(coordinate: memphis))
    XCTAssertNil(RadarLoader.forecastOutsideCoverageMessage(coordinate: nil))
    XCTAssertEqual(
      RadarLoader.forecastOutsideCoverageMessage(coordinate: london), RadarChromeCopy.futureUSOnly)
    for forbidden in ["temporarily", "xweather", "key", "quota"] {
      XCTAssertFalse(RadarChromeCopy.futureUSOnly.localizedCaseInsensitiveContains(forbidden))
    }
  }

  @MainActor
  func testChipNoteIgnoresThePreLoadPlaceholder() {
    let state = RadarState()
    XCTAssertFalse(state.forecastIsTemporarilyUnavailable)
    XCTAssertNotEqual(state.statusFooterContent.text, RadarChromeCopy.futureTemporarilyUnavailable)
  }
}
