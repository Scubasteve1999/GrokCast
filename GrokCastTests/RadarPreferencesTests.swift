import XCTest

@testable import GrokCast

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

  func testDefaultsApplyWhenNothingIsStored() {
    XCTAssertEqual(RadarPreferences.colorScheme, .vibrant)
    XCTAssertEqual(RadarPreferences.baseMapStyle, .satelliteStreets)
    XCTAssertTrue(RadarPreferences.showRadarOverlay)
    XCTAssertFalse(RadarPreferences.showFireLayer)
    XCTAssertEqual(RadarPreferences.playbackSpeed, RadarPlayback.defaultPlaybackSpeed)
  }

  func testValuesRoundTrip() {
    RadarPreferences.colorScheme = .balanced
    RadarPreferences.baseMapStyle = .dark
    RadarPreferences.showFireLayer = true
    RadarPreferences.playbackSpeed = 1.0

    XCTAssertEqual(RadarPreferences.colorScheme, .balanced)
    XCTAssertEqual(RadarPreferences.baseMapStyle, .dark)
    XCTAssertTrue(RadarPreferences.showFireLayer)
    XCTAssertEqual(RadarPreferences.playbackSpeed, 1.0)
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
}
