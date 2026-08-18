import XCTest

@testable import DayCast

/// Runs against a private suite rather than `UserDefaults.standard`: the test bundle
/// is hosted by the app, so `standard` carries whatever the app last persisted and
/// the "no value stored" assertions would depend on it.
final class RadarPreferencesTests: XCTestCase {
  private static let suiteName = "RadarPreferencesTests"
  private var suite: UserDefaults!

  override func setUp() {
    super.setUp()
    UserDefaults.standard.removePersistentDomain(forName: Self.suiteName)
    suite = UserDefaults(suiteName: Self.suiteName)
    RadarPreferences.store = suite
  }

  override func tearDown() {
    RadarPreferences.store = .standard
    suite.removePersistentDomain(forName: Self.suiteName)
    suite = nil
    super.tearDown()
  }

  func testVibrantPaintSoftensHarshTiles() {
    XCTAssertLessThan(RadarColorScheme.vibrant.rasterContrast, 0)
    XCTAssertGreaterThan(RadarColorScheme.vibrant.rasterSaturation, 0)
    XCTAssertGreaterThan(RadarColorScheme.vibrant.rasterEmissiveStrength, 1)
    XCTAssertLessThan(RadarColorScheme.vibrant.rasterHueRotate, 0)
  }

  func testTodayRadarCardUsesOneRadarLabel() {
    XCTAssertEqual(RadarFeedCopy.title, "Radar")
    XCTAssertEqual(RadarFeedCopy.accessibilityLabel, "Radar. Opens the Radar tab.")
    XCTAssertFalse(RadarFeedCopy.title.localizedCaseInsensitiveContains("Live Radar"))
    XCTAssertFalse(RadarFeedCopy.title.localizedCaseInsensitiveContains("Open"))
    XCTAssertFalse(RadarFeedCopy.accessibilityLabel.localizedCaseInsensitiveContains("Live Radar"))
  }

  func testTodayRadarPreviewUsesXweatherNotRainViewer() {
    guard XweatherRadarService.mapsAuthConfigured else {
      XCTAssertNil(RadarPreviewSource.latestLiveTileTemplate())
      return
    }
    let template = RadarPreviewSource.latestLiveTileTemplate()
    XCTAssertNotNil(template)
    XCTAssertTrue(template?.contains("xweather.com") == true)
    XCTAssertFalse(template?.contains("rainviewer") == true)
  }

  func testMapsGLRadarPaletteIsTransparentAtZero() {
    let first = MapsGLRadarPalette.reflectivityStops.first
    XCTAssertEqual(first?.dbz, 0)
    XCTAssertEqual(first?.alpha, 0)
    XCTAssertFalse(MapsGLRadarPalette.interpolatesStops)
    XCTAssertGreaterThan(MapsGLRadarPalette.reflectivityStops.count, 4)

    func stop(_ dbz: Double) -> MapsGLRadarPalette.Stop? {
      MapsGLRadarPalette.reflectivityStops.first { $0.dbz == dbz }
    }
    XCTAssertEqual(stop(5)?.hex, "#04E9E7")
    XCTAssertEqual(stop(20)?.hex, "#02FD02")
    XCTAssertEqual(stop(50)?.hex, "#FD0000")
    XCTAssertEqual(stop(65)?.hex, "#F800FD")
    XCTAssertEqual(stop(75)?.hex, "#FFFFFF")

    XCTAssertTrue(
      MapsGLRadarPalette.shouldUseMapsGL(
        overlayOn: true, isSiteProduct: false, keysPresent: true)
    )
    XCTAssertFalse(
      MapsGLRadarPalette.shouldUseMapsGL(
        overlayOn: true, isSiteProduct: true, keysPresent: true)
    )
    XCTAssertFalse(
      MapsGLRadarPalette.shouldUseMapsGL(
        overlayOn: true, isSiteProduct: false, keysPresent: false)
    )
  }

  func testRasterColorSchemeIsHiddenWhenMapsGLRainIsOn() {
    XCTAssertFalse(
      MapsGLRadarPalette.showsRasterColorScheme(
        overlayOn: true, isSiteProduct: false, keysPresent: true)
    )
    XCTAssertTrue(
      MapsGLRadarPalette.showsRasterColorScheme(
        overlayOn: true, isSiteProduct: false, keysPresent: false)
    )
    XCTAssertFalse(
      MapsGLRadarPalette.showsRasterColorScheme(
        overlayOn: true, isSiteProduct: true, keysPresent: false)
    )
    XCTAssertFalse(
      MapsGLRadarPalette.showsRasterColorScheme(
        overlayOn: false, isSiteProduct: false, keysPresent: false)
    )
  }

  func testLegendTicksReuseMapsGLPaletteStops() {
    XCTAssertEqual(MapsGLRadarPalette.legendTickDbz, [5, 20, 35, 50, 65])
    XCTAssertFalse(MapsGLRadarPalette.interpolatesStops)

    let visible = MapsGLRadarPalette.visibleReflectivityStops
    XCTAssertEqual(visible.count, MapsGLRadarPalette.reflectivityStops.count - 1)
    XCTAssertTrue(visible.allSatisfy { $0.alpha > 0 })
    XCTAssertFalse(visible.contains { $0.dbz == 0 })

    for tick in MapsGLRadarPalette.legendTickDbz {
      let stop = visible.first { $0.dbz == tick }
      XCTAssertNotNil(stop, "legend tick \(tick) must be a painted palette stop")
      XCTAssertEqual(
        stop?.hex,
        MapsGLRadarPalette.reflectivityStops.first { $0.dbz == tick }?.hex
      )
    }
  }

  func testControlSheetStaysUpWhenMapOnlyIsPersisted() {
    XCTAssertTrue(RadarChromeVisibility.showsControlSheet(mapOnly: false))
    XCTAssertTrue(RadarChromeVisibility.showsControlSheet(mapOnly: true))
  }

  func testLayersSwitchesHaveSpokenNames() {
    XCTAssertEqual(RadarChromeCopy.autoResumeSwitch, "Auto-resume after scrub")
    XCTAssertEqual(RadarChromeCopy.mapOnlySwitch, "Map only")
    XCTAssertEqual(RadarChromeCopy.radarOverlaySwitch, "Radar overlay")
    XCTAssertEqual(RadarChromeCopy.fireLayerSwitch, "Fire layer")
  }

  func testRadarModeChipsAreNotNamedForecast() {
    XCTAssertEqual(RadarChromeCopy.liveChip, "Live")
    XCTAssertEqual(RadarChromeCopy.futureChip, "24-hr")
    XCTAssertFalse(RadarChromeCopy.futureChip.localizedCaseInsensitiveContains("Forecast"))
    XCTAssertEqual(RadarChromeCopy.layers, "Layers")
  }

  func testDefaultsApplyWhenNothingIsStored() {
    XCTAssertEqual(RadarPreferences.colorScheme, .vibrant)
    XCTAssertEqual(RadarPreferences.baseMapStyle, .satelliteStreets)
    XCTAssertTrue(RadarPreferences.showRadarOverlay)
    XCTAssertFalse(RadarPreferences.showFireLayer)
    XCTAssertEqual(RadarPreferences.playbackSpeed, RadarPlayback.defaultPlaybackSpeed)
    XCTAssertEqual(RadarPreferences.radarOpacity, RadarPreferences.defaultRadarOpacity)
    XCTAssertFalse(RadarPreferences.chaseDecluttered)
  }

  func testValuesRoundTrip() {
    RadarPreferences.colorScheme = .balanced
    RadarPreferences.baseMapStyle = .dark
    RadarPreferences.showFireLayer = true
    RadarPreferences.playbackSpeed = 1.0
    RadarPreferences.radarOpacity = 0.55
    RadarPreferences.chaseDecluttered = true

    XCTAssertEqual(RadarPreferences.colorScheme, .balanced)
    XCTAssertEqual(RadarPreferences.baseMapStyle, .dark)
    XCTAssertTrue(RadarPreferences.showFireLayer)
    XCTAssertEqual(RadarPreferences.playbackSpeed, 1.0)
    XCTAssertEqual(RadarPreferences.radarOpacity, 0.55, accuracy: 0.0001)
    XCTAssertTrue(RadarPreferences.chaseDecluttered)
  }

  /// The default is true, so a stored `false` has to survive — the bug this guards
  /// against is reading it back with `UserDefaults.bool(forKey:)`, which cannot tell
  /// "stored false" from "never set".
  func testRadarOverlayOffIsRemembered() {
    RadarPreferences.showRadarOverlay = false
    XCTAssertFalse(RadarPreferences.showRadarOverlay)
  }

  func testUnknownRawValueFallsBackToTheDefault() {
    suite.set("chartreuse", forKey: "radar.pref.colorScheme")
    suite.set("blueprint", forKey: "radar.pref.baseMapStyle")

    XCTAssertEqual(RadarPreferences.colorScheme, .vibrant)
    XCTAssertEqual(RadarPreferences.baseMapStyle, .satelliteStreets)
  }

  func testPlaybackSpeedIsClampedInBothDirections() {
    RadarPreferences.playbackSpeed = 99
    XCTAssertEqual(RadarPreferences.playbackSpeed, 4.0)

    RadarPreferences.playbackSpeed = -5
    XCTAssertEqual(RadarPreferences.playbackSpeed, 0.25)
  }

  /// A value written by something other than this store (an older build, a synced
  /// defaults plist) must not reach playback unclamped — a zero would divide the
  /// frame interval by zero.
  func testStoredSpeedOutOfRangeIsClampedOnRead() {
    suite.set(0.0, forKey: "radar.pref.playbackSpeed")
    XCTAssertEqual(RadarPreferences.playbackSpeed, 0.25)
  }

  func testRadarOpacityIsClampedInBothDirections() {
    RadarPreferences.radarOpacity = 1.5
    XCTAssertEqual(RadarPreferences.radarOpacity, 1.0, accuracy: 0.0001)

    RadarPreferences.radarOpacity = 0.1
    XCTAssertEqual(
      RadarPreferences.radarOpacity,
      RadarPreferences.radarOpacityRange.lowerBound,
      accuracy: 0.0001
    )
  }

  func testStoredOpacityOutOfRangeIsClampedOnRead() {
    suite.set(0.0, forKey: "radar.pref.radarOpacity")
    XCTAssertEqual(
      RadarPreferences.radarOpacity,
      RadarPreferences.radarOpacityRange.lowerBound,
      accuracy: 0.0001
    )

    suite.set(Double.nan, forKey: "radar.pref.radarOpacity")
    XCTAssertEqual(
      RadarPreferences.radarOpacity,
      RadarPreferences.defaultRadarOpacity,
      accuracy: 0.0001
    )
  }
}
