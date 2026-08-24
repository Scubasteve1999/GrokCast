import XCTest

@testable import DayCast

final class StormSpotterHonestyTests: XCTestCase {

  func testVisionPromptIsFieldFirstNotWitty() {
    let prompt = GrokPrompts.stormSpotterSystemPrompt
    XCTAssertFalse(
      prompt.localizedCaseInsensitiveContains("witty"),
      "Severe photo path must not instruct witty / humor tone")
    XCTAssertFalse(prompt.localizedCaseInsensitiveContains("humor"))
    XCTAssertTrue(prompt.localizedCaseInsensitiveContains("not an NWS product"))
    XCTAssertTrue(prompt.localizedCaseInsensitiveContains("not a warning"))
    XCTAssertTrue(prompt.localizedCaseInsensitiveContains("observed"))
    XCTAssertTrue(prompt.localizedCaseInsensitiveContains("inferred"))
    XCTAssertTrue(prompt.contains("Sky Check"))
    XCTAssertFalse(
      prompt.localizedCaseInsensitiveContains("storm spotter assistant"),
      "Model-facing identity should be Sky Check, not storm spotter assistant")
  }

  func testUserFacingCopyUsesSkyCheckNotStormSpotter() {
    XCTAssertTrue(PaywallFeature.grokAI.headline.contains("Sky Check"))
    XCTAssertFalse(PaywallFeature.grokAI.headline.localizedCaseInsensitiveContains("storm spotter"))
    XCTAssertTrue(PaywallFeature.grokAI.subheadline.contains("Sky Check"))
    XCTAssertFalse(
      PaywallFeature.grokAI.subheadline.localizedCaseInsensitiveContains("Storm Spotter"))

    let share = ShareableBriefText.stormSpotterReport(
      locationName: "Southaven, MS", observerNotes: nil, analysis: "Shelf cloud.")
    XCTAssertTrue(share.contains("DayCast Sky Check"))
    XCTAssertTrue(share.contains("#DayCastSkyCheck"))
    XCTAssertFalse(share.localizedCaseInsensitiveContains("Storm Spotter"))
  }

  func testPaywallGrokAIDoesNotClaimProNeverUnlocksHostedAI() {
    let copy = PaywallFeature.grokAI.subheadline
    XCTAssertFalse(
      copy.localizedCaseInsensitiveContains("not hosted AI"),
      "Paywall must not claim Pro never unlocks hosted AI")
    XCTAssertTrue(copy.localizedCaseInsensitiveContains("Pro"))
    XCTAssertTrue(copy.localizedCaseInsensitiveContains("xAI key"))
  }

  func testMorningBriefPaywallMentionsProHostedPath() {
    let copy = PaywallFeature.morningBrief.subheadline
    XCTAssertTrue(copy.localizedCaseInsensitiveContains("Pro"))
    XCTAssertTrue(copy.localizedCaseInsensitiveContains("xAI key"))
  }

  func testLockedAlertsCopyMentionsProAndBYOK() {
    let copy = GrokAccessRules.lockedAlertsSummaryCopy
    XCTAssertTrue(copy.localizedCaseInsensitiveContains("Pro"))
    XCTAssertTrue(copy.localizedCaseInsensitiveContains("xAI key"))
    XCTAssertFalse(copy.hasPrefix("Add an xAI key"))
  }

  @MainActor
  func testPhotoTurnUsesUserWithPhotoAndAssistantFactories() {
    let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
    let messages = GrokAIViewModel.photoTurnMessages(
      locationName: "Olive Branch, MS",
      thumbnail: jpeg,
      analysis: "Wall cloud; rotation is inferred, not certified.",
      notes: "looking southwest"
    )

    XCTAssertEqual(messages.count, 2)
    XCTAssertEqual(messages[0].role, .user)
    XCTAssertEqual(messages[1].role, .assistant)
    XCTAssertNotNil(messages[0].imageData)
    XCTAssertEqual(messages[0].imageData, jpeg)
    XCTAssertTrue(messages[0].content.contains("Olive Branch, MS"))
    XCTAssertTrue(messages[0].content.contains("looking southwest"))
    XCTAssertTrue(messages[1].isStormSpotterAnalysis)
    XCTAssertEqual(messages[1].content, "Wall cloud; rotation is inferred, not certified.")
    XCTAssertEqual(messages[1].originalNotes, "looking southwest")
  }

  @MainActor
  func testPhotoTurnCaptionWorksWithoutLocationOrNotes() {
    let messages = GrokAIViewModel.photoTurnMessages(
      locationName: nil, thumbnail: nil, analysis: "Shelf cloud.", notes: "  ")
    XCTAssertEqual(messages.first?.content, "Analyze this storm photo")
    XCTAssertFalse(messages.first?.content.contains("Notes:") ?? true)
  }
}
