import XCTest

@testable import DayCast

final class RadarMapChromeTests: XCTestCase {
  func testMapDoesNotImposeFourHundredPointFloor() {
    XCTAssertFalse(RadarMapChromeLayout.imposesMinimumMapSize)
  }

  func testFieldOverlaysShareMeasuredPanelInset() {
    let panelHeight: CGFloat = 188
    let inset = RadarMapChromeLayout.fieldOverlayBottomInset(controlPanelHeight: panelHeight)
    XCTAssertEqual(
      inset,
      WeatherStageSheet.tabBarClearance + panelHeight + RadarMapChromeLayout.overlayGap
    )
    XCTAssertEqual(WeatherStageSheet.tabBarClearance, CompactTabBar.chromeHeight)
    XCTAssertNotEqual(inset, 72, "layer rail must not use the old hardcoded 72pt inset")
  }

  func testLiveSourceToggleIsSiteAndNationalOnly() {
    XCTAssertTrue(RadarLiveSourceChrome.showsToggle(showsFuture: false))
    XCTAssertFalse(RadarLiveSourceChrome.showsToggle(showsFuture: true))
    XCTAssertEqual(
      RadarLiveSourceChrome.liveProducts,
      [.superResReflectivity, .reflectivity]
    )
    XCTAssertFalse(RadarLiveSourceChrome.liveProducts.contains(.stormRelativeVelocity))
    XCTAssertTrue(
      RadarLiveSourceChrome.isSelected(
        .superResReflectivity, current: .superResReflectivity))
    XCTAssertTrue(
      RadarLiveSourceChrome.isSelected(
        .superResReflectivity, current: .stormRelativeVelocity),
      "Storm winds is still a site scan — Site chip stays selected"
    )
    XCTAssertFalse(
      RadarLiveSourceChrome.isSelected(.reflectivity, current: .stormRelativeVelocity))
    XCTAssertTrue(
      RadarLiveSourceChrome.isSelected(.reflectivity, current: .reflectivity))
    XCTAssertTrue(
      RadarLiveSourceChrome.isDisabled(.superResReflectivity, siteAvailable: false))
    XCTAssertFalse(
      RadarLiveSourceChrome.isDisabled(.superResReflectivity, siteAvailable: true))
    XCTAssertFalse(RadarLiveSourceChrome.isDisabled(.reflectivity, siteAvailable: false))
  }

  func testProviderFootersUseSkillNamesNotVendors() {
    let vendors = ["RainViewer", "Xweather", "OpenWeatherMap", "OWM", "MRMS", "Mosaic", "NEXRAD"]
    for provider in RadarTileProvider.allCases {
      XCTAssertEqual(provider.liveFooterLabel, RadarChromeCopy.liveFooterNational)
      XCTAssertEqual(provider.forecastFooterLabel, RadarChromeCopy.forecastFooter)
      for vendor in vendors {
        XCTAssertFalse(
          provider.liveFooterLabel.localizedCaseInsensitiveContains(vendor),
          "\(provider) live footer leaked \(vendor)"
        )
        XCTAssertFalse(
          provider.forecastFooterLabel.localizedCaseInsensitiveContains(vendor),
          "\(provider) forecast footer leaked \(vendor)"
        )
      }
    }
    XCTAssertEqual(
      RadarStatusFooterCopy.live(isSiteProduct: true),
      RadarChromeCopy.liveFooterSite
    )
    XCTAssertEqual(
      RadarStatusFooterCopy.live(isSiteProduct: false),
      RadarChromeCopy.liveFooterNational
    )
    XCTAssertEqual(
      RadarStatusFooterCopy.forecast(for: .openWeatherMap),
      RadarChromeCopy.forecastFooter
    )
    XCTAssertEqual(RadarChromeCopy.liveFooterGeneric, "Live radar")
    XCTAssertEqual(RadarChromeCopy.liveFooterSite, "Live radar · Site Doppler")
    XCTAssertEqual(RadarChromeCopy.liveFooterNational, "Live radar · National radar")
    XCTAssertEqual(
      RadarStatusFooterCopy.availability(
        "OpenWeatherMap API key not configured.", preferForecast: true),
      "Forecast radar unavailable"
    )
    XCTAssertEqual(
      RadarStatusFooterCopy.availability(
        "Xweather daily map quota exceeded. Tiles refresh when quota resets.",
        preferForecast: false),
      "Radar unavailable — check connection and try again"
    )
    XCTAssertEqual(
      RadarStatusFooterCopy.availability(
        "Live radar unavailable — scan is too old.", preferForecast: false),
      "Live radar unavailable — scan is too old."
    )
  }

  @MainActor
  func testStatusFooterUsesSkillNamesForVendorBackends() {
    let now = Date()
    let national = RadarFrame(
      provider: .rainViewer,
      kind: .livePrecipitation,
      tileEpoch: Int(now.timeIntervalSince1970),
      timestamp: now,
      tileURLTemplates: ["https://example.com/{z}/{x}/{y}"]
    )
    let state = RadarState()
    state.seedCompositeCacheForTesting(frames: [national], loadedAt: now)
    state.restoreCompositeLiveForTesting()
    XCTAssertEqual(state.statusFooterContent.text, RadarChromeCopy.liveFooterNational)
    XCTAssertFalse(state.statusFooterContent.text.localizedCaseInsensitiveContains("RainViewer"))

    let site = IEMRadarService.Site(id: "NQA", name: "Memphis", lon: -89.9, lat: 35.0)
    let siteFrame = RadarFrame(
      provider: .iem,
      kind: .livePrecipitation,
      tileEpoch: Int(now.timeIntervalSince1970),
      timestamp: now,
      tileURLTemplates: ["https://example.com/{z}/{x}/{y}"]
    )
    state.seedSiteLiveForTesting(site: site, frames: [siteFrame])
    XCTAssertEqual(state.statusFooterContent.text, RadarChromeCopy.liveFooterSite)
    XCTAssertFalse(state.statusFooterContent.text.localizedCaseInsensitiveContains("IEM"))
    XCTAssertFalse(state.statusFooterContent.text.localizedCaseInsensitiveContains("NEXRAD"))
  }
}
