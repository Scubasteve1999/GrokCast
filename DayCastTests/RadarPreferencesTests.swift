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

  #if DEBUG
    func testDebugNationalPaintDefaultsToAuto() {
      UserDefaults.standard.removeObject(forKey: "radar.debug.nationalPaint")
      XCTAssertEqual(DebugFlags.nationalPaint, .auto)
      XCTAssertEqual(MRMSNationalSource.overrideForDebug(), .auto)
      XCTAssertTrue(
        MapsGLRadarPalette.shouldUseMapsGL(
          overlayOn: true, isSiteProduct: false, keysPresent: true)
      )
    }
  #endif

  func testTodayRadarCardUsesOneRadarLabel() {
    XCTAssertEqual(RadarFeedCopy.title, "Radar")
    XCTAssertEqual(RadarFeedCopy.accessibilityLabel, "Radar. Opens the Radar tab.")
    XCTAssertFalse(RadarFeedCopy.title.localizedCaseInsensitiveContains("Live Radar"))
    XCTAssertFalse(RadarFeedCopy.title.localizedCaseInsensitiveContains("Open"))
    XCTAssertFalse(RadarFeedCopy.accessibilityLabel.localizedCaseInsensitiveContains("Live Radar"))
  }

  func testTodayRadarPreviewUsesMapsGLOnLight() {
    XCTAssertEqual(RadarPreviewSource.previewBaseMap, .light)
    XCTAssertTrue(RadarPreviewSource.usesMapsGL(keysPresent: true))
    XCTAssertFalse(RadarPreviewSource.usesMapsGL(keysPresent: false))
    // Today card stays on the national mosaic even though Live Rain is now N0B.
    XCTAssertTrue(
      MapsGLRadarPalette.shouldUseMapsGL(
        overlayOn: true, isSiteProduct: false, keysPresent: true)
    )
    XCTAssertFalse(MapsGLRadarPalette.interpolatesStops)
    XCTAssertFalse(MapsGLRadarPalette.interpolatesSamples)
    XCTAssertEqual(MapsGLRadarPalette.sampleSmoothing, 0)
  }

  func testMapsGLRadarPaletteIsTransparentAtZero() {
    let first = MapsGLRadarPalette.reflectivityStops.first
    XCTAssertEqual(first?.dbz, 0)
    XCTAssertEqual(first?.alpha, 0)
    XCTAssertFalse(MapsGLRadarPalette.interpolatesStops)
    XCTAssertFalse(MapsGLRadarPalette.interpolatesSamples)
    XCTAssertEqual(MapsGLRadarPalette.bandIntervalDbz, 5)
    XCTAssertEqual(MapsGLRadarPalette.sampleSmoothing, 0)
    XCTAssertGreaterThan(MapsGLRadarPalette.reflectivityStops.count, 4)

    func stop(_ dbz: Double) -> MapsGLRadarPalette.Stop? {
      MapsGLRadarPalette.reflectivityStops.first { $0.dbz == dbz }
    }
    XCTAssertEqual(stop(5)?.hex, "#01A0F6")
    XCTAssertEqual(stop(5)?.alpha ?? -1, 0.85, accuracy: 0.0001)
    XCTAssertEqual(stop(10)?.hex, "#0000F6")
    XCTAssertEqual(stop(10)?.alpha ?? -1, 0.90, accuracy: 0.0001)
    XCTAssertEqual(stop(15)?.hex, "#00FF00")
    XCTAssertEqual(stop(15)?.alpha ?? -1, 0.94, accuracy: 0.0001)
    XCTAssertEqual(stop(20)?.hex, "#00C800")
    XCTAssertEqual(stop(20)?.alpha ?? -1, 0.97, accuracy: 0.0001)
    XCTAssertEqual(stop(25)?.alpha, 1)
    XCTAssertEqual(stop(35)?.hex, "#E7C000")
    XCTAssertEqual(stop(40)?.hex, "#FF9000")
    XCTAssertEqual(stop(40)?.alpha, 1)
    XCTAssertEqual(stop(50)?.hex, "#D60000")
    XCTAssertEqual(stop(50)?.alpha, 1)
    XCTAssertEqual(stop(60)?.hex, "#FF00FF")
    XCTAssertEqual(stop(65)?.hex, "#9955C9")
    XCTAssertEqual(stop(70)?.hex, "#FFFFFF")
    XCTAssertEqual(stop(70)?.alpha, 1)
    XCTAssertGreaterThan(stop(5)?.alpha ?? 0, 0.8)
    XCTAssertEqual(stop(30)?.alpha, 1)
    XCTAssertEqual(
      MapsGLRadarPalette.colorScaleBreaks, [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70])
    XCTAssertTrue(MapsGLRadarPalette.liveRasterUsesNearestResampling)
    XCTAssertFalse(MapsGLRadarPalette.interpolatesStops)
    XCTAssertEqual(MapsGLRadarPalette.bandIntervalDbz, 5)

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
    XCTAssertEqual(MapsGLRadarPalette.legendTickDbz, [5, 20, 35, 50, 65, 70])
    XCTAssertFalse(MapsGLRadarPalette.interpolatesStops)

    let visible = MapsGLRadarPalette.visibleReflectivityStops
    XCTAssertEqual(
      visible.count,
      MapsGLRadarPalette.reflectivityStops.filter { $0.alpha > 0 }.count
    )
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

  func testN0BColorbarOmitsKeyedCyanBlueStops() {
    let n0b = MapsGLRadarPalette.paintedReflectivityStops(keysClearAir: true)
    XCTAssertEqual(n0b.first?.dbz, 15)
    XCTAssertEqual(n0b.first?.hex, "#00FF00")
    XCTAssertFalse(n0b.contains { $0.dbz == 5 })
    XCTAssertFalse(n0b.contains { $0.dbz == 10 })
    XCTAssertFalse(n0b.contains { $0.hex == "#01A0F6" })
    XCTAssertFalse(n0b.contains { $0.hex == "#0000F6" })
    XCTAssertTrue(n0b.contains { $0.dbz == 40 && $0.hex == "#FF9000" })
    XCTAssertEqual(MapsGLRadarPalette.legendTicks(keysClearAir: true), [15, 30, 45, 60, 70])
    for tick in MapsGLRadarPalette.legendTicks(keysClearAir: true) {
      XCTAssertNotNil(n0b.first { $0.dbz == tick })
    }

    let mosaic = MapsGLRadarPalette.paintedReflectivityStops(keysClearAir: false)
    XCTAssertEqual(mosaic.first?.dbz, 5)
    XCTAssertTrue(mosaic.contains { $0.dbz == 10 })
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
    XCTAssertEqual(RadarChromeCopy.motionTracks, "Motion tracks")
  }

  func testStormcellsFollowMapsGLRainGate() {
    XCTAssertTrue(
      MapsGLLiveRainLayers.shouldShow(
        overlayOn: true, isSiteProduct: false, keysPresent: true, isLive: true)
    )
    XCTAssertFalse(
      MapsGLLiveRainLayers.shouldShow(
        overlayOn: true, isSiteProduct: false, keysPresent: true, isLive: false)
    )
    XCTAssertFalse(
      MapsGLLiveRainLayers.shouldShow(
        overlayOn: true, isSiteProduct: true, keysPresent: true)
    )
    XCTAssertFalse(
      MapsGLLiveRainLayers.shouldShow(
        overlayOn: false, isSiteProduct: false, keysPresent: true)
    )
    XCTAssertFalse(
      MapsGLLiveRainLayers.shouldShow(
        overlayOn: true, isSiteProduct: false, keysPresent: false)
    )
    XCTAssertEqual(
      MapsGLLiveRainLayers.shouldShow(
        overlayOn: true, isSiteProduct: false, keysPresent: true),
      MapsGLRadarPalette.shouldUseMapsGL(
        overlayOn: true, isSiteProduct: false, keysPresent: true)
    )
    XCTAssertEqual(
      MapsGLLiveRainLayers.shouldShow(
        overlayOn: true, isSiteProduct: true, keysPresent: true),
      MapsGLRadarPalette.shouldUseMapsGL(
        overlayOn: true, isSiteProduct: true, keysPresent: true)
    )
    // Host used to pass rainWant as overlayOn with isSiteProduct: false.
    // N0B rainWant is false, but that is not a license to lie about site.
    XCTAssertFalse(
      MapsGLLiveRainLayers.shouldShow(
        overlayOn: true, isSiteProduct: true, keysPresent: true, isLive: true)
    )
    XCTAssertFalse(
      MapsGLLiveRainLayers.shouldShow(
        overlayOn: false, isSiteProduct: false, keysPresent: true, isLive: true)
    )
  }

  func testMapsGLRadarNeverAttachesOnSiteN0B() {
    XCTAssertFalse(
      MapsGLLiveRainLayers.shouldAttachRadar(
        overlayOn: true, isSiteProduct: true, keysPresent: true)
    )
    XCTAssertFalse(
      MapsGLLiveRainLayers.shouldShow(
        overlayOn: true, isSiteProduct: true, keysPresent: true, isLive: true)
    )
    XCTAssertTrue(
      MapsGLLiveRainLayers.shouldAttachRadar(
        overlayOn: true, isSiteProduct: false, keysPresent: true)
    )
    XCTAssertEqual(
      MapsGLLiveRainLayers.shouldAttachRadar(
        overlayOn: true, isSiteProduct: true, keysPresent: true),
      MapsGLRadarPalette.shouldUseMapsGL(
        overlayOn: true, isSiteProduct: true, keysPresent: true)
    )
    XCTAssertEqual(RadarLivePresentation.mapsGLLiveLookback, 60 * 60, accuracy: 0.1)
    XCTAssertEqual(RadarLivePresentation.mapsGLLiveLookback, RadarLivePresentation.loopWindow)
    XCTAssertLessThan(RadarLivePresentation.mapsGLLiveLookback, 3 * 3600)
    XCTAssertGreaterThan(RadarLivePresentation.mapsGLLiveLookback, 15 * 60)
  }

  func testStormcellFilterIsSevereClassOnly() {
    XCTAssertEqual(MapsGLLiveRainLayers.severeTraitTypes, ["hail", "rotating", "tornado"])
    XCTAssertEqual(MapsGLLiveRainLayers.excludedTraitType, "general")
    XCTAssertFalse(MapsGLLiveRainLayers.severeTraitTypes.contains("general"))
    XCTAssertEqual(MapsGLLiveRainLayers.traitTypeProperty, "traits.type")
    XCTAssertEqual(MapsGLLiveRainLayers.traitTornadoProperty, "traits.tornado")
    XCTAssertEqual(MapsGLLiveRainLayers.tvsProperty, "tvs")
    XCTAssertFalse(MapsGLLiveRainLayers.isSevereStormcell(traitType: "general"))
    XCTAssertFalse(MapsGLLiveRainLayers.isSevereStormcell(traitType: nil))
    XCTAssertTrue(MapsGLLiveRainLayers.isSevereStormcell(traitType: "hail"))
    XCTAssertTrue(MapsGLLiveRainLayers.isSevereStormcell(traitType: "rotating"))
    XCTAssertTrue(MapsGLLiveRainLayers.isSevereStormcell(traitType: "tornado"))
    XCTAssertTrue(MapsGLLiveRainLayers.isSevereStormcell(traitType: "general", tvs: 1))
    XCTAssertTrue(MapsGLLiveRainLayers.isSevereStormcell(traitType: "general", traitTornado: 1))
    XCTAssertFalse(MapsGLLiveRainLayers.isSevereStormcell(traitType: "general", traitTornado: 0, tvs: 0))
  }

  func testStormcellTracksPaintLineStringsOnly() {
    XCTAssertEqual(MapsGLLiveRainLayers.lineStringGeometryType, "LineString")
    XCTAssertTrue(
      MapsGLLiveRainLayers.shouldPaintStormcellTrack(
        geometryType: "LineString", traitType: "hail"))
    XCTAssertTrue(
      MapsGLLiveRainLayers.shouldPaintStormcellTrack(
        geometryType: "LineString", traitType: "rotating"))
    XCTAssertTrue(
      MapsGLLiveRainLayers.shouldPaintStormcellTrack(
        geometryType: "LineString", traitType: "tornado"))
    XCTAssertTrue(
      MapsGLLiveRainLayers.shouldPaintStormcellTrack(
        geometryType: "LineString", traitType: "general", tvs: 1))
    XCTAssertFalse(
      MapsGLLiveRainLayers.shouldPaintStormcellTrack(
        geometryType: "Polygon", traitType: "hail"))
    XCTAssertFalse(
      MapsGLLiveRainLayers.shouldPaintStormcellTrack(
        geometryType: "Point", traitType: "hail"))
    XCTAssertFalse(
      MapsGLLiveRainLayers.shouldPaintStormcellTrack(
        geometryType: "GeometryCollection", traitType: "hail"))
    XCTAssertFalse(
      MapsGLLiveRainLayers.shouldPaintStormcellTrack(
        geometryType: "LineString", traitType: "general"))
    let filter = MapsGLLiveRainLayers.mapboxStormcellTrackFilter
    XCTAssertEqual(filter.first as? String, "all")
    let geom = filter.dropFirst().first as? [Any]
    XCTAssertEqual(geom?.first as? String, "==")
    XCTAssertEqual((geom?.dropFirst().first as? [String])?.first, "geometry-type")
    XCTAssertEqual(geom?.last as? String, "LineString")
    let any = filter.last as? [Any]
    XCTAssertEqual(any?.first as? String, "any")
    XCTAssertGreaterThanOrEqual(any?.count ?? 0, 6)
  }

  func testDetachRemovesStormcellsAndRadar() {
    XCTAssertEqual(
      MapsGLLiveRainLayers.detachIDs,
      ["radar", "stormcells-tracks"]
    )
    XCTAssertFalse(MapsGLLiveRainLayers.detachIDs.contains("stormcells-positions"))
    XCTAssertFalse(MapsGLLiveRainLayers.stormcellIDs.contains("stormcells-positions"))
    XCTAssertFalse(MapsGLLiveRainLayers.detachIDs.contains("stormcells-heat"))
    XCTAssertFalse(MapsGLLiveRainLayers.detachIDs.contains("stormcells-cones"))
    XCTAssertFalse(MapsGLLiveRainLayers.detachIDs.contains("alerts"))
    XCTAssertFalse(MapsGLLiveRainLayers.stormcellIDs.contains("stormcells"))
    XCTAssertEqual(MapsGLLiveRainLayers.trackThickness, 1.15, accuracy: 0.0001)
    XCTAssertLessThan(MapsGLLiveRainLayers.trackThickness, 2)
    XCTAssertEqual(MapsGLLiveRainLayers.trackOpacity, 0.68, accuracy: 0.0001)
    XCTAssertEqual(MapsGLLiveRainLayers.trackColorWhite, 0.07, accuracy: 0.0001)
  }

  func testStormcellsChromeIsNotSCIT() {
    let chrome = [
      RadarChromeCopy.motionTracks,
      RadarChromeCopy.liveChip,
      RadarChromeCopy.futureChip,
      RadarChromeCopy.layers,
      RadarChromeCopy.radarOverlaySwitch,
      RadarChromeCopy.liveAccessibility,
    ]
    for label in chrome {
      XCTAssertFalse(label.localizedCaseInsensitiveContains("SCIT"), label)
      XCTAssertFalse(label.localizedCaseInsensitiveContains("NWS tracks"), label)
      XCTAssertFalse(label.localizedCaseInsensitiveContains("official storm"), label)
    }
    XCTAssertEqual(RadarChromeCopy.motionTracks, "Motion tracks")
    XCTAssertTrue(RadarChromeCopy.motionTracks.localizedCaseInsensitiveContains("motion tracks"))
  }

  func testRadarModeChipsAreNotNamedForecast() {
    XCTAssertEqual(RadarChromeCopy.liveChip, "Live")
    XCTAssertEqual(RadarChromeCopy.futureChip, "24-hr")
    XCTAssertFalse(RadarChromeCopy.futureChip.localizedCaseInsensitiveContains("Forecast"))
    XCTAssertEqual(RadarChromeCopy.layers, "Layers")
  }

  func testDefaultBaseMapIsQuietMapboxLight() {
    XCTAssertEqual(RadarBaseMapStyle.light.displayName, "Light")
    XCTAssertEqual(RadarBaseMapStyle.satelliteStreets.displayName, "Hybrid")
    XCTAssertEqual(RadarBaseMapStyle.light.cycled(), .satelliteStreets)
    XCTAssertEqual(
      RadarBaseMapStyle.quietWorkstationHiddenLayerIDs,
      ["poi-label", "transit-label", "airport-label", "natural-point-label"]
    )
    XCTAssertFalse(RadarBaseMapStyle.quietWorkstationHiddenLayerIDs.contains("road-label"))
    XCTAssertFalse(RadarBaseMapStyle.quietWorkstationHiddenLayerIDs.contains("settlement-label"))
  }

  func testSatellitePostcardMigratesToLightOnce() {
    suite.set(RadarBaseMapStyle.satelliteStreets.rawValue, forKey: "radar.pref.baseMapStyle")
    XCTAssertEqual(RadarPreferences.baseMapStyle, .light)

    RadarPreferences.baseMapStyle = .satelliteStreets
    XCTAssertEqual(RadarPreferences.baseMapStyle, .satelliteStreets)
  }

  func testDefaultsApplyWhenNothingIsStored() {
    XCTAssertEqual(RadarPreferences.colorScheme, .vibrant)
    XCTAssertEqual(RadarPreferences.baseMapStyle, .light)
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
    XCTAssertEqual(RadarPreferences.baseMapStyle, .light)
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
