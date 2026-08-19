import XCTest

@testable import DayCast

/// Covers the wiring between `RadarState` and `RadarPreferences`, which
/// `RadarPreferencesTests` deliberately does not touch: that mutating a state
/// property writes through, and that a freshly constructed state reads back.
///
/// The controls bind straight to these properties (`$radarState.colorScheme`), so
/// `didSet` firing is what makes a user's choice outlive the launch.
@MainActor
final class RadarStatePreferencesTests: XCTestCase {
  private static let suiteName = "RadarStatePreferencesTests"
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

  func testMutatingStateWritesThroughToPreferences() {
    let state = RadarState()

    state.colorScheme = .balanced
    state.baseMapStyle = .dark
    state.showRadarOverlay = false
    state.showFireLayer = true

    XCTAssertEqual(RadarPreferences.colorScheme, .balanced)
    XCTAssertEqual(RadarPreferences.baseMapStyle, .dark)
    XCTAssertFalse(RadarPreferences.showRadarOverlay)
    XCTAssertTrue(RadarPreferences.showFireLayer)
  }

  func testFreshStateRestoresStoredPreferences() {
    RadarPreferences.colorScheme = .balanced
    RadarPreferences.baseMapStyle = .dark
    RadarPreferences.showRadarOverlay = false
    RadarPreferences.showFireLayer = true

    let restored = RadarState()

    XCTAssertEqual(restored.colorScheme, .balanced)
    XCTAssertEqual(restored.baseMapStyle, .dark)
    XCTAssertFalse(restored.showRadarOverlay)
    XCTAssertTrue(restored.showFireLayer)
  }

  /// The round trip a user actually performs: change a setting, quit, relaunch.
  func testPreferencesSurviveAcrossStateInstances() {
    let first = RadarState()
    first.colorScheme = .balanced
    first.showRadarOverlay = false

    let second = RadarState()

    XCTAssertEqual(second.colorScheme, .balanced)
    XCTAssertFalse(second.showRadarOverlay)
  }

  /// Speed lives on `RadarPlayback`, so it restores through `init` rather than a
  /// `didSet` — a separate path worth its own assertion.
  func testPlaybackSpeedRestoresIntoPlayback() {
    RadarPreferences.playbackSpeed = 0.5

    let state = RadarState()

    XCTAssertEqual(state.playbackSpeed, 0.5, accuracy: 0.0001)
    XCTAssertEqual(state.playback.playbackSpeed, 0.5, accuracy: 0.0001)
  }

  /// The setter used to write `newValue` straight to `RadarPlayback` while
  /// persisting through `RadarPreferences`, which clamps — so an out-of-range
  /// speed animated unclamped for the session and then changed on next launch.
  func testOutOfRangeSpeedIsClampedInMemoryAndInStorage() {
    let state = RadarState()

    state.playbackSpeed = 99

    XCTAssertEqual(state.playbackSpeed, 4.0, accuracy: 0.0001)
    XCTAssertEqual(state.playback.playbackSpeed, 4.0, accuracy: 0.0001)
    XCTAssertEqual(RadarPreferences.playbackSpeed, 4.0, accuracy: 0.0001)

    state.playbackSpeed = -5

    XCTAssertEqual(state.playback.playbackSpeed, 0.25, accuracy: 0.0001)
    XCTAssertEqual(RadarPreferences.playbackSpeed, 0.25, accuracy: 0.0001)
  }

  func testDefaultsHoldWhenNothingWasEverStored() {
    let state = RadarState()

    XCTAssertEqual(state.colorScheme, .vibrant)
    XCTAssertEqual(state.baseMapStyle, .light)
    XCTAssertTrue(state.showRadarOverlay)
    XCTAssertFalse(state.showFireLayer)
    XCTAssertEqual(state.playbackSpeed, RadarPlayback.defaultPlaybackSpeed, accuracy: 0.0001)
  }

  func testLiveDefaultIsNearestSiteN0B() {
    XCTAssertEqual(RadarProduct.defaultLive, .superResReflectivity)
    XCTAssertEqual(RadarProduct.defaultLive.iemCode, "N0B")
    XCTAssertTrue(RadarProduct.defaultLive.isSiteProduct)
    XCTAssertEqual(RadarProduct.defaultLive.displayName, "Rain")

    let state = RadarState()
    XCTAssertEqual(state.selectedProduct, .superResReflectivity)
    XCTAssertTrue(state.selectedProduct.isSiteProduct)
    XCTAssertFalse(
      MapsGLRadarPalette.shouldUseMapsGL(
        overlayOn: true, isSiteProduct: state.selectedProduct.isSiteProduct, keysPresent: true)
    )
  }

  func testMosaicRemainsAOneTapFallback() async {
    let state = RadarState()
    XCTAssertEqual(state.selectedProduct, RadarProduct.defaultLive)

    await state.setProduct(.reflectivity)

    XCTAssertEqual(state.selectedProduct, .reflectivity)
    XCTAssertFalse(state.selectedProduct.isSiteProduct)
    XCTAssertEqual(state.selectedProduct.displayName, "Mosaic")
    XCTAssertTrue(
      MapsGLRadarPalette.shouldUseMapsGL(
        overlayOn: true, isSiteProduct: state.selectedProduct.isSiteProduct, keysPresent: true)
    )
  }
}
