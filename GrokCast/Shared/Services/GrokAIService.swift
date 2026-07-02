import Foundation

/// Dedicated service for all Grok AI (xAI) communication.
/// Provides consistent streaming and error handling so the UI never gets stuck in "THINKING...".
@MainActor
final class GrokAIService {
  private let grokBuildService: GrokBuildService

  init(grokBuildService: GrokBuildService = GrokBuildService()) {
    self.grokBuildService = grokBuildService
  }

  var hasValidKey: Bool {
    !GrokBuildConfiguration.make().apiKey.isEmpty
  }

  // MARK: - Regular chat (quick prompts + free text)
  func streamResponse(messages: [GrokBuildMessage]) -> AsyncThrowingStream<String, Error> {
    // Direct delegation to GrokBuildService (now configured for grok-3-mini + xAI key fallback).
    // Timeouts and key checks handled inside.
    return grokBuildService.streamChat(messages: messages)
  }
}
