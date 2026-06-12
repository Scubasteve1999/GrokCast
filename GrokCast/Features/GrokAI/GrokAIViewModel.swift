import Foundation
import SwiftUI

@MainActor
final class GrokAIViewModel: ObservableObject {
  @Published var responseText: String = ""
  @Published var isStreaming: Bool = false
  @Published var errorMessage: String?
  @Published var stormAnalysisMode: Bool = false
  @Published var stormThumbnailData: Data?

  private let weatherStore: WeatherStore
  private let grokBuildService: GrokBuildService
  private var generationTask: Task<Void, Never>?
  private(set) var generationWasCancelled = false

  private(set) var lastStormImageData: Data?
  private(set) var lastStormNotes: String?

  init(weatherStore: WeatherStore) {
    self.weatherStore = weatherStore
    self.grokBuildService = weatherStore.grokBuildService
  }

  deinit {
    generationTask?.cancel()
  }

  func askGrok(question: String) async {
    guard !question.trimmingCharacters(in: .whitespaces).isEmpty else { return }

    generationTask?.cancel()
    generationWasCancelled = false
    stormAnalysisMode = false
    isStreaming = true
    responseText = ""
    errorMessage = nil

    let messages = buildMessages(with: question)

    generationTask = Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        for try await token in self.grokBuildService.streamChat(messages: messages) {
          if Task.isCancelled || !isStreaming { break }
          self.responseText += token
        }
      } catch {
        if !(error is CancellationError) {
          self.errorMessage = error.localizedDescription
        }
      }
      self.isStreaming = false
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
        return
          "No xAI API key found. Add your developer key in Settings → Developer Key to use Storm Spotter."
      case .networkError(let underlying):
        if let urlError = underlying as? URLError, urlError.code == .timedOut {
          return
            "Storm analysis timed out. The image may be large or the service is busy — tap Retry."
        }
        return "Network error during storm analysis. Check your connection and try again."
      case .apiError(let message):
        let lower = message.lowercased()
        if lower.contains("http 401") || lower.contains("http 403") {
          return "Invalid or unauthorized xAI API key. Check Settings → Developer Key."
        }
        if lower.contains("http 422") || lower.contains("http 400") {
          if lower.contains("image") || lower.contains("vision") || lower.contains("format")
            || lower.contains("base64")
          {
            return "That photo couldn't be analyzed. Try a clearer sky image (JPEG/PNG)."
          }
          return "Storm analysis request was rejected. \(message)"
        }
        if lower.contains("http 5") {
          return "Storm analysis service is temporarily unavailable. Tap Retry in a moment."
        }
        return message
      case .invalidKeyFormat:
        return "Invalid xAI API key format. Keys must start with 'xai-'."
      case .invalidMode(let message):
        return message
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

  private func buildMessages(with question: String) -> [GrokBuildMessage] {
    var messages: [GrokBuildMessage] = []

    let systemPrompt = buildWeatherSystemPrompt()
    messages.append(GrokBuildMessage(role: "system", content: systemPrompt))

    messages.append(GrokBuildMessage(role: "user", content: question))

    return messages
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
}
