import XCTest

@testable import DayCast

final class AskGrokPendingPromptTests: XCTestCase {

  override func tearDown() {
    _ = AskGrokPendingPrompt.take()
    super.tearDown()
  }

  func testSubmitRoundTripsAndClears() {
    AskGrokPendingPrompt.set(.submit("What's the storm doing?"))
    XCTAssertEqual(AskGrokPendingPrompt.take(), .submit("What's the storm doing?"))
    XCTAssertNil(AskGrokPendingPrompt.take())
  }

  func testEmptySubmitBecomesFocusOnly() {
    AskGrokPendingPrompt.set(.submit("   "))
    XCTAssertEqual(AskGrokPendingPrompt.take(), .focusInput)
  }

  func testFocusDoesNotCarryAQuestion() {
    AskGrokPendingPrompt.set(.focusInput)
    XCTAssertEqual(AskGrokPendingPrompt.take(), .focusInput)
    XCTAssertNil(AskGrokPendingPrompt.take())
  }
}

final class RadarTimelinePlayheadTests: XCTestCase {
  func testProgressAtEndsAndMidpoint() {
    XCTAssertEqual(RadarTimelinePlayhead.progress(index: 0, count: 1), 0)
    XCTAssertEqual(RadarTimelinePlayhead.progress(index: 0, count: 5), 0)
    XCTAssertEqual(RadarTimelinePlayhead.progress(index: 4, count: 5), 1)
    XCTAssertEqual(RadarTimelinePlayhead.progress(index: 2, count: 5), 0.5)
  }

  func testProgressClampsOutOfRange() {
    XCTAssertEqual(RadarTimelinePlayhead.progress(index: -3, count: 5), 0)
    XCTAssertEqual(RadarTimelinePlayhead.progress(index: 99, count: 5), 1)
  }
}
