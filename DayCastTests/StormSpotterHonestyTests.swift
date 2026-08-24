import XCTest

@testable import DayCast

final class StormSpotterHonestyTests: XCTestCase {

  override func tearDown() {
    _ = AskGrokPendingPrompt.take()
    super.tearDown()
  }

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
    XCTAssertEqual(messages.first?.content, SkyCheckDeskCopy.photoTurnCaption)
    XCTAssertFalse(messages.first?.content.contains("Notes:") ?? true)
  }

  func testPublicCTAIsASkyPhotoVerb() {
    XCTAssertEqual(SkyCheckDeskCopy.photoCTA, "Check this sky")
    XCTAssertFalse(SkyCheckDeskCopy.photoCTA.contains("Analyze Storm Photo"))
    XCTAssertFalse(SkyCheckDeskCopy.emptyPitch.localizedCaseInsensitiveContains("field read"))
    XCTAssertFalse(SkyCheckDeskCopy.emptyPitch.localizedCaseInsensitiveContains("wall cloud"))
    XCTAssertFalse(SkyCheckDeskCopy.notesHelper.localizedCaseInsensitiveContains("wall cloud"))
    XCTAssertFalse(SkyCheckDeskCopy.notesPlaceholder.localizedCaseInsensitiveContains("Observer"))
    XCTAssertEqual(
      SkyCheckDeskCopy.hedge,
      "Not an NWS product or warning. Rotation and hail are inferred, not certified.")
    XCTAssertEqual(SkyCheckDeskCopy.checkAnotherCTA, "Check another")
  }

  func testSkyCheckQuickPromptsDropFieldAndRadarRead() {
    XCTAssertFalse(SkyCheckDeskCopy.prompts.isEmpty)
    for prompt in SkyCheckDeskCopy.prompts {
      XCTAssertFalse(
        prompt.title.localizedCaseInsensitiveContains("Radar read"),
        "Sky Check must not impersonate Explain Radar: \(prompt.title)")
      XCTAssertFalse(prompt.title.localizedCaseInsensitiveContains("Imagine"))
      XCTAssertFalse(prompt.body.localizedCaseInsensitiveContains("SRV"))
      XCTAssertFalse(prompt.body.localizedCaseInsensitiveContains("field radar"))
      XCTAssertFalse(prompt.body.localizedCaseInsensitiveContains("storm-relative"))
    }
    let titles = SkyCheckDeskCopy.prompts.map(\.title)
    XCTAssertFalse(titles.contains("Radar read"))
    XCTAssertFalse(titles.contains("Imagine the scene"))
  }

  func testSkyCheckChatPromptIsPublicDeskNotFieldFirst() {
    let noWeather = GrokPrompts.skyCheckChatSystemPrompt(conditionsBlock: nil)
    let withWeather = GrokPrompts.skyCheckChatSystemPrompt(
      conditionsBlock: "Current conditions for Olive Branch, MS:\n- Temperature: 82°F")
    for prompt in [noWeather, withWeather] {
      XCTAssertTrue(prompt.contains("Sky Check"))
      XCTAssertFalse(prompt.localizedCaseInsensitiveContains("field-first"))
      XCTAssertFalse(prompt.localizedCaseInsensitiveContains("watching severe weather"))
      XCTAssertFalse(prompt.localizedCaseInsensitiveContains("SRV"))
      XCTAssertTrue(prompt.localizedCaseInsensitiveContains("do not invent radar"))
      XCTAssertTrue(prompt.localizedCaseInsensitiveContains("do not invent warnings"))
    }
  }

  func testMoreUnlockedSubtitleIsPhotoCheckAndQuestions() {
    let copy = GrokAccessRules.moreHubGrokSubtitle(canUseAI: true)
    XCTAssertEqual(copy, "Photo check and weather questions")
    XCTAssertFalse(copy.localizedCaseInsensitiveContains("briefings"))
    XCTAssertFalse(copy.localizedCaseInsensitiveContains("chat"))
  }

  func testTakeAndMorningLandOnSkyCheckReadyToType() {
    XCTAssertEqual(SkyCheckDeskCopy.landingActionTitle, "Sky Check")
    XCTAssertFalse(SkyCheckDeskCopy.landingActionTitle.localizedCaseInsensitiveContains("Ask AI"))
    XCTAssertFalse(SkyCheckDeskCopy.landingActionTitle.localizedCaseInsensitiveContains("Ask Grok"))
    _ = AskGrokPendingPrompt.take()
    AskGrokPendingPrompt.set(.focusInput)
    XCTAssertEqual(AskGrokPendingPrompt.take(), .focusInput)
  }

  @MainActor
  func testOpenReadyToTypeSelectsGrokTabAndQueuesFocus() {
    let store = WeatherStore.shared
    let previous = store.selectedTab
    _ = AskGrokPendingPrompt.take()
    SkyCheckLanding.openReadyToType(on: store)
    XCTAssertEqual(store.selectedTab, .grok)
    // Live GrokAIView may consume the queued focus; leftover must still be focus-only.
    if let leftover = AskGrokPendingPrompt.take() {
      XCTAssertEqual(leftover, .focusInput)
    }
    store.selectedTab = previous
  }

  func testShareReportUsesNotesNotObserverNotes() {
    let share = ShareableBriefText.stormSpotterReport(
      locationName: "Southaven, MS", observerNotes: "looking southwest", analysis: "Shelf cloud.")
    XCTAssertTrue(share.contains("Notes: looking southwest"))
    XCTAssertFalse(share.contains("Observer notes:"))
  }
}
