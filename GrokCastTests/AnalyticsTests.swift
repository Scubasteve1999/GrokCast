import XCTest
@testable import GrokCast

final class AnalyticsTests: XCTestCase {
  override func setUp() {
    super.setUp()
    Analytics.resetAllCounts()
    UserDefaults.standard.removeObject(forKey: PostHogAnalytics.optOutKey)
  }

  override func tearDown() {
    Analytics.resetAllCounts()
    UserDefaults.standard.removeObject(forKey: PostHogAnalytics.optOutKey)
    super.tearDown()
  }

  func testTrackIncrementsLocalCountWithoutCrashing() {
    // Capture no-ops when Secrets.xcconfig has no POSTHOG_API_KEY; local counts remain.
    Analytics.track(.appOpen)
    Analytics.track(.tabToday)
    XCTAssertEqual(Analytics.count(for: .appOpen), 1)
    XCTAssertEqual(Analytics.count(for: .tabToday), 1)
  }

  func testOptOutRoundTrip() {
    XCTAssertFalse(PostHogAnalytics.isOptedOut)
    PostHogAnalytics.setOptedOut(true)
    XCTAssertTrue(PostHogAnalytics.isOptedOut)
    PostHogAnalytics.setOptedOut(false)
    XCTAssertFalse(PostHogAnalytics.isOptedOut)
  }

  func testEmptyPostHogKeyIsNotConfigured() {
    // Without a real Secrets.xcconfig key, configure/capture must remain safe no-ops.
    if PostHogAnalytics.apiKey.isEmpty || PostHogAnalytics.apiKey.hasPrefix("$(") {
      XCTAssertFalse(PostHogAnalytics.isConfigured)
    }
    PostHogAnalytics.configure()
    PostHogAnalytics.capture("test_event")
  }
}
