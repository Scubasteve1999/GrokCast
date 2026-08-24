import XCTest

@testable import DayCast

@MainActor
final class SkyCheckStreamWriterTests: XCTestCase {
  func testPhotoStreamDoesNotGrowResponseText() {
    let viewModel = makeViewModel()
    viewModel.stormAnalysisMode = true
    viewModel.responseText = "prior chat"
    viewModel.stormAnalysisText = ""

    viewModel.appendSkyCheckStreamToken("shelf ")
    viewModel.appendSkyCheckStreamToken("cloud")

    XCTAssertEqual(viewModel.stormAnalysisText, "shelf cloud")
    XCTAssertEqual(viewModel.responseText, "prior chat")
  }

  func testChatStreamDoesNotGrowStormAnalysisText() {
    let viewModel = makeViewModel()
    viewModel.stormAnalysisMode = false
    viewModel.responseText = ""
    viewModel.stormAnalysisText = "prior photo analysis"

    viewModel.appendSkyCheckStreamToken("rain ")
    viewModel.appendSkyCheckStreamToken("later")

    XCTAssertEqual(viewModel.responseText, "rain later")
    XCTAssertEqual(viewModel.stormAnalysisText, "prior photo analysis")
  }

  func testAllowedPhotoCommitLeavesResponseTextEmpty() async {
    let viewModel = makeViewModel()
    await viewModel.waitForHistoryLoad()
    viewModel.responseText = "leftover analysis copy"
    let reply = "Shelf cloud along the gust front. Rotation is inferred, not certified."
    viewModel.commitFinishedSkyCheckReply(reply, asPhotoTurn: true)

    XCTAssertEqual(viewModel.stormAnalysisText, reply)
    XCTAssertTrue(viewModel.responseText.isEmpty)
  }

  func testPublicPhotoCTAStaysCheckThisSky() {
    XCTAssertEqual(SkyCheckDeskCopy.photoCTA, "Check this sky")
  }

  private func makeViewModel() -> GrokAIViewModel {
    GrokAIViewModel(
      weatherStore: WeatherStore(),
      conversationStore: GrokAIConversationStore(inMemory: true)
    )
  }
}
