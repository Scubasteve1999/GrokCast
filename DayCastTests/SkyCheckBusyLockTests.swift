import XCTest

@testable import DayCast

@MainActor
final class SkyCheckBusyLockTests: XCTestCase {
  private let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])

  func testAnalyzeStormPhotoRefusesWhileStreamingWithoutStartingASecondVisionJob() async {
    let viewModel = makeViewModel()
    viewModel.isStreaming = true
    viewModel.stormAnalysisMode = true
    viewModel.responseText = "in flight"
    viewModel.stormAnalysisText = "checking this sky"

    await viewModel.analyzeStormPhoto(imageData: jpeg, userNotes: "southwest")

    XCTAssertNil(viewModel.lastStormImageData, "Must not take the second photo")
    XCTAssertEqual(viewModel.stormAnalysisText, "checking this sky")
    XCTAssertEqual(viewModel.responseText, "in flight")
    XCTAssertTrue(viewModel.isStreaming)
    XCTAssertTrue(viewModel.stormAnalysisMode)
    XCTAssertFalse(
      viewModel.conversationHistory.contains { $0.content.contains("southwest") },
      "Must not append a second photo turn")
    XCTAssertEqual(viewModel.errorMessage, SkyCheckDeskCopy.alreadyChecking)
  }

  func testAnalyzeStormPhotoRefusesWhileChatIsStreaming() async {
    let viewModel = makeViewModel()
    viewModel.isStreaming = true
    viewModel.stormAnalysisMode = false
    viewModel.responseText = "partial answer"

    await viewModel.analyzeStormPhoto(imageData: jpeg, userNotes: nil)

    XCTAssertNil(viewModel.lastStormImageData)
    XCTAssertEqual(viewModel.responseText, "partial answer")
    XCTAssertTrue(viewModel.stormAnalysisText.isEmpty)
    XCTAssertFalse(viewModel.stormAnalysisMode)
    XCTAssertTrue(viewModel.isStreaming)
    XCTAssertEqual(viewModel.errorMessage, SkyCheckDeskCopy.alreadyAnswering)
  }

  func testAnalyzeStormPhotoRefusesWhileGeneratingImage() async {
    let viewModel = makeViewModel()
    viewModel.isGeneratingImage = true

    await viewModel.analyzeStormPhoto(imageData: jpeg, userNotes: nil)

    XCTAssertNil(viewModel.lastStormImageData)
    XCTAssertTrue(viewModel.stormAnalysisText.isEmpty)
    XCTAssertTrue(viewModel.isGeneratingImage)
    XCTAssertFalse(viewModel.isStreaming)
    XCTAssertEqual(viewModel.errorMessage, SkyCheckDeskCopy.alreadyAnswering)
  }

  func testAskGrokStillRefusesWhileStreaming() async {
    let viewModel = makeViewModel()
    viewModel.isStreaming = true
    viewModel.responseText = "partial answer"

    await viewModel.askGrok(question: "hello")

    XCTAssertFalse(
      viewModel.conversationHistory.contains { $0.role == .user && $0.content == "hello" },
      "askGrok must not append while streaming")
    XCTAssertEqual(viewModel.responseText, "partial answer")
    XCTAssertTrue(viewModel.isStreaming)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testPublicPhotoCTAStaysCheckThisSky() {
    XCTAssertEqual(SkyCheckDeskCopy.photoCTA, "Check this sky")
  }

  private func makeViewModel() -> GrokAIViewModel {
    GrokAIViewModel(weatherStore: WeatherStore())
  }
}
