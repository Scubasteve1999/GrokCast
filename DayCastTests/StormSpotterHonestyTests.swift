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
    XCTAssertTrue(SkyCheckDeskCopy.emptyPitch.lowercased().hasPrefix("ask about your weather"))
    XCTAssertTrue(SkyCheckDeskCopy.emptyPitch.localizedCaseInsensitiveContains("sky photo"))
    XCTAssertFalse(SkyCheckDeskCopy.emptyPitch.localizedCaseInsensitiveContains("field read"))
    XCTAssertFalse(SkyCheckDeskCopy.emptyPitch.localizedCaseInsensitiveContains("wall cloud"))
    XCTAssertFalse(SkyCheckDeskCopy.emptyPitch.localizedCaseInsensitiveContains("Ask Grok"))
    XCTAssertFalse(SkyCheckDeskCopy.emptyPitch.localizedCaseInsensitiveContains("Ask AI"))
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
    XCTAssertEqual(titles, ["Threat check", "Outside now?", "Outlook"])
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

  func testSkyCheckChatPromptGroundsHourlyHRRRAFDAndObservation() {
    let now = Date(timeIntervalSince1970: 1_787_547_600)  // 2026-08-24 09:00 UTC
    let hourly = [
      HourlyForecast(
        time: now.addingTimeInterval(3600),
        temp: 84,
        precipChance: 40,
        weatherCode: 61,
        symbolName: "cloud.rain.fill",
        rain: 0.2,
        showers: nil,
        snowfall: nil,
        isDay: true
      ),
      HourlyForecast(
        time: now.addingTimeInterval(2 * 3600),
        temp: 82,
        precipChance: 20,
        weatherCode: 1,
        symbolName: "cloud.fill",
        rain: nil,
        showers: nil,
        snowfall: nil,
        isDay: true
      ),
    ]
    let weather = DayCastWeather(
      location: SavedLocation(name: "Olive Branch, MS", latitude: 34.96, longitude: -89.83),
      currentTemp: 81,
      feelsLike: 83,
      conditionCode: 1,
      conditionText: "Partly cloudy",
      humidity: 55,
      windSpeed: 8,
      uvIndex: 6,
      precipitationChance: 20,
      high: 86,
      low: 70,
      symbolName: "cloud.sun.fill",
      fetchedAt: now,
      timezoneIdentifier: "America/Chicago",
      airQualityIndex: nil,
      pm25: nil,
      pollenLevel: nil,
      hourly: hourly,
      daily: [],
      minutely15: []
    )
    let obs = NWSObservation(
      stationId: "KMEM",
      observedAt: now,
      temperatureF: 82,
      windSpeedMph: 5,
      windDirectionDegrees: 270
    )
    let hrrr = ShortTermPrecipContext(
      locationID: "loc-olive",
      fetchedAt: now,
      source: .hrrr,
      slots: [
        MinutelyForecast(time: now.addingTimeInterval(15 * 60), precipitation: 0.12, precipChance: 80)
      ],
      summary: nil
    )
    let briefing = LocalBriefingItem(
      id: "afd-test-km0",
      title: "Shower and thunderstorm chances increase late tonight.",
      sourceName: "NWS Memphis",
      issuedAt: now,
      url: URL(string: "https://forecast.weather.gov/product.php?product=AFD")!,
      productCode: "AFD",
      officeID: "MEG",
      imageURL: nil
    )

    let prompt = GrokPrompts.skyCheckChatSystemPrompt(
      weather: weather,
      locationName: "Olive Branch, MS",
      unit: .fahrenheit,
      alerts: [],
      severeContext: nil,
      shortTermContext: hrrr,
      nearestStationObservation: obs,
      briefingItems: [briefing],
      now: now
    )

    XCTAssertTrue(prompt.contains("Sky Check"))
    XCTAssertTrue(prompt.contains("84°F"), prompt)
    XCTAssertTrue(prompt.contains("40% precip"), prompt)
    XCTAssertTrue(prompt.contains("0.2\""), prompt)
    XCTAssertTrue(prompt.contains("Next 12–24 hours"), prompt)
    XCTAssertTrue(prompt.contains("KMEM"), prompt)
    XCTAssertTrue(prompt.localizedCaseInsensitiveContains("Nearest official NWS"), prompt)
    XCTAssertTrue(prompt.contains("HRRR"), prompt)
    XCTAssertTrue(prompt.localizedCaseInsensitiveContains("Short-term precip"), prompt)
    XCTAssertTrue(prompt.contains("AFD"), prompt)
    XCTAssertTrue(prompt.contains("NWS Memphis"), prompt)
    XCTAssertTrue(
      prompt.contains("Shower and thunderstorm chances increase late tonight."), prompt)
    XCTAssertTrue(prompt.localizedCaseInsensitiveContains("Do not rewrite"), prompt)
    XCTAssertTrue(prompt.localizedCaseInsensitiveContains("Cite NWS, HRRR, or AFD"), prompt)
    XCTAssertTrue(prompt.localizedCaseInsensitiveContains("do not invent radar"), prompt)
    XCTAssertFalse(prompt.localizedCaseInsensitiveContains("N0B"))
    XCTAssertFalse(prompt.localizedCaseInsensitiveContains("Site Doppler"))
    XCTAssertFalse(prompt.localizedCaseInsensitiveContains("MRMS"))
    XCTAssertFalse(prompt.localizedCaseInsensitiveContains("RadarExplain"))
  }

  func testSkyCheckChatPromptOmitsMissingGroundingBlocks() {
    let now = Date(timeIntervalSince1970: 1_787_547_600)
    let weather = DayCastWeather(
      location: SavedLocation(name: "Olive Branch, MS", latitude: 34.96, longitude: -89.83),
      currentTemp: 81,
      feelsLike: 83,
      conditionCode: 0,
      conditionText: "Clear",
      humidity: 40,
      windSpeed: 5,
      uvIndex: 4,
      precipitationChance: 0,
      high: 86,
      low: 70,
      symbolName: "sun.max.fill",
      fetchedAt: now,
      timezoneIdentifier: "America/Chicago",
      airQualityIndex: nil,
      pm25: nil,
      pollenLevel: nil,
      hourly: [],
      daily: [],
      minutely15: []
    )
    let prompt = GrokPrompts.skyCheckChatSystemPrompt(
      weather: weather,
      locationName: "Olive Branch, MS",
      unit: .fahrenheit,
      now: now
    )
    XCTAssertTrue(prompt.contains("81°F"))
    XCTAssertFalse(prompt.contains("Next 12–24 hours"))
    XCTAssertFalse(prompt.contains("HRRR 15-min"))
    XCTAssertFalse(prompt.localizedCaseInsensitiveContains("Nearest official NWS"))
    XCTAssertFalse(prompt.contains("NWS local briefing"))
    XCTAssertFalse(prompt.contains("[AFD]"))
    XCTAssertTrue(prompt.localizedCaseInsensitiveContains("do not invent radar"))
  }

  @MainActor
  func testImageGenerationDetectorDoesNotStealSkyPhotoWeatherQuestions() {
    XCTAssertFalse(
      GrokAIViewModel.isImageGenerationRequest(
        "What's the picture of the sky going to look like this afternoon?"))
    XCTAssertFalse(
      GrokAIViewModel.isImageGenerationRequest("Can you check this photo of the sky?"))
    XCTAssertFalse(
      GrokAIViewModel.isImageGenerationRequest("Analyze this sky photo for me."))
    for prompt in SkyCheckDeskCopy.prompts {
      XCTAssertFalse(
        GrokAIViewModel.isImageGenerationRequest(prompt.body),
        "Chip must stay in askGrok chat, not Imagine: \(prompt.title)")
      XCTAssertFalse(prompt.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
  }

  func testMoreUnlockedSubtitleIsWeatherQuestionsFirst() {
    let copy = GrokAccessRules.moreHubGrokSubtitle(canUseAI: true)
    XCTAssertEqual(copy, "Ask about your weather. Photo check when you want.")
    XCTAssertTrue(copy.lowercased().hasPrefix("ask about your weather"))
    XCTAssertFalse(copy.localizedCaseInsensitiveContains("briefings"))
    XCTAssertFalse(copy.localizedCaseInsensitiveContains("Ask Grok"))
    XCTAssertFalse(copy.localizedCaseInsensitiveContains("Ask AI"))
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
