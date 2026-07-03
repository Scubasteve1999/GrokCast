import Foundation

/// Dedicated service for all Grok AI (xAI) communication.
/// Provides consistent streaming and error handling so the UI never gets stuck in "THINKING...".
@MainActor
final class GrokAIService {
  var hasValidKey: Bool {
    GrokAuthResolver.canAccessGrok(subscription: SubscriptionManager.shared)
  }

  // MARK: - Regular chat (quick prompts + free text)
  func streamResponse(messages: [GrokBuildMessage]) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
      Task { @MainActor in
        do {
          let auth = try GrokAuthResolver.resolve(subscription: SubscriptionManager.shared)
          let config = GrokBuildConfiguration(auth: auth)
          let stream = GrokBuildService(configuration: config).streamChat(
            messages: messages,
            auth: auth
          )
          for try await chunk in stream {
            continuation.yield(chunk)
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }
}
