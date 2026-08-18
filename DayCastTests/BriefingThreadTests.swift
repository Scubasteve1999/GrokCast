import XCTest

@testable import DayCast

final class BriefingThreadTests: XCTestCase {
  func testSameCityIdentityDoesNotReplaceTheThread() {
    let seattle = UUID()
    XCTAssertFalse(
      BriefingThreadScope.shouldReplace(boundLocationID: seattle, selectedLocationID: seattle))
    XCTAssertFalse(
      BriefingThreadScope.shouldReplace(boundLocationID: nil, selectedLocationID: nil))
  }

  func testDifferentCityIdentityReplacesTheThread() {
    let seattle = UUID()
    let denver = UUID()
    XCTAssertTrue(
      BriefingThreadScope.shouldReplace(boundLocationID: seattle, selectedLocationID: denver))
    XCTAssertTrue(
      BriefingThreadScope.shouldReplace(boundLocationID: seattle, selectedLocationID: nil))
    XCTAssertTrue(
      BriefingThreadScope.shouldReplace(boundLocationID: nil, selectedLocationID: denver))
  }

  func testPersistedThreadIsNotVisibleOnAnotherCity() throws {
    let store = GrokAIConversationStore(inMemory: true)
    let olive = UUID()
    let seattle = UUID()
    let heat = ChatMessage.assistant(
      "Afternoon heat (96°F, heat index 103°F). Marginal wind risk.")

    try store.saveHistory([heat], for: olive)

    XCTAssertEqual(try store.loadHistory(for: olive).map(\.content), [heat.content])
    XCTAssertTrue(try store.loadHistory(for: seattle).isEmpty)
    XCTAssertTrue(try store.loadHistory(for: nil).isEmpty)
  }
}
