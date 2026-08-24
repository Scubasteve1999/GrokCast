import Foundation
import Observation

@MainActor
@Observable
final class GrokAIViewModel {
  var responseText: String = ""
  /// Dedicated storm-photo write-up. Compact card and share use this so later
  /// chat tokens in `responseText` cannot appear inside Sky Check chrome.
  var stormAnalysisText: String = ""
  var isStreaming: Bool = false
  var errorMessage: String?
  var stormAnalysisMode: Bool = false
  var stormThumbnailData: Data?
  var isGeneratingImage: Bool = false

  private let weatherStore: WeatherStore
  private let conversationStore: GrokAIConversationStore
  @ObservationIgnored private nonisolated(unsafe) var generationTask: Task<Void, Never>?
  /// Identifies the current generation so a cancelled/superseded task's teardown can't
  /// clobber the state of the generation that replaced it.
  @ObservationIgnored private var activeGenerationID = UUID()
  private(set) var generationWasCancelled = false

  private(set) var lastStormImageData: Data?
  private(set) var lastStormNotes: String?

  // Conversation history for multi-turn context
  private(set) var conversationHistory: [ChatMessage] = []
  private let maxContextMessages = 16  // simple limit for context window (~8 turns)
  @ObservationIgnored private var historyLoadTask: Task<Void, Never>?
  /// Selected city whose thread is currently in `conversationHistory`.
  private var boundLocationID: UUID?

  init(
    weatherStore: WeatherStore,
    conversationStore: GrokAIConversationStore = GrokAIConversationStore()
  ) {
    self.weatherStore = weatherStore
    self.conversationStore = conversationStore
    boundLocationID = weatherStore.currentLocation?.id

    // Load persisted history before accepting new messages (prevents async overwrite race).
    historyLoadTask = Task { @MainActor in
      await loadPersistedHistory()
    }
  }

  /// Swap the visible thread when the selected city identity changes.
  /// Same-city refresh / reopen is a no-op so that city's thread stays.
  func syncThread(to selectedLocationID: UUID?) {
    guard
      BriefingThreadScope.shouldReplace(
        boundLocationID: boundLocationID,
        selectedLocationID: selectedLocationID
      )
    else { return }

    if let boundLocationID {
      persistCurrentHistory(for: boundLocationID)
    }
    if isStreaming || isGeneratingImage {
      stopGeneration()
    }
    responseText = ""
    stormAnalysisText = ""
    errorMessage = nil
    stormThumbnailData = nil
    stormAnalysisMode = false
    lastStormImageData = nil
    lastStormNotes = nil
    boundLocationID = selectedLocationID
    conversationHistory = []
    historyLoadTask = Task { @MainActor in
      await loadPersistedHistory()
    }
  }

  deinit {
    generationTask?.cancel()
  }

  /// Clears action-blocking flags left over when a prior request was interrupted
  /// (tab switch, timeout, or cancel) without finishing the generation task.
  func recoverFromStaleActionStateIfNeeded() {
    guard generationTask == nil else { return }
    if isStreaming || isGeneratingImage {
      isStreaming = false
      isGeneratingImage = false
      stormAnalysisMode = false
    }
  }

  func askGrok(question: String) async {
    syncThread(to: weatherStore.currentLocation?.id)
    await historyLoadTask?.value

    guard !question.trimmingCharacters(in: .whitespaces).isEmpty else { return }

    // Prevent overlapping generations from rapid taps
    guard !isStreaming && !isGeneratingImage else { return }

    // Early key guard — stay on AI tab with a clear CTA (no error banner / tab bounce).
    if !weatherStore.canUseGrok {
      handleMissingDeveloperKey()
      return
    }

    // Imagine stays on Today. Never steal Sky Check weather questions — including
    // "picture of the sky" / photo analysis — into image generation.

    // Show thinking immediately so actions feel responsive during weather prefetch.
    generationTask?.cancel()
    generationWasCancelled = false
    stormAnalysisMode = false
    isStreaming = true
    responseText = ""
    errorMessage = nil

    await ensureWeatherContext()

    // Append user to history immediately so it shows in transcript
    let userMsg = ChatMessage.user(question)
    conversationHistory.append(userMsg)
    conversationHistory = trimHistory(conversationHistory)
    persistCurrentHistory()

    let systemPrompt = buildWeatherSystemPrompt()

    // Build API messages: system first + history turns
    var apiMessages: [GrokBuildMessage] = [
      GrokBuildMessage(role: "system", content: systemPrompt)
    ]
    for msg in conversationHistory {
      apiMessages.append(GrokBuildMessage(role: msg.role.rawValue, content: msg.content))
    }

    let generationID = UUID()
    activeGenerationID = generationID
    generationTask = Task { @MainActor [weak self] in
      guard let self else { return }
      var tokenCount = 0
      do {
        // Use streaming for progressive token display
        for try await token in try GrokBuildService.stream(
          messages: apiMessages, feature: .chat)
        {
          if Task.isCancelled || !self.isStreaming { break }
          tokenCount += 1
          self.responseText += token
        }
      } catch {
        if !(error is CancellationError) {
          self.errorMessage = error.localizedDescription
        }
      }
      // A newer generation replaced this one — don't touch shared state it now owns.
      guard self.activeGenerationID == generationID else { return }
      self.isStreaming = false

      if !self.responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        self.commitFinishedSkyCheckReply(self.responseText, asPhotoTurn: false)
      } else if !Task.isCancelled && self.generationWasCancelled == false {
        self.errorMessage = "AI returned an empty response. Check your connection and try again."
      }
      self.generationTask = nil
    }
    await generationTask?.value
  }

  func analyzeStormPhoto(imageData: Data, userNotes: String?) async {
    syncThread(to: weatherStore.currentLocation?.id)
    await historyLoadTask?.value

    // Same lock as askGrok — one in-flight generation. Do not cancel-and-restart.
    guard !isStreaming && !isGeneratingImage else {
      if generationTask == nil {
        errorMessage = SkyCheckDeskCopy.generationBusyMessage(
          isCheckingSky: stormAnalysisMode)
      }
      return
    }

    generationTask?.cancel()
    generationWasCancelled = false
    stormAnalysisMode = true
    isStreaming = true
    responseText = ""
    stormAnalysisText = ""
    errorMessage = nil

    lastStormImageData = imageData
    lastStormNotes = userNotes
    stormThumbnailData = imageData.compressedForVision(
      maxDimension: SkyCheckPersistedThumbnail.maxDimension,
      quality: SkyCheckPersistedThumbnail.jpegQuality
    )

    guard imageData.compressedForVision() != nil else {
      errorMessage = "Couldn't process that photo. Try a different image or format (JPEG/PNG)."
      isStreaming = false
      stormAnalysisMode = false
      return
    }

    guard weatherStore.canUseGrok else {
      handleMissingDeveloperKey()
      isStreaming = false
      stormAnalysisMode = false
      return
    }

    await refreshStormWeatherContext()

    let weather = weatherStore.currentWeather
    let alerts = weatherStore.displayableActiveAlerts
    let severeContext = SevereWeatherStore.shared.context
    let shortTerm = ShortTermPrecipStore.shared.context
    let locationKey = weatherStore.currentLocation?.id.uuidString
    let observation = weatherStore.currentNWSObservation

    let generationID = UUID()
    activeGenerationID = generationID
    generationTask = Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        for try await token in try GrokBuildService.streamStormPhoto(
          imageData: imageData,
          weather: weather,
          alerts: alerts,
          severeContext: severeContext.locationID == locationKey ? severeContext : nil,
          shortTermContext: shortTerm.locationID == locationKey && shortTerm.hasHRRRSlots
            ? shortTerm : nil,
          observation: observation,
          userNotes: userNotes,
          unit: weatherStore.temperatureUnit
        ) {
          if Task.isCancelled || !isStreaming { break }
          self.stormAnalysisText += token
          self.responseText += token
        }
      } catch {
        if !(error is CancellationError) {
          self.errorMessage = self.userFriendlyStormError(for: error)
        }
      }
      // A newer generation replaced this one — don't touch shared state it now owns.
      guard self.activeGenerationID == generationID else { return }
      self.isStreaming = false
      if !self.stormAnalysisText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        self.commitFinishedSkyCheckReply(self.stormAnalysisText, asPhotoTurn: true)
      } else if !Task.isCancelled && self.generationWasCancelled == false {
        self.errorMessage =
          "Storm analysis returned an empty response. Check your connection and try again."
      }
      self.stormAnalysisMode = false
      self.generationTask = nil
    }
    await generationTask?.value
  }

  /// User photo + assistant write-up appended to the bound city thread.
  static func photoTurnMessages(
    locationName: String?,
    thumbnail: Data?,
    analysis: String,
    notes: String?
  ) -> [ChatMessage] {
    let turn = ChatMessage.stormSpotterPhotoTurn(
      locationName: locationName,
      thumbnail: thumbnail,
      analysis: analysis,
      notes: notes
    )
    return [turn.user, turn.assistant]
  }

  /// After a finished Sky Check stream. Screens, then commits. Never writes blocked raw.
  func commitFinishedSkyCheckReply(_ raw: String, asPhotoTurn: Bool) {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    if let accepted = GrokContentFilter.acceptedSkyCheckText(trimmed) {
      if asPhotoTurn {
        stormAnalysisText = accepted
        responseText = accepted
        conversationHistory.append(
          contentsOf: Self.photoTurnMessages(
            locationName: weatherStore.currentLocation?.name,
            thumbnail: stormThumbnailData,
            analysis: accepted,
            notes: lastStormNotes
          )
        )
      } else {
        responseText = accepted
        conversationHistory.append(ChatMessage.assistant(accepted))
      }
      conversationHistory = trimHistory(conversationHistory)
      persistCurrentHistory()
      return
    }

    responseText = ""
    stormAnalysisText = ""
    if asPhotoTurn {
      conversationHistory.append(
        ChatMessage.userWithPhoto(
          text: ChatMessage.stormSpotterUserCaption(
            locationName: weatherStore.currentLocation?.name,
            notes: lastStormNotes
          ),
          imageData: stormThumbnailData
        )
      )
    }
    conversationHistory.append(ChatMessage.assistant(SkyCheckDeskCopy.replyHidden))
    conversationHistory = trimHistory(conversationHistory)
    persistCurrentHistory()
  }

  func retryStormAnalysis() async {
    guard let imageData = lastStormImageData else { return }
    await analyzeStormPhoto(imageData: imageData, userNotes: lastStormNotes)
  }

  func clearResponse() {
    responseText = ""
    stormAnalysisText = ""
    errorMessage = nil
    stormThumbnailData = nil
    stormAnalysisMode = false
    lastStormImageData = nil
    lastStormNotes = nil
    isGeneratingImage = false
    conversationHistory.removeAll()  // start fresh conversation for this city

    if let boundLocationID {
      Task {
        try? conversationStore.deleteAll(for: boundLocationID)
      }
    }
  }

  public func stopGeneration() {
    generationTask?.cancel()
    generationTask = nil
    isStreaming = false
    stormAnalysisMode = false
    generationWasCancelled = true
  }

  func consumeGenerationWasCancelled() -> Bool {
    let was = generationWasCancelled
    generationWasCancelled = false
    return was
  }

  /// Missing-key UX: open Pro paywall when that unlocks AI; otherwise leave empty-state CTA visible (actions are disabled in the UI).
  private func handleMissingDeveloperKey() {
    errorMessage = nil
    if PaywallCoordinator.shared.canUnlockGrokViaPro {
      PaywallCoordinator.shared.present(.grokAI)
    }
  }

  func userFriendlyStormError(for error: Error) -> String {
    if weatherStore.isOffline {
      return "No internet connection. Check your Wi-Fi or cellular and try again."
    }

    if let urlError = error as? URLError, urlError.code == .timedOut {
      return "Storm analysis timed out. The image may be large or the service is busy — tap Retry."
    }

    if let buildError = error as? GrokBuildError {
      return buildError.errorDescription ?? "Storm analysis failed. Please try again."
    }

    return "Storm analysis failed. Please try again."
  }

  private func refreshStormWeatherContext() async {
    if weatherStore.currentLocation != nil {
      await weatherStore.refreshWeather()
    } else {
      await weatherStore.useCurrentDeviceLocation()
    }
  }

  private enum WeatherPrefetchResult {
    case loaded
    case timedOut
  }

  private static let weatherPollIntervalNs: UInt64 = 100_000_000
  private static let inFlightWeatherPollAttempts = 30  // 3s
  private static let cappedFetchTimeoutNs: UInt64 = 3_000_000_000

  private func ensureWeatherContext() async {
    guard weatherStore.currentWeather == nil else { return }

    // Wait briefly for an in-flight app-wide refresh instead of starting a duplicate fetch.
    if weatherStore.isLoadingWeather || !weatherStore.hasCompletedInitialLoad {
      for _ in 0..<Self.inFlightWeatherPollAttempts {
        if weatherStore.currentWeather != nil { return }
        if weatherStore.hasCompletedInitialLoad && !weatherStore.isLoadingWeather { break }
        try? await Task.sleep(nanoseconds: Self.weatherPollIntervalNs)
      }
    }

    guard weatherStore.currentWeather == nil else { return }

    if !weatherStore.hasCompletedInitialLoad {
      let result = await withTaskGroup(of: WeatherPrefetchResult.self) { group in
        group.addTask { @MainActor in
          await self.weatherStore.performInitialLoadIfNeeded()
          return .loaded
        }
        group.addTask {
          try? await Task.sleep(nanoseconds: Self.cappedFetchTimeoutNs)
          return .timedOut
        }
        let first = await group.next() ?? .timedOut
        group.cancelAll()
        return first
      }
      if weatherStore.currentWeather != nil || result == .loaded { return }
    }

    guard weatherStore.currentWeather == nil, weatherStore.currentLocation != nil else { return }

    let result = await withTaskGroup(of: WeatherPrefetchResult.self) { group in
      group.addTask { @MainActor in
        await self.weatherStore.refreshWeather()
        return .loaded
      }
      group.addTask {
        try? await Task.sleep(nanoseconds: Self.cappedFetchTimeoutNs)
        return .timedOut
      }
      let first = await group.next() ?? .timedOut
      group.cancelAll()
      return first
    }
    _ = result
  }

  private func buildWeatherSystemPrompt() -> String {
    let locationName =
      weatherStore.currentLocation?.name
      ?? weatherStore.currentWeather?.location.name
      ?? "your location"
    let locationKey = weatherStore.currentLocation?.id.uuidString
    let severe = SevereWeatherStore.shared.context
    let shortTerm = ShortTermPrecipStore.shared.context
    let briefing = LocalBriefingStore.shared

    let severeContext: SevereWeatherContext? =
      locationKey != nil && severe.locationID == locationKey ? severe : nil
    let shortTermContext: ShortTermPrecipContext? = {
      guard let locationKey,
        shortTerm.locationID == locationKey,
        shortTerm.hasHRRRSlots,
        shortTerm.isUsableHRRR()
      else { return nil }
      return shortTerm
    }()
    let briefingItems: [LocalBriefingItem] = {
      guard let locationKey, briefing.locationID == locationKey, !briefing.items.isEmpty else {
        return []
      }
      return briefing.items
    }()

    return GrokPrompts.skyCheckChatSystemPrompt(
      weather: weatherStore.currentWeather,
      locationName: locationName,
      unit: weatherStore.temperatureUnit,
      alerts: Array(weatherStore.displayableActiveAlerts.prefix(5)),
      severeContext: severeContext,
      shortTermContext: shortTermContext,
      nearestStationObservation: weatherStore.currentNWSObservation,
      briefingItems: briefingItems
    )
  }

  /// Imagine stays on Today. Weather / sky-photo questions must stay in chat.
  static func isImageGenerationRequest(_ text: String) -> Bool {
    let lower = text.lowercased()
    if looksLikeSkyPhotoOrWeatherQuestion(lower) { return false }
    return lower.contains("imagine")
      || lower.contains("draw")
      || lower.contains("visualize")
      || lower.contains("generate a scene")
      || lower.contains("show me the weather as")
      || (lower.contains("generate") && (lower.contains("image") || lower.contains("picture")))
  }

  private static func looksLikeSkyPhotoOrWeatherQuestion(_ lower: String) -> Bool {
    let analysisSignals = [
      "picture of the sky", "photo of the sky", "picture of the clouds",
      "photo of the clouds", "sky photo", "sky picture", "check this sky",
      "analyze this", "analyse this", "what's in this photo", "whats in this photo",
      "this photo", "this picture", "look at this",
    ]
    if analysisSignals.contains(where: lower.contains) { return true }
    let mentionsMedia =
      lower.contains("picture") || lower.contains("photo") || lower.contains("image")
    let mentionsWeather =
      lower.contains("sky") || lower.contains("cloud") || lower.contains("storm")
      || lower.contains("weather") || lower.contains("radar") || lower.contains("outlook")
      || lower.contains("warning") || lower.contains("watch")
    return mentionsMedia && mentionsWeather
  }

  private func buildImagePrompt(userDescription: String?) -> String {
    guard let current = weatherStore.currentWeather else {
      let base =
        userDescription?.isEmpty == false ? userDescription! : "A beautiful cinematic weather scene"
      return "\(base), photorealistic, high detail, atmospheric lighting, no text or logos"
    }

    let unit = weatherStore.temperatureUnit
    let location = current.location.name
    let base = userDescription?.isEmpty == false ? "\(userDescription!). " : ""
    let timeOfDay =
      (current.symbolName.contains("sun") || current.symbolName.contains("day"))
      ? "daytime" : "evening or night"

    return """
      \(base)Create a highly detailed, cinematic weather visualization for \(location) right now.
      Conditions: \(current.conditionText), \(unit.format(current.currentTemp)) (feels like \(unit.format(current.feelsLike))), wind \(unit.formatWind(current.windSpeed)), humidity \(current.humidity)%.
      Today's range \(unit.formatShort(current.high)) / \(unit.formatShort(current.low)). \(timeOfDay) lighting.
      Photorealistic or atmospheric digital art style, dramatic natural light, rich colors, 
      moody and immersive, no text, no logos, no people unless they naturally enhance the scene.
      """
  }

  func generateWeatherImage(description: String? = nil) async {
    syncThread(to: weatherStore.currentLocation?.id)
    await historyLoadTask?.value
    guard !isStreaming && !isGeneratingImage else { return }

    guard weatherStore.canUseGrok else {
      handleMissingDeveloperKey()
      return
    }

    await ensureWeatherContext()

    generationTask?.cancel()
    stormAnalysisMode = false
    isGeneratingImage = true
    responseText = ""
    errorMessage = nil

    let userContent =
      description?.trimmingCharacters(in: .whitespaces).isEmpty == false
      ? description!
      : "Generate an image of the current weather"
    let userMsg = ChatMessage.user(userContent)
    conversationHistory.append(userMsg)
    conversationHistory = trimHistory(conversationHistory)
    persistCurrentHistory()

    do {
      let prompt = buildImagePrompt(userDescription: description)
      let url = try await GrokBuildService.generateImage(prompt: prompt)

      let assistantMsg = ChatMessage(
        role: .assistant,
        content: "Here's a generated visualization based on the current conditions:",
        generatedImageURL: url
      )
      conversationHistory.append(assistantMsg)
      conversationHistory = trimHistory(conversationHistory)
      persistCurrentHistory()
    } catch {
      errorMessage = "Image generation failed: \(error.localizedDescription)"
    }

    isGeneratingImage = false
  }

  private func trimHistory(_ history: [ChatMessage]) -> [ChatMessage] {
    var trimmed = history
    let maxTokens = 2048  // conservative rough budget (leaves room for system + generation)
    while estimateTokens(trimmed) > maxTokens && trimmed.count > 2 {
      trimmed.removeFirst()
    }
    return trimmed
  }

  private func estimateTokens(_ messages: [ChatMessage]) -> Int {
    // Rough estimate: ~4 characters per token
    let chars = messages.reduce(0) { $0 + $1.content.count }
    return chars / 4
  }

  // MARK: - SwiftData Persistence

  func waitForHistoryLoad() async {
    await historyLoadTask?.value
  }

  private func loadPersistedHistory() async {
    do {
      var loaded = try conversationStore.loadHistory(for: boundLocationID)
      loaded = trimHistory(loaded)
      conversationHistory = loaded
    } catch {
      // Start with empty history on error (non-fatal for the feature).
      conversationHistory = []
    }
    historyLoadTask = nil
  }

  private func persistCurrentHistory() {
    persistCurrentHistory(for: boundLocationID)
  }

  private func persistCurrentHistory(for locationID: UUID?) {
    guard let locationID else { return }
    // Snapshot to avoid capturing mutable state across the Task boundary
    // User-turn `imageData` is already the 150px JPEG thumb. The store
    // re-caps it and never writes `lastStormImageData` / vision bytes.
    let snapshot = conversationHistory
    Task {
      do {
        try conversationStore.saveHistory(snapshot, for: locationID)
      } catch {
        // Silent fail is acceptable; history is in-memory for this session.
      }
    }
  }

  // MARK: - Structured Grok fetches (Today brief, radar explain, alert summary)

  private enum StructuredFetchError: LocalizedError {
    case busy
    case missingWeather
    case emptyResponse

    var errorDescription: String? {
      switch self {
      case .busy: "AI is busy with another request. Try again in a moment."
      case .missingWeather: "Weather data isn't loaded yet. Pull to refresh and try again."
      case .emptyResponse: "AI returned an empty response. Check your connection and try again."
      }
    }
  }

  func fetchWeatherBrief() async throws -> String {
    guard !isStreaming && !isGeneratingImage else { throw StructuredFetchError.busy }
    await ensureWeatherContext()
    guard let weather = weatherStore.currentWeather else {
      throw StructuredFetchError.missingWeather
    }

    let location = weatherStore.currentLocation?.name ?? weather.location.name
    let unit = weatherStore.temperatureUnit
    let alertEvents = weatherStore.displayableActiveAlerts.prefix(3).map(\.event)
    let alertLine = alertEvents.joined(separator: ", ")

    let system = """
      You are a helpful weather assistant inside DayCast. Write a practical 2–4 sentence weather brief for \(location).
      Current: \(unit.format(weather.currentTemp)), feels \(unit.format(weather.feelsLike)), \(weather.conditionText).
      Today high/low: \(unit.formatShort(weather.high)) / \(unit.formatShort(weather.low)).
      Precip chance now: \(weather.precipitationChance)%.
      Active alerts: \(alertLine.isEmpty ? "none" : alertLine).
      Include outfit hint, best outdoor window, and anything worth watching. No markdown, no hashtags. Do not use internal labels such as "Forecast-only take", "SEVERE CONTEXT", or MD numbers.
      """

    let raw: String
    do {
      raw = try await completeChat(
        messages: [
          GrokBuildMessage(role: "system", content: system),
          GrokBuildMessage(role: "user", content: "Give me today's weather take."),
        ],
        feature: .todaysTake,
        maxTokens: 280
      )
    } catch StructuredFetchError.emptyResponse {
      raw = LocalWeatherBrief.make(
        weather: weather,
        unit: unit,
        locationName: location,
        activeAlerts: Array(alertEvents)
      )
    }

    guard
      let finalized = GrokBriefText.finalize(
        raw: raw,
        weather: weather,
        unit: unit,
        locationName: location,
        activeAlerts: Array(alertEvents)
      )
    else {
      throw StructuredFetchError.emptyResponse
    }
    return finalized
  }

  func fetchRadarExplanation(context: RadarExplainContext) async throws -> String {
    guard !isStreaming && !isGeneratingImage else { throw StructuredFetchError.busy }

    if RadarExplainCopy.shouldUseLocalExplanation(context) {
      return RadarExplainCopy.localExplanation(for: context)
    }

    let raw = try await completeChat(
      messages: [
        GrokBuildMessage(role: "system", content: RadarExplainCopy.systemPrompt(for: context)),
        GrokBuildMessage(role: "user", content: "Explain this radar view in plain English."),
      ],
      feature: .explainRadar,
      maxTokens: 320
    )
    guard let accepted = GrokContentFilter.acceptedText(raw) else {
      return RadarExplainCopy.localExplanation(for: context)
    }
    if RadarExplainCopy.inventsPrecipitationAtPin(accepted, context: context) {
      return RadarExplainCopy.localExplanation(for: context)
    }
    return accepted
  }

  func fetchAlertsPlainEnglishSummary(alerts: [NWSAlert]) async throws -> String {
    guard !isStreaming && !isGeneratingImage else { throw StructuredFetchError.busy }
    guard !alerts.isEmpty else { return "No active alerts to summarize." }

    let location = weatherStore.currentLocation?.name ?? "your area"
    let bulletList = alerts.prefix(5).map { alert in
      "- \(alert.event): \(alert.headline ?? alert.areaDesc ?? "See DayCast for details")"
    }.joined(separator: "\n")

    let system = """
      Summarize these NWS alerts for \(location) in plain English (3–5 sentences).
      Say who is affected, timing if known, and 1–2 safety actions. No markdown.
      Alerts:
      \(bulletList)
      """

    let raw = try await completeChat(
      messages: [
        GrokBuildMessage(role: "system", content: system),
        GrokBuildMessage(role: "user", content: "Summarize these alerts for a regular person."),
      ],
      feature: .alertsSummary,
      maxTokens: 360
    )
    if let accepted = GrokContentFilter.acceptedText(raw) {
      return GrokBriefText.visible(accepted)
    }
    return GrokBriefText.visible(
      LocalWeatherBrief.alertsSummary(locationName: location, alerts: alerts))
  }

  private func completeChat(
    messages: [GrokBuildMessage], feature: GrokFeature, maxTokens: Int
  ) async throws -> String {
    let trimmed = try await GrokBuildService.complete(
      messages: messages, feature: feature, maxTokens: maxTokens)
    guard !trimmed.isEmpty else { throw StructuredFetchError.emptyResponse }
    return trimmed
  }
}
