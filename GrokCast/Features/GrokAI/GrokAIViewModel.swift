import Foundation
import Observation

@MainActor
@Observable
final class GrokAIViewModel {
  var responseText: String = ""
  var isStreaming: Bool = false
  var errorMessage: String?
  var stormAnalysisMode: Bool = false
  var stormThumbnailData: Data?
  var isGeneratingImage: Bool = false

  private let weatherStore: WeatherStore
  private let grokAIService = GrokAIService()
  private let conversationStore = GrokAIConversationStore()
  @ObservationIgnored private nonisolated(unsafe) var generationTask: Task<Void, Never>?
  private(set) var generationWasCancelled = false

  private(set) var lastStormImageData: Data?
  private(set) var lastStormNotes: String?

  // Conversation history for multi-turn context
  private(set) var conversationHistory: [ChatMessage] = []
  private let maxContextMessages = 16  // simple limit for context window (~8 turns)
  @ObservationIgnored private var historyLoadTask: Task<Void, Never>?

  init(weatherStore: WeatherStore) {
    self.weatherStore = weatherStore

    // Load persisted history before accepting new messages (prevents async overwrite race).
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
    await historyLoadTask?.value

    guard !question.trimmingCharacters(in: .whitespaces).isEmpty else { return }

    // Prevent overlapping generations from rapid taps
    guard !isStreaming && !isGeneratingImage else { return }

    // Early key guard (prevents append + silent fail; GrokBuild falls back to xai key)
    if !grokAIService.hasValidKey {
      errorMessage =
        "No xAI API key found. Add your developer key in Settings → Developer Key to use Grok AI."
      return
    }

    // Detect image generation requests in free-text (or route quick prompts that match)
    if isImageGenerationRequest(question) {
      await generateWeatherImage(description: question)
      return
    }

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

    generationTask = Task { @MainActor [weak self] in
      guard let self else { return }
      var tokenCount = 0
      do {
        // Use streaming for progressive token display
        for try await token in self.grokAIService.streamResponse(messages: apiMessages) {
          if Task.isCancelled || !self.isStreaming { break }
          tokenCount += 1
          self.responseText += token
        }
      } catch {
        if !(error is CancellationError) {
          self.errorMessage = error.localizedDescription
        }
      }
      self.isStreaming = false

      // On completion, append the full assistant message to history
      if !self.responseText.isEmpty {
        let assistantMsg = ChatMessage.assistant(self.responseText)
        self.conversationHistory.append(assistantMsg)
        self.conversationHistory = self.trimHistory(self.conversationHistory)
        self.persistCurrentHistory()
      } else if !Task.isCancelled && self.generationWasCancelled == false {
        self.errorMessage = "Grok returned an empty response. Check your connection and try again."
      }
      self.generationTask = nil
    }
    await generationTask?.value
  }

  func analyzeStormPhoto(imageData: Data, userNotes: String?) async {
    generationTask?.cancel()
    generationWasCancelled = false
    stormAnalysisMode = true
    isStreaming = true
    responseText = ""
    errorMessage = nil

    lastStormImageData = imageData
    lastStormNotes = userNotes
    stormThumbnailData = imageData.compressedForVision(maxDimension: 150, quality: 0.6)

    guard imageData.compressedForVision() != nil else {
      errorMessage = "Couldn't process that photo. Try a different image or format (JPEG/PNG)."
      isStreaming = false
      stormAnalysisMode = false
      return
    }

    guard weatherStore.xaiService.hasValidKey else {
      errorMessage =
        "No xAI API key found. Add your developer key in Settings → Developer Key to use Storm Spotter."
      isStreaming = false
      stormAnalysisMode = false
      return
    }

    await refreshStormWeatherContext()

    let weather = weatherStore.currentWeather
    let alerts = weatherStore.activeAlerts
    let observation = weatherStore.currentNWSObservation

    generationTask = Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        for try await token in self.weatherStore.xaiService.streamAdvancedStormAnalysis(
          imageData: imageData,
          weather: weather,
          alerts: alerts,
          nearestStationObservation: observation,
          userNotes: userNotes
        ) {
          if Task.isCancelled || !isStreaming { break }
          self.responseText += token
        }
      } catch {
        if !(error is CancellationError) {
          self.errorMessage = self.userFriendlyStormError(for: error)
        }
      }
      self.isStreaming = false
      self.stormAnalysisMode = false
      self.generationTask = nil
    }
    await generationTask?.value
  }

  func retryStormAnalysis() async {
    guard let imageData = lastStormImageData else { return }
    await analyzeStormPhoto(imageData: imageData, userNotes: lastStormNotes)
  }

  func clearResponse() {
    responseText = ""
    errorMessage = nil
    stormThumbnailData = nil
    stormAnalysisMode = false
    isGeneratingImage = false
    conversationHistory.removeAll()  // start fresh conversation

    // Also clear persisted data so it doesn't come back on next launch.
    Task {
      try? conversationStore.deleteAll()
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

  func userFriendlyStormError(for error: Error) -> String {
    if weatherStore.isOffline {
      return "No internet connection. Check your Wi-Fi or cellular and try again."
    }

    if let apiError = error as? GrokAPIError {
      switch apiError {
      case .missingAPIKey:
        return "No xAI API key found. Add your developer key in Settings → Developer Key to use Storm Spotter."
      case .networkError(let underlying):
        if let urlError = underlying as? URLError, urlError.code == .timedOut {
          return "Storm analysis timed out. The image may be large or the service is busy — tap Retry."
        }
        return apiError.errorDescription ?? error.localizedDescription
      case .apiError(let statusCode, let message) where statusCode == 400 || statusCode == 422:
        let lower = message.lowercased()
        if lower.contains("image") || lower.contains("vision") || lower.contains("format")
          || lower.contains("base64")
        {
          return "That photo couldn't be analyzed. Try a clearer sky image (JPEG/PNG)."
        }
        return "Storm analysis request was rejected. \(message)"
      default:
        return apiError.errorDescription ?? error.localizedDescription
      }
    }

    if let urlError = error as? URLError, urlError.code == .timedOut {
      return "Storm analysis timed out. The image may be large or the service is busy — tap Retry."
    }

    return error.localizedDescription
  }

  private func refreshStormWeatherContext() async {
    let targetLocation =
      weatherStore.savedLocations.first(where: {
        $0.name.localizedCaseInsensitiveContains("Olive Branch")
      })
      ?? weatherStore.savedLocations.first(where: { !$0.isCurrent })

    if let location = targetLocation {
      await weatherStore.refreshWeather(for: location)
    } else if let current = weatherStore.savedLocations.first(where: { $0.isCurrent }) {
      await weatherStore.refreshWeather(for: current)
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
    guard let current = weatherStore.currentWeather else {
      return "You are a helpful weather assistant inside the GrokCast app."
    }

    let location = weatherStore.currentLocation?.name ?? "your location"
    let temp = Int(current.currentTemp)
    let condition = current.conditionText

    return """
      You are a helpful weather assistant inside the GrokCast app.

      Current conditions for \(location):
      - Temperature: \(temp)°F
      - Condition: \(condition)
      - Feels like: \(Int(current.feelsLike))°F
      - Humidity: \(current.humidity)%
      - Wind: \(Int(current.windSpeed)) mph

      Be concise, friendly, and practical. When giving recommendations (outfits, activities, etc.),
      base them on the current weather data.
      """
  }

  private func isImageGenerationRequest(_ text: String) -> Bool {
    let lower = text.lowercased()
    return lower.contains("image") || lower.contains("picture") || lower.contains("imagine")
      || lower.contains("draw") || lower.contains("visualize") || lower.contains("generate a scene")
      || lower.contains("show me the weather as")
  }

  private func buildImagePrompt(userDescription: String?) -> String {
    guard let current = weatherStore.currentWeather else {
      let base =
        userDescription?.isEmpty == false ? userDescription! : "A beautiful cinematic weather scene"
      return "\(base), photorealistic, high detail, atmospheric lighting, no text or logos"
    }

    let temp = Int(round(current.currentTemp))
    let feels = Int(round(current.feelsLike))
    let condition = current.conditionText
    let location = current.location.name
    let wind = Int(round(current.windSpeed))
    let humidity = current.humidity
    let high = Int(round(current.high))
    let low = Int(round(current.low))

    let base = userDescription?.isEmpty == false ? "\(userDescription!). " : ""
    let timeOfDay =
      (current.symbolName.contains("sun") || current.symbolName.contains("day"))
      ? "daytime" : "evening or night"

    return """
      \(base)Create a highly detailed, cinematic weather visualization for \(location) right now.
      Conditions: \(condition), \(temp)°F (feels like \(feels)°F), wind \(wind) mph, humidity \(humidity)%.
      Today's range \(high)° / \(low)°. \(timeOfDay) lighting.
      Photorealistic or atmospheric digital art style, dramatic natural light, rich colors, 
      moody and immersive, no text, no logos, no people unless they naturally enhance the scene.
      """
  }

  func generateWeatherImage(description: String? = nil) async {
    await historyLoadTask?.value
    guard !isStreaming && !isGeneratingImage else { return }

    guard weatherStore.xaiService.hasValidKey else {
      errorMessage =
        "No xAI API key found. Add your developer key in Settings → Developer Key to generate images."
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
      let url = try await weatherStore.xaiService.generateDayImage(prompt: prompt)

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

  private func loadPersistedHistory() async {
    do {
      var loaded = try conversationStore.loadHistory()
      loaded = trimHistory(loaded)
      conversationHistory = loaded
    } catch {
      // Start with empty history on error (non-fatal for the feature).
      conversationHistory = []
    }
    historyLoadTask = nil
  }

  private func persistCurrentHistory() {
    // Snapshot to avoid capturing mutable state across the Task boundary
    let snapshot = conversationHistory
    Task {
      do {
        try conversationStore.saveHistory(snapshot)
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
      case .busy: "Grok is busy with another request. Try again in a moment."
      case .missingWeather: "Weather data isn't loaded yet. Pull to refresh and try again."
      case .emptyResponse: "Grok returned an empty response. Check your connection and try again."
      }
    }
  }

  func fetchWeatherBrief() async throws -> String {
    guard !isStreaming && !isGeneratingImage else { throw StructuredFetchError.busy }
    await ensureWeatherContext()
    guard let weather = weatherStore.currentWeather else { throw StructuredFetchError.missingWeather }

    let location = weatherStore.currentLocation?.name ?? weather.location.name
    let unit = weatherStore.temperatureUnit
    let alerts = weatherStore.displayableActiveAlerts.prefix(3).map(\.event).joined(separator: ", ")

    let system = """
      You are Grok inside GrokCast. Write a practical 2–4 sentence weather brief for \(location).
      Current: \(unit.format(weather.currentTemp)), feels \(unit.format(weather.feelsLike)), \(weather.conditionText).
      Today high/low: \(unit.formatShort(weather.high)) / \(unit.formatShort(weather.low)).
      Precip chance now: \(weather.precipitationChance)%.
      Active alerts: \(alerts.isEmpty ? "none" : alerts).
      Include outfit hint, best outdoor window, and anything worth watching. No markdown, no hashtags.
      """

    return try await completeChat(
      messages: [
        GrokBuildMessage(role: "system", content: system),
        GrokBuildMessage(role: "user", content: "Give me Grok's take on today's weather."),
      ],
      maxTokens: 280
    )
  }

  func fetchRadarExplanation(context: RadarExplainContext) async throws -> String {
    guard !isStreaming && !isGeneratingImage else { throw StructuredFetchError.busy }

    let system = """
      You are Grok explaining weather radar to a non-meteorologist inside GrokCast.
      Location: \(context.locationName). Product: \(context.productName). Mode: \(context.modeLabel). Frame: \(context.frameLabel).
      In 3–5 short sentences, describe what the radar likely shows, movement/trends if inferable, and practical impacts.
      No markdown. If uncertain, say so plainly.
      """

    return try await completeChat(
      messages: [
        GrokBuildMessage(role: "system", content: system),
        GrokBuildMessage(role: "user", content: "Explain this radar view in plain English."),
      ],
      maxTokens: 320
    )
  }

  func fetchAlertsPlainEnglishSummary(alerts: [NWSAlert]) async throws -> String {
    guard !isStreaming && !isGeneratingImage else { throw StructuredFetchError.busy }
    guard !alerts.isEmpty else { return "No active alerts to summarize." }

    let location = weatherStore.currentLocation?.name ?? "your area"
    let bulletList = alerts.prefix(5).map { alert in
      "- \(alert.event): \(alert.headline ?? alert.areaDesc ?? "See GrokCast for details")"
    }.joined(separator: "\n")

    let system = """
      Summarize these NWS alerts for \(location) in plain English (3–5 sentences).
      Say who is affected, timing if known, and 1–2 safety actions. No markdown.
      Alerts:
      \(bulletList)
      """

    return try await completeChat(
      messages: [
        GrokBuildMessage(role: "system", content: system),
        GrokBuildMessage(role: "user", content: "Summarize these alerts for a regular person."),
      ],
      maxTokens: 360
    )
  }

  private func completeChat(messages: [GrokBuildMessage], maxTokens: Int) async throws -> String {
    guard grokAIService.hasValidKey else {
      throw GrokBuildError.missingAPIKey
    }

    var result = ""
    for try await token in grokAIService.streamResponse(messages: messages) {
      result += token
    }

    let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw StructuredFetchError.emptyResponse }
    return trimmed
  }
}
