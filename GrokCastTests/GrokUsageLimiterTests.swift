import XCTest

@testable import GrokCast

/// Client-side mirror of the proxy's daily caps. The arithmetic and the UTC day
/// boundary have to match the server exactly, or the "resets at" copy lies.
final class GrokUsageLimiterTests: XCTestCase {
  private var defaults: UserDefaults!
  private var suiteName: String!
  private var clock: Date!

  override func setUp() {
    super.setUp()
    suiteName = "GrokUsageLimiterTests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)
    clock = Self.date("2026-08-01T12:00:00Z")
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    defaults = nil
    super.tearDown()
  }

  private static func date(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    return formatter.date(from: iso)!
  }

  private func makeLimiter() -> GrokUsageLimiter {
    GrokUsageLimiter(defaults: defaults, now: { self.clock })
  }

  func testConsumeCountsUpToTheLimitThenRefuses() {
    let limiter = makeLimiter()

    for expected in 1...GrokUsageBucket.image.dailyLimit {
      XCTAssertTrue(limiter.consume(.image))
      XCTAssertEqual(limiter.used(.image), expected)
    }

    XCTAssertFalse(limiter.consume(.image))
    XCTAssertEqual(limiter.remaining(.image), 0)
  }

  func testChatAndImageBudgetsAreIndependent() {
    let limiter = makeLimiter()

    for _ in 0..<GrokUsageBucket.image.dailyLimit { _ = limiter.consume(.image) }
    XCTAssertFalse(limiter.consume(.image))

    XCTAssertTrue(limiter.consume(.chat), "an exhausted image budget must not block chat")
  }

  func testCountersRollOverAtUTCMidnight() {
    let limiter = makeLimiter()

    clock = Self.date("2026-08-01T23:59:00Z")
    for _ in 0..<GrokUsageBucket.image.dailyLimit { _ = limiter.consume(.image) }
    XCTAssertFalse(limiter.consume(.image))

    clock = Self.date("2026-08-02T00:01:00Z")
    XCTAssertTrue(limiter.consume(.image))
    XCTAssertEqual(limiter.used(.image), 1)
  }

  func testResetDateIsTheNextUTCMidnight() {
    let limiter = makeLimiter()
    XCTAssertEqual(limiter.resetDate(), Self.date("2026-08-02T00:00:00Z"))

    clock = Self.date("2026-08-01T00:00:00Z")
    XCTAssertEqual(limiter.resetDate(), Self.date("2026-08-02T00:00:00Z"))
  }

  func testRefundReleasesAUnitAndNeverGoesNegative() {
    let limiter = makeLimiter()

    XCTAssertTrue(limiter.consume(.chat))
    limiter.refund(.chat)
    XCTAssertEqual(limiter.used(.chat), 0)

    limiter.refund(.chat)
    XCTAssertEqual(limiter.used(.chat), 0, "refunding an unused bucket must not underflow")
  }

  func testYesterdaysCountersArePrunedRatherThanAccumulating() {
    let limiter = makeLimiter()

    clock = Self.date("2026-08-01T12:00:00Z")
    _ = limiter.consume(.chat)

    clock = Self.date("2026-08-05T12:00:00Z")
    _ = limiter.consume(.chat)

    let leftover = defaults.dictionaryRepresentation().keys.filter {
      $0.contains("grokUsage") && $0.contains("2026-08-01")
    }
    XCTAssertTrue(leftover.isEmpty, "stale day counters should not pile up: \(leftover)")
  }

  func testLimitsMatchTheProxyConfiguration() {
    // These must stay in step with DAILY_CHAT_LIMIT / DAILY_IMAGE_LIMIT in
    // server/grok-proxy/wrangler.toml.
    XCTAssertEqual(GrokUsageBucket.chat.dailyLimit, 150)
    XCTAssertEqual(GrokUsageBucket.image.dailyLimit, 10)
  }
}
